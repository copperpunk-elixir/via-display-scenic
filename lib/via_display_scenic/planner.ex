defmodule ViaDisplayScenic.Planner do
  use Scenic.Scene
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaNavigation.Dubins.Shared.MissionValues, as: MV
  import Scenic.Primitives

  @impl Scenic.Scene
  def init(args, opts) do
    Logger.debug("Planner.init self: #{inspect(self())}")
    Logger.debug("Planner.init opts: #{inspect(opts)}")
    Logger.debug("Planner args: #{inspect(args)}")
    viewport = opts[:viewport]

    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} = Scenic.ViewPort.info(viewport)

    go_to_gcs_width = 80
    go_to_gcs_height = 60

    graph =
      Scenic.Graph.build()
      |> rect({vp_width, vp_height})

    {graph, _, _} =
      ViaDisplayScenic.Utils.add_button_to_graph(
        graph,
        %{
          text: "GCS",
          id: :go_to_gcs,
          theme: %{text: :white, background: :blue, active: :grey, border: :white},
          width: go_to_gcs_width,
          height: go_to_gcs_height,
          font_size: 19,
          offset_x: vp_width - go_to_gcs_width - 10,
          offset_y: vp_height - go_to_gcs_height - 10
        }
      )

    {graph, _, _} =
      ViaDisplayScenic.Utils.add_button_to_graph(
        graph,
        %{
          text: "Load\nRacetrack",
          id: :load_racetrack,
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
      mission: nil,
      origin: nil,
      vehicle_position: nil
    }

    state = if !is_nil(mission), do: display_mission(state, mission), else: state

    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, Groups.clear_mission())
    ViaUtils.Comms.join_group(__MODULE__, Groups.display_mission())

    {:ok, state, push: state.graph}
  end

  @impl Scenic.Scene
  def terminate(reason, state) do
    Logger.warn("Planner terminate: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def handle_cast({Groups.display_mission(), mission}, state) do
    Logger.debug("planner display mission: #{inspect(mission)}")
    state = display_mission(state, mission)
    {:noreply, state, push: state.graph}
  end

  def display_mission(state, mission) do
    Logger.debug("display mission: #{inspect(mission)}")
    Logger.debug("Planner display mission: #{inspect(mission)}")
    %{MV.waypoints() => waypoints, MV.turn_rate_rps() => turn_rate_rps} = mission

    {config_points, path_distance} =
      ViaNavigation.Dubins.Utils.config_points_from_waypoints(
        waypoints,
        turn_rate_rps
      )

    Logger.debug("Distance: #{path_distance}")
    Logger.debug("Config points: #{inspect(config_points)}")

    %{
      graph: graph,
      vehicle_position: vehicle_position,
      vp_width: vp_width,
      vp_height: vp_height,
      margin: margin
    } = state

    {graph, origin} =
      ViaDisplayScenic.Planner.Path.Dubins.add_mission_to_graph(
        graph,
        mission,
        vehicle_position,
        vp_width,
        vp_height,
        margin
      )

    Logger.debug("graph: #{inspect(graph)}")
    %{state | mission: mission, origin: origin, graph: graph}
  end

  @impl Scenic.Scene
  def filter_event({:click, :go_to_gcs}, _from, state) do
    Logger.debug("Go To GCS")
    vp = state.viewport

    args =
      state.args
      |> Keyword.put(:planner_state, Map.drop(state, [:graph]))

    gcs_scene = args[:gcs_scene]
    Scenic.ViewPort.set_root(vp, {gcs_scene, args})
    # {:cont, event, state}
    {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, :load_racetrack}, _from, state) do
    Logger.debug("Load Racetrack")
    is_realflight = state.args[:realflight_sim]

    mission =
      if is_realflight do
        ViaNavigation.Dubins.Mission.Prebuilt.get_flight_school_18L()
      else
        ViaNavigation.Dubins.Mission.Prebuilt.get_seatac_34L()
      end

    # Logger.info("mission: #{inspect(mission)}")
    ViaUtils.Comms.send_local_msg_to_group(__MODULE__, {Groups.display_mission(), mission}, nil)
    # {:cont, event, state}
    {:noreply, state}
  end
end
