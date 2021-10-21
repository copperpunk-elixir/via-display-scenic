defmodule ViaDisplayScenic.Planner.Path.Dubins do
  # use Scenic.Scene
  require Logger
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaNavigation.Dubins.Shared.MissionValues, as: MV
  require ViaNavigation.Dubins.Shared.ModelSpec, as: MS

  import Scenic.Primitives

  @primitive_id :mission_primitives
  @orbit_id :orbit_primitive

  @spec add_mission_to_graph(map(), struct(), struct(), integer(), float(), float()) ::
          tuple()
  def add_mission_to_graph(graph, mission, vehicle_position, width, height, margin) do
    %{MV.waypoints() => waypoints, MV.model_spec() => model_spec} = mission
    %{MS.turn_rate_rps() => turn_rate_rps} = model_spec

    bounding_box = calculate_lat_lon_bounding_box(waypoints, vehicle_position)
    origin = calculate_origin(bounding_box, width, height, margin)

    {config_points, _current_path_distance} =
      ViaNavigation.Dubins.Utils.config_points_from_waypoints(
        waypoints,
        turn_rate_rps
      )

    graph = draw_mission(graph, origin, height, waypoints, config_points)

    {graph, origin}
  end

  @spec draw_mission(map(), struct(), float(), list(), list()) :: map()
  def draw_mission(graph, origin, height, waypoints, config_points) do
    Scenic.Graph.delete(graph, @primitive_id)
    |> Scenic.Graph.delete(@orbit_id)
    |> draw_waypoints(origin, height, waypoints)
    |> draw_path(origin, height, config_points)
  end

  @spec add_orbit_points_to_waypoints(map(), float(), list()) :: list()
  def add_orbit_points_to_waypoints(orbit_center, radius, waypoints) do
    orbit_points =
      Enum.reduce(0..3, [], fn mult, acc ->
        angle = mult * :math.pi() / 2
        x = radius * :math.sin(angle)
        y = radius * :math.cos(angle)
        point = ViaUtils.Location.location_from_point_with_dx_dy(orbit_center, x, y)
        [point] ++ acc
      end)

    orbit_points ++ waypoints
  end

  @spec calculate_lat_lon_bounding_box(list(), map(), boolean()) :: tuple()
  def calculate_lat_lon_bounding_box(waypoints, vehicle_position, degrees \\ false) do
    Logger.debug("cllbb wps: #{inspect(waypoints)}")
    Logger.debug("cllbb pos: #{inspect(vehicle_position)}")

    {min_lat, max_lat, min_lon, max_lon} =
      if degrees == true do
        {90, -90, 180, -180}
      else
        {:math.pi() / 2, -:math.pi() / 2, :math.pi(), -:math.pi()}
      end

    # waypoints = Map.get(mission, :waypoints, [])

    all_coords =
      if Enum.empty?(vehicle_position) do
        waypoints
      else
        [vehicle_position] ++ waypoints
      end

    {min_lat, max_lat, min_lon, max_lon} =
      Enum.reduce(all_coords, {min_lat, max_lat, min_lon, max_lon}, fn coord, acc ->
        %{SVN.latitude_rad() => lat, SVN.longitude_rad() => lon} = coord
        min_lat = min(elem(acc, 0), lat)
        max_lat = max(elem(acc, 1), lat)
        min_lon = min(elem(acc, 2), lon)
        max_lon = max(elem(acc, 3), lon)
        {min_lat, max_lat, min_lon, max_lon}
      end)

    min_separation = 0.00001

    {min_lat, max_lat} =
      if min_lat == max_lat do
        dLat = min_separation
        {min_lat - dLat, max_lat + dLat}
      else
        {min_lat, max_lat}
      end

    {min_lon, max_lon} =
      if min_lon == max_lon do
        dLon = min_separation * :math.sqrt(2)
        {min_lon - dLon, max_lon + dLon}
      else
        {min_lon, max_lon}
      end

    # {min_lat, max_lat, min_lon, max_lon}
    {ViaUtils.Location.new(min_lat, min_lon), ViaUtils.Location.new(max_lat, max_lon)}
  end

  @spec calculate_origin(tuple(), integer(), integer(), integer()) :: struct()
  def calculate_origin(bounding_box, vp_width, vp_height, margin) do
    {bottom_left, top_right} = bounding_box
    # Logger.debug("bottom left: #{Common.Utils.LatLonAlt.to_string(bottom_left)}")
    # Logger.debug("top right: #{Common.Utils.LatLonAlt.to_string(top_right)}")
    aspect_ratio = vp_width / vp_height
    {dx_dist, dy_dist} = ViaUtils.Location.dx_dy_between_points(bottom_left, top_right)
    # Logger.debug("dx_dist/dy_dist: #{dx_dist}/#{dy_dist}")
    gap_x = 1 / dx_dist
    gap_y = aspect_ratio / dy_dist
    # Logger.debug("gap_x/gap_y: #{gap_x}/#{gap_y}")
    # margin = 100#734
    {origin, top_corner} =
      if gap_x < gap_y do
        # (1+2*margin)*dx_dist
        total_dist_x = 2 * margin + dx_dist
        # *:math.sqrt(2)
        total_dist_y = aspect_ratio * total_dist_x
        # *dx_dist
        margin_x = margin
        margin_y = (total_dist_y - dy_dist) / 2

        origin =
          ViaUtils.Location.location_from_point_with_dx_dy(bottom_left, -margin_x, -margin_y)

        top_corner =
          ViaUtils.Location.location_from_point_with_dx_dy(top_right, margin_x, margin_y)

        {origin, top_corner}
      else
        # (1 + 2*margin) * dy_dist##*:math.sqrt(2)
        total_dist_y = 2 * margin + dy_dist
        total_dist_x = total_dist_y / aspect_ratio
        # *dy_dist
        margin_y = margin
        margin_x = (total_dist_x - dx_dist) / 2

        origin =
          ViaUtils.Location.location_from_point_with_dx_dy(bottom_left, -margin_x, -margin_y)

        top_corner =
          ViaUtils.Location.location_from_point_with_dx_dy(top_right, margin_x, margin_y)

        {origin, top_corner}
      end

    %{SVN.latitude_rad() => origin_lat, SVN.longitude_rad() => origin_lon} = origin

    %{SVN.latitude_rad() => top_corner_lat, SVN.longitude_rad() => top_corner_lon} = top_corner

    total_x = top_corner_lat - origin_lat
    total_y = top_corner_lon - origin_lon

    dx_lat = vp_height / total_x
    dy_lon = vp_width / total_y
    # Logger.debug("dx_lat/dy_lon: #{dx_lat}/#{dy_lon}")
    # Logger.debug("dx/dy ratio: #{dx_lat/dy_lon}")
    ViaDisplayScenic.Planner.Origin.new(origin_lat, origin_lon, dx_lat, dy_lon)
  end

  @spec draw_waypoints(map(), struct(), float(), list()) :: map()
  def draw_waypoints(graph, origin, height, waypoints) do
    Enum.reduce(waypoints, graph, fn wp, acc ->
      wp_plot = get_translate(wp, origin, height)

      left_or_right =
        case wp.type do
          :approach -> :left
          :landing -> :left
          _other -> :right
        end

      wp_text_x =
        if left_or_right == :left do
          elem(wp_plot, 0) - 8 * String.length(wp.name)
        else
          elem(wp_plot, 0) + 10
        end

      wp_text = {wp_text_x, elem(wp_plot, 1)}
      # Logger.debug("#{wp.name} xy: #{inspect(wp_plot)}")
      # Logger.debug(Common.Utils.LatLonAlt.to_string(wp))
      circle(acc, 10, fill: :blue, translate: wp_plot, id: @primitive_id)
      |> text(wp.name, translate: wp_text, id: @primitive_id)
    end)
  end

  @spec draw_path(map(), struct(), float(), list()) :: map()
  def draw_path(graph, origin, height, config_points) do
    line_width = 5

    Enum.reduce(config_points, graph, fn cp, acc ->
      # Arc
      # Line
      cs_arc_start_angle =
        (ViaUtils.Location.angle_between_points(cp.cs, cp.pos) - :math.pi() / 2)
        |> ViaUtils.Math.constrain_angle_to_compass()

      cs_arc_finish_angle =
        (ViaUtils.Location.angle_between_points(cp.cs, cp.z1) - :math.pi() / 2)
        |> ViaUtils.Math.constrain_angle_to_compass()

      {cs_arc_start_angle, cs_arc_finish_angle} =
        correct_arc_angles(cs_arc_start_angle, cs_arc_finish_angle, cp.start_direction)

      # if (cs_arc_finish_angle - cs_arc_start_angle < ) do
      # end
      ce_arc_start_angle =
        (ViaUtils.Location.angle_between_points(cp.ce, cp.z2) - :math.pi() / 2)
        |> ViaUtils.Math.constrain_angle_to_compass()

      ce_arc_finish_angle =
        (ViaUtils.Location.angle_between_points(cp.ce, cp.z3) - :math.pi() / 2)
        |> ViaUtils.Math.constrain_angle_to_compass()

      {ce_arc_start_angle, ce_arc_finish_angle} =
        correct_arc_angles(ce_arc_start_angle, ce_arc_finish_angle, cp.end_direction)

      radius_cs =
        ViaDisplayScenic.Planner.Origin.get_dx_dy(origin, cp.cs, cp.pos)
        |> ViaUtils.Math.hypot()
        |> round()

      radius_ce =
        ViaDisplayScenic.Planner.Origin.get_dx_dy(origin, cp.ce, cp.z2)
        |> ViaUtils.Math.hypot()
        |> round()

      line_start = get_translate(cp.z1, origin, height)
      line_end = get_translate(cp.z2, origin, height)
      cs = get_translate(cp.cs, origin, height)
      ce = get_translate(cp.ce, origin, height)

      line(acc, {line_start, line_end}, stroke: {line_width, :white}, id: @primitive_id)
      |> circle(3, stroke: {2, :green}, translate: cs, id: @primitive_id)
      |> circle(5, stroke: {2, :red}, translate: ce, id: @primitive_id)
      |> arc({radius_cs, cs_arc_start_angle, cs_arc_finish_angle},
        stroke: {line_width, :green},
        translate: cs,
        id: @primitive_id
      )
      |> arc({radius_ce, ce_arc_start_angle, ce_arc_finish_angle},
        stroke: {line_width, :red},
        translate: ce,
        id: @primitive_id
      )

      # Arc
    end)
  end

  @spec draw_orbit(map(), struct(), struct(), float(), float()) :: map()
  def draw_orbit(graph, origin, orbit_center, radius, height) do
    c_orbit = get_translate(orbit_center, origin, height)
    color = if radius > 0, do: :blue, else: :pink
    point_on_circle = ViaUtils.Location.location_from_point_with_dx_dy(orbit_center, radius, 0)

    radius_draw =
      ViaDisplayScenic.Planner.Origin.get_dx_dy(origin, orbit_center, point_on_circle)
      |> ViaUtils.Math.hypot()
      |> round()

    circle(graph, radius_draw, stroke: {2, color}, translate: c_orbit, id: @orbit_id)
    |> circle(3, stroke: {2, color}, translate: c_orbit, id: @orbit_id)
  end

  @spec draw_vehicle(map(), struct(), struct(), float()) :: map()
  def draw_vehicle(graph, vehicle, origin, vp_height) do
    %{SVN.position_rrm() => veh_pos, SVN.yaw_rad() => veh_yaw, SVN.groundspeed_mps() => veh_speed} =
      vehicle

    %{SVN.latitude_rad() => veh_lat, SVN.longitude_rad() => veh_lon} = veh_pos

    {y_plot, x_plot} =
      ViaDisplayScenic.Planner.Origin.get_xy(
        origin,
        veh_lat,
        veh_lon
      )

    # Logger.debug("xy_plot: #{x_plot}/#{y_plot}")
    vehicle_size = ceil(veh_speed / 10) + 10

    Scenic.Graph.delete(graph, :vehicle)
    |> ViaDisplayScenic.Utils.draw_arrow(
      x_plot,
      vp_height - y_plot,
      veh_yaw,
      vehicle_size,
      :vehicle,
      true
    )
  end

  @spec get_translate(struct(), struct(), float()) :: tuple()
  def get_translate(point, origin, vp_height) do
    %{SVN.latitude_rad() => p_lat, SVN.longitude_rad() => p_lon} = point
    {y, x} = ViaDisplayScenic.Planner.Origin.get_xy(origin, p_lat, p_lon)
    {x, vp_height - y}
  end

  @spec correct_arc_angles(float(), float(), integer()) :: tuple()
  def correct_arc_angles(start, finish, direction) do
    # Logger.debug("start/finish initial: #{Common.Utils.Math.rad2deg(start)}/#{Common.Utils.Math.rad2deg(finish)}")
    arc = ViaUtils.Motion.turn_left_or_right_for_correction(start - finish) |> abs()

    if arc < ViaUtils.Math.deg2rad(2) do
      {0, 0}
    else
      if direction > 0 do
        # Turning right
        if(finish < start) do
          {start, finish + 2.0 * :math.pi()}
        else
          {start, finish}
        end
      else
        cs_start = finish
        cs_finish = start

        if cs_finish < cs_start do
          {cs_start, cs_finish + 2.0 * :math.pi()}
        else
          {cs_start, cs_finish}
        end
      end
    end
  end
end
