defmodule ViaDisplayScenic.Messages do
  use Scenic.Scene
  require Logger
  require ViaDisplayScenic.Ids, as: Ids
  require ViaTelemetry.Ubx.MsgClasses, as: MsgClasses
  require ViaTelemetry.Ubx.Actions.SubscribeToMsg, as: SubscribeToMsg
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaUtils.Shared.Groups, as: Groups
  alias ViaDisplayScenic.Messages.Frequencies, as: Freq
  import Scenic.Primitives

  @impl Scenic.Scene
  @font_size 19

  def init(args, opts) do
    Logger.debug("#{__MODULE__} PID: #{inspect(self())}")
    Logger.debug("#{__MODULE__} opts: #{inspect(opts)}")
    Logger.debug("#{__MODULE__} args: #{inspect(args)}")
    viewport = opts[:viewport]

    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} = Scenic.ViewPort.info(viewport)

    graph =
      Scenic.Graph.build()
      |> rect({vp_width, vp_height})

    {graph, _offset_x, _offset_y} =
      ViaDisplayScenic.Utils.add_sidebar(graph, vp_width, Ids.button_go_to_msgs())

    # Logger.debug("graph after buttons: #{inspect(graph)}")

    {graph, _offset_x, _offset_y} =
      ViaDisplayScenic.Utils.add_button_dropdown_columns_to_graph(graph,
        width: 100,
        height: 40,
        offset_x: 0,
        offset_y: 0,
        spacer_y: 20,
        # theme: %{text: :white, background: :blue, active: :grey, border: :white},
        labels: ["Att/AttRate", "Pos/Vel", "PCL 1 Cmd", "PCL 2 Cmd", "PCL 3 Cmd", "PCL 4 Cmd"],
        dropdown_ids: [
          Ids.dropdown_attitude_attrate_val(),
          Ids.dropdown_position_velocity_val(),
          Ids.dropdown_bodyrate_throttle_cmd(),
          Ids.dropdown_attitude_thrust_cmd(),
          Ids.dropdown_speed_course_altitude_sideslip_cmd(),
          Ids.dropdown_speed_courserate_altrate_sideslip_cmd()
        ],
        dropdown_items: Freq.freq_binary_number_tuple(),
        font_size: @font_size
      )

    Logger.debug("graph after dropdown: #{inspect(graph)}")
    # origin = GenServer.call(ViaDisplayScenic.Operator, :retrieve_origin)
    # vehicle_position = GenServer.call(ViaDisplayScenic.Operator, :retrieve_vehicle_position)
    state = %{
      graph: graph,
      viewport: viewport,
      vp_width: vp_width,
      vp_height: vp_height,
      args: Keyword.drop(args, [:messages_state])
    }

    ViaUtils.Comms.start_operator(__MODULE__)
    {:ok, state, push: graph}
  end

  @impl Scenic.Scene
  def terminate(reason, state) do
    Logger.warn("Messages terminate: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, {Ids.button_go_to(), dest_scene}}, _from, state) do
    ViaDisplayScenic.Utils.go_to_scene(dest_scene, :messages_state, state)
    {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event(
        {:value_changed, {Ids.message_rate_dropdown(), msg_class, msg_id}, msg_freq_hz},
        _from,
        state
      ) do
    Logger.debug("#{msg_class}/#{msg_id} changed to #{msg_freq_hz}.")

    # {_id_atom, msg_class, msg_id} = dropdown_id

    ViaDisplayScenic.Messages.Utils.subscribe_to_message(
      __MODULE__,
      msg_class,
      msg_id,
      msg_freq_hz
    )

    {:noreply, state}
  end
end
