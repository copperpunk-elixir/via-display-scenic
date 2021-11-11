defmodule ViaDisplayScenic.Operator do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaTelemetry.Ubx.Custom.ClassDefs, as: ClassDefs
  alias ViaTelemetry.Ubx.Custom.VehicleCmds, as: VehicleCmds
  alias ViaTelemetry.Ubx.Custom.VehicleState, as: VehicleState
  require VehicleCmds.AttitudeThrustCmd, as: AttitudeThrustCmd
  require VehicleCmds.BodyrateThrottleCmd, as: BodyrateThrottleCmd
  require VehicleCmds.ActuatorCmdDirect, as: ActuatorCmdDirect
  require VehicleCmds.SpeedCourseAltitudeSideslipCmd, as: SpeedCourseAltitudeSideslipCmd
  require VehicleCmds.SpeedCourserateAltrateSideslipCmd, as: SpeedCourserateAltrateSideslipCmd
  require VehicleCmds.ControllerActuatorOutput, as: ControllerActuatorOutput
  require VehicleState.AttitudeAndRates, as: AttitudeAndRates
  require VehicleState.PositionVelocity, as: PositionVelocity
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaUtils.Shared.GoalNames, as: SGN
  require ViaDisplayScenic.Groups, as: DisplayGroups

  def start_link(config) do
    Logger.debug("Start ViaDisplayScenic.Operator GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    Logger.debug("#{__MODULE__} config: #{inspect(config)}")
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    uart_port = Keyword.fetch!(config, :uart_port)

    state = %{
      uart_ref: nil,
      uart_port: uart_port,
      ubx: UbxInterpreter.new(),
      mission: nil
    }

    if uart_port == "virtual" do
      Logger.debug("#{__MODULE__} virtual UART port")
      ViaUtils.Comms.join_group(__MODULE__, Groups.virtual_uart_telemetry())
    else
      port_options = Keyword.fetch!(config, :port_options) ++ [active: true]
      GenServer.cast(self(), {:open_uart_connection, uart_port, port_options, false})
    end

    ViaUtils.Comms.join_group(__MODULE__, Groups.clear_mission())
    ViaUtils.Comms.join_group(__MODULE__, Groups.display_mission())

    Logger.warn("Disply OP PID: #{inspect(self())}")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:open_uart_connection, uart_port, port_options}, state) do
    uart_ref =
      ViaUtils.Uart.open_connection_and_return_uart_ref(
        uart_port,
        port_options
      )

    {:noreply, %{state | uart_ref: uart_ref}}
  end

  @impl true
  def handle_cast({Groups.display_mission(), mission}, state) do
    # Logger.debug("#{__MODULE__} display mission: #{inspect(mission)}")
    {:noreply, %{state | mission: mission}}
  end

  @impl true
  def handle_info({:circuits_uart, _port, data}, state) do
    # Logger.debug("Op rx'd data: #{inspect(data)}")
    state = check_for_new_messages_and_process(:binary.bin_to_list(data), state)

    {:noreply, state}
  end

  @spec check_for_new_messages_and_process(list(), map()) :: map()
  def check_for_new_messages_and_process(data, state) do
    %{ubx: ubx} = state
    {ubx, payload} = UbxInterpreter.check_for_new_message(ubx, data)

    if Enum.empty?(payload) do
      state
    else
      %{msg_class: msg_class, msg_id: msg_id} = ubx
      # Logger.debug("#{__MODULE__} msg class/id: #{msg_class}/#{msg_id}")

      {bytes, multipliers, keys, group} =
        case msg_class do
          ClassDefs.vehicle_state() ->
            case msg_id do
              AttitudeAndRates.id() ->
                {AttitudeAndRates.bytes(), AttitudeAndRates.multipliers(),
                 AttitudeAndRates.keys(), DisplayGroups.attitude_attrate_val()}

              PositionVelocity.id() ->
                {PositionVelocity.bytes(), PositionVelocity.multipliers(),
                 PositionVelocity.keys(), DisplayGroups.position_velocity_val()}

              _other ->
                Logger.warn("Bad message id: #{msg_id}")
                {nil, nil, nil, nil}
            end

          ClassDefs.vehicle_cmds() ->
            case msg_id do
              BodyrateThrottleCmd.id() ->
                {BodyrateThrottleCmd.bytes(), BodyrateThrottleCmd.multipliers(),
                 BodyrateThrottleCmd.keys(), DisplayGroups.bodyrate_thrust_cmd()}

              AttitudeThrustCmd.id() ->
                {AttitudeThrustCmd.bytes(), AttitudeThrustCmd.multipliers(),
                 AttitudeThrustCmd.keys(), DisplayGroups.attitude_throttle_cmd()}

              SpeedCourseAltitudeSideslipCmd.id() ->
                {SpeedCourseAltitudeSideslipCmd.bytes(),
                 SpeedCourseAltitudeSideslipCmd.multipliers(),
                 SpeedCourseAltitudeSideslipCmd.keys(),
                 DisplayGroups.speed_course_altitude_sideslip_cmd()}

              SpeedCourserateAltrateSideslipCmd.id() ->
                {SpeedCourserateAltrateSideslipCmd.bytes(),
                 SpeedCourserateAltrateSideslipCmd.multipliers(),
                 SpeedCourserateAltrateSideslipCmd.keys(),
                 DisplayGroups.speed_courserate_altrate_sideslip_cmd()}

              _other ->
                Logger.warn("Bad message id: #{msg_id}")
                {nil, nil, nil, nil}
            end

          # case msg_id do
          # end

          _other ->
            Logger.warn("Bad message class: #{msg_class}")
        end

      unless is_nil(bytes) do
        values =
          UbxInterpreter.deconstruct_message_to_map(
            bytes,
            multipliers ,
            keys,
            payload
          )

        # Logger.debug("#{__MODULE__} group/vals: #{inspect(group)}/#{inspect(values)}")

        ViaUtils.Comms.cast_local_msg_to_group(
          __MODULE__,
          {group, values},
          self()
        )
      end

      check_for_new_messages_and_process([], %{state | ubx: UbxInterpreter.clear(ubx)})
    end
  end

  @impl GenServer
  def handle_call(:retrieve_mission, _from, state) do
    Logger.debug("Retrieve mission: #{inspect(state.mission)}")
    {:reply, state.mission, state}
  end
end
