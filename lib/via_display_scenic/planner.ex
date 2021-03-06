defmodule ViaDisplayScenic.Planner do
  use Scenic.Scene
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaDisplayScenic.Ids, as: Ids
  import Scenic.Primitives

  @impl Scenic.Scene

  @draw_vehicle_loop :draw_vehicle_loop
  @draw_vehicle_interval_ms 100
  def init(args, opts) do
    Logger.debug("Planner PID: #{inspect(self())}")
    Logger.debug("Planner.init opts: #{inspect(opts)}")
    Logger.debug("Planner args: #{inspect(args)}")
    viewport = opts[:viewport]

    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} = Scenic.ViewPort.info(viewport)

    go_to_gcs_width = 80
    go_to_gcs_height = 60

    graph =
      Scenic.Graph.build()
      |> rect({vp_width, vp_height})

    {graph, _offset_x, _offset_y} =
      ViaDisplayScenic.Utils.add_sidebar(graph, vp_width, Ids.button_go_to_planner())

    # {graph, _, _} =
    #   ViaDisplayScenic.Utils.add_button_to_graph(
    #     graph,
    #     %{
    #       text: "GCS",
    #       id: Ids.button_go_to_gcs(),
    #       theme: %{text: :white, background: :blue, active: :grey, border: :white},
    #       width: go_to_gcs_width,
    #       height: go_to_gcs_height,
    #       font_size: 19,
    #       offset_x: vp_width - go_to_gcs_width - 10,
    #       offset_y: vp_height - go_to_gcs_height - 10
    #     }
    #   )

    {graph, _, _} =
      ViaDisplayScenic.Utils.add_button_to_graph(
        graph,
        %{
          text: "Load\nRacetrack",
          id: Ids.button_load_racetrack(),
          theme: %{text: :white, background: :purple, active: :grey, border: :white},
          width: go_to_gcs_width,
          height: go_to_gcs_height,
          font_size: 19,
          offset_x: vp_width - go_to_gcs_width - 10,
          offset_y: vp_height - 2 * go_to_gcs_height - 20
        }
      )

    mission = GenServer.call(ViaDisplayScenic.Operator, :retrieve_mission)
    # origin = GenServer.call(ViaDisplayScenic.Operator, :retrieve_origin)
    # vehicle_position = GenServer.call(ViaDisplayScenic.Operator, :retrieve_vehicle_position)
    is_realflight = Keyword.get(args, :realflight_sim, false)
    margin = if is_realflight, do: 100, else: 734

    state = %{
      graph: graph,
      viewport: viewport,
      vp_width: vp_width,
      vp_height: vp_height,
      margin: margin,
      args: Keyword.drop(args, [:planner_state]),
      mission: mission,
      origin: nil,
      vehicle_position_rrm: %{},
      vehicle_groundspeed_mps: nil,
      vehicle_yaw_rad: nil
    }

    state = if !is_nil(mission), do: display_mission(state, mission), else: state

    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.clear_mission())
    ViaUtils.Comms.join_group(__MODULE__, Groups.display_mission())
    ViaUtils.Comms.join_group(__MODULE__, Groups.ubx_position_velocity_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.ubx_attitude_attrate_val())

    ViaUtils.Process.start_loop(self(), @draw_vehicle_interval_ms, @draw_vehicle_loop)
    {:ok, state, push: state.graph}
  end

  @impl Scenic.Scene
  def terminate(reason, state) do
    Logger.warn("Planner terminate: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({Groups.ubx_attitude_attrate_val(), values}, state) do
    %{SVN.yaw_rad() => yaw_rad} = values

    {:noreply,
     %{
       state
       | vehicle_yaw_rad: yaw_rad
     }}
  end

  @impl true
  def handle_cast({Groups.ubx_position_velocity_val(), values}, state) do
    %{
      SVN.groundspeed_mps() => groundspeed_mps
    } = values

    {:noreply,
     %{
       state
       | vehicle_position_rrm:
           Map.take(values, [SVN.latitude_rad(), SVN.longitude_rad(), SVN.altitude_m()]),
         vehicle_groundspeed_mps: groundspeed_mps
     }}
  end

  @impl true
  def handle_cast({Groups.display_mission(), mission}, state) do
    # Logger.debug("planner display mission: #{inspect(mission)}")
    state = display_mission(state, mission)
    {:noreply, state, push: state.graph}
  end

  @impl true
  def handle_info(@draw_vehicle_loop, state) do
    %{
      vehicle_position_rrm: position_rrm,
      vehicle_groundspeed_mps: groundspeed_mps,
      vehicle_yaw_rad: yaw_rad,
      origin: origin,
      vp_width: vp_width,
      vp_height: vp_height,
      margin: margin,
      graph: graph
    } = state

    origin =
      cond do
        Enum.empty?(position_rrm) ->
          origin

        is_nil(origin) ->
          bounding_box =
            ViaDisplayScenic.Planner.Path.Dubins.calculate_lat_lon_bounding_box([], position_rrm)

          ViaDisplayScenic.Planner.Path.Dubins.calculate_origin(
            bounding_box,
            vp_width,
            vp_height,
            margin
          )

        true ->
          origin
      end

    graph =
      unless is_nil(yaw_rad) or is_nil(groundspeed_mps) or Enum.empty?(position_rrm) do
        # Logger.debug("draw veh")
        draw_vehicle(graph, position_rrm, groundspeed_mps, yaw_rad, origin, vp_height)
      else
        # Logger.debug("draw empty")
        graph
      end

    {:noreply, %{state | graph: graph, origin: origin}, push: graph}
  end

  @spec display_mission(map(), any()) :: map()
  def display_mission(state, mission) do
    # Logger.debug("Planner display mission: #{inspect(mission)}")
    # %{MV.waypoints() => waypoints, MV.turn_rate_rps() => turn_rate_rps} = mission

    # {config_points, path_distance} =
    #   ViaNavigation.Dubins.Utils.config_points_from_waypoints(
    #     waypoints,
    #     turn_rate_rps
    #   )

    # Logger.debug("Distance: #{path_distance}")
    # Logger.debug("Config points: #{inspect(config_points)}")

    %{
      graph: graph,
      vehicle_position_rrm: vehicle_position_rrm,
      vp_width: vp_width,
      vp_height: vp_height,
      margin: margin
    } = state

    {graph, origin} =
      ViaDisplayScenic.Planner.Path.Dubins.add_mission_to_graph(
        graph,
        mission,
        vehicle_position_rrm,
        vp_width,
        vp_height,
        margin
      )

    # Logger.debug("graph: #{inspect(graph)}")
    %{state | mission: mission, origin: origin, graph: graph}
  end

  @spec draw_vehicle(map(), map(), number(), number(), struct(), float()) :: map()
  def draw_vehicle(graph, position_rrm, groundspeed_mps, yaw_rad, origin, vp_height) do
    %{SVN.latitude_rad() => lat, SVN.longitude_rad() => lon} = position_rrm
    {y_plot, x_plot} = ViaDisplayScenic.Planner.Origin.get_xy(origin, lat, lon)
    # Logger.debug("xy_plot: #{x_plot}/#{y_plot}")
    vehicle_size = ceil(groundspeed_mps / 10) + 10

    Scenic.Graph.delete(graph, :vehicle)
    |> ViaDisplayScenic.Utils.draw_arrow(
      x_plot,
      vp_height - y_plot,
      yaw_rad,
      vehicle_size,
      :vehicle,
      true
    )
  end

  @impl Scenic.Scene
  def filter_event({:click, {Ids.button_go_to(), dest_scene}}, _from, state) do
    ViaDisplayScenic.Utils.go_to_scene(dest_scene, :planner_state, state)
    {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, Ids.button_load_racetrack()}, _from, state) do
    Logger.debug("Load Racetrack")
    is_realflight = state.args[:realflight_sim]

    mission =
      if is_realflight do
        ViaNavigation.Dubins.Mission.Prebuilt.get_flight_school_18L()
      else
        ViaNavigation.Dubins.Mission.Prebuilt.get_seatac_34L()
      end

    # Logger.info("mission: #{inspect(mission)}")
    ViaUtils.Comms.cast_local_msg_to_group(__MODULE__, {Groups.display_mission(), mission}, nil)
    ViaUtils.Comms.cast_local_msg_to_group(__MODULE__, {Groups.load_mission(), mission}, self())
    # {:cont, event, state}
    {:noreply, state}
  end
end
