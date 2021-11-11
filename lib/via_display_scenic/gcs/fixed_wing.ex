defmodule ViaDisplayScenic.Gcs.FixedWing do
  use Scenic.Scene
  require Logger
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaUtils.Shared.GoalNames, as: SGN
  require ViaUtils.Shared.ControlTypes, as: CT
  # require ViaTelemetry.Ubx.Custom.ClassDefs, as: ClassDefs
  # require ViaTelemetry.Ubx.Custom.VehicleState.AttitudeAndRates, as: AttitudeAndRates
  # require ViaTelemetry.Ubx.Custom.VehicleState.PositionVelocity, as: PositionVelocity
  require ViaDisplayScenic.Groups, as: DisplayGroups

  import Scenic.Primitives
  @degrees "°"
  @dps "°/s"
  @meters "m"
  @mps "m/s"
  @pct "%"

  @rect_border 6

  @impl true
  def init(args, opts) do
    Logger.warn("gcs pid: #{inspect(self())}")
    Logger.debug("Gcs.init: #{inspect(opts)}")
    Logger.debug("Gcs.args: #{inspect(Keyword.drop(args, [:gcs_state]))}")
    viewport = opts[:viewport]

    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} = Scenic.ViewPort.info(viewport)
    graph = ViaDisplayScenic.Gcs.FixedWing.Utils.build_graph(vp_width, vp_height, args)
    # col = vp_width / 12
    # subscribe to the simulated temperature sensor

    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, DisplayGroups.attitude_attrate_val())
    ViaUtils.Comms.join_group(__MODULE__, DisplayGroups.position_velocity_val())

    ViaUtils.Comms.join_group(__MODULE__, DisplayGroups.bodyrate_thrust_cmd())
    ViaUtils.Comms.join_group(__MODULE__, DisplayGroups.attitude_throttle_cmd())
    ViaUtils.Comms.join_group(__MODULE__, DisplayGroups.speed_course_altitude_sideslip_cmd())
    ViaUtils.Comms.join_group(__MODULE__, DisplayGroups.speed_courserate_altrate_sideslip_cmd())

    # ViaUtils.Comms.join_group(__MODULE__, {vehicle_id, DisplayGroups.attitude_throttle_cmd()})
    # ViaUtils.Comms.join_group(__MODULE__, Groups.current_pcl_and_all_commands_val())
    ViaUtils.Comms.join_group(__MODULE__, Groups.host_ip_address())
    ViaUtils.Comms.join_group(__MODULE__, Groups.realflight_ip_address())
    previous_state = args[:gcs_state]

    state =
      if is_nil(previous_state) do
        %{
          graph: graph,
          viewport: viewport,
          args: Keyword.drop(args, [:gcs_state]),
          host_ip: nil,
          realflight_ip: nil,
          save_log_file: "",
          pilot_control_level: nil
        }
      else
        Map.put(previous_state, :graph, graph)
      end

    # Logger.debug("prev GCS state: #{inspect(previous_state)}")

    if Keyword.get(args, :realflight_sim, false) do
      :erlang.send_after(1000, self(), :request_realflight_ip_address)
    end

    :erlang.send_after(1000, self(), :request_host_ip_address)

    {:ok, state, push: graph}
  end

  @impl Scenic.Scene
  def terminate(reason, state) do
    Logger.warn("GCS terminate: #{inspect(reason)}")
    {:noreply, state}
  end

  @impl true
  def handle_info(:request_realflight_ip_address, state) do
    Logger.debug("request rf ip")

    ViaUtils.Comms.cast_local_msg_to_group(
      __MODULE__,
      {Groups.get_realflight_ip_address(), self()},
      self()
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(:request_host_ip_address, state) do
    Logger.debug("request host ip")

    ViaUtils.Comms.cast_local_msg_to_group(__MODULE__, {:get_host_ip_address, self()}, self())

    {:noreply, state}
  end

  @impl true
  def handle_cast({Groups.host_ip_address(), ip_address}, state) do
    Logger.warn("host ip updated: #{inspect(ip_address)}")

    graph =
      if is_binary(ip_address) do
        Scenic.Graph.modify(state.graph, :host_ip, &text(&1, ip_address))
      else
        state.graph
      end

    {:noreply, %{state | graph: graph, host_ip: ip_address}, push: graph}
  end

  @impl true
  def handle_cast({Groups.realflight_ip_address(), ip_address}, state) do
    Logger.warn("RF ip updated: #{inspect(ip_address)}")

    graph =
      if is_binary(ip_address) do
        Scenic.Graph.modify(state.graph, :realflight_ip, &text(&1, ip_address))
      else
        state.graph
      end

    {:noreply, %{state | graph: graph, realflight_ip: ip_address}, push: graph}
  end

  # receive PV updates from the vehicle
  @impl true
  def handle_cast({DisplayGroups.attitude_attrate_val(), values}, state) do
    # Logger.debug("attitude/attrate: #{inspect(values)}")
    graph = draw_attitude(state.graph, values)
    {:noreply, %{state | graph: graph}, push: graph}
  end

  @impl true
  def handle_cast({DisplayGroups.position_velocity_val(), values}, state) do
    # Logger.debug("position/velocity: #{inspect(values)}")

    graph = draw_pos_vel(state.graph, values)
    {:noreply, %{state | graph: graph}, push: graph}
  end

  @impl true
  def handle_cast({DisplayGroups.bodyrate_thrust_cmd(), values}, state) do
    # Logger.debug("bodyrate-thrust: #{inspect(values)}")
    handle_draw_commands(state, :draw_pcl_1, values)
  end

  @impl true
  def handle_cast({DisplayGroups.attitude_throttle_cmd(), values}, state) do
    # Logger.debug("attitude-throttle: #{inspect(values)}")
    handle_draw_commands(state, :draw_pcl_2, values)
  end

  @impl true
  def handle_cast({DisplayGroups.speed_course_altitude_sideslip_cmd(), values}, state) do
    # Logger.debug("scas: #{inspect(values)}")
    handle_draw_commands(state, :draw_pcl_3, values)
  end

  @impl true
  def handle_cast({DisplayGroups.speed_courserate_altrate_sideslip_cmd(), values}, state) do
    # Logger.debug("scrars: #{inspect(values)}")
    handle_draw_commands(state, :draw_pcl_4, values)
  end

  # def handle_cast({Groups.current_pcl_and_all_commands_val(), cmds_and_pcl}, state) do
  #   # Logger.debug("gcs rx pcl=#{cmds_and_pcl.pilot_control_level}:#{inspect(cmds_and_pcl)}")

  #   %{
  #     # SVN.rollrate_rps() => rollrate_rps,
  #     # SVN.pitchrate_rps() => pitchrate_rps,
  #     # SVN.yawrate_rps() => yawrate_rps,
  #     SVN.pilot_control_level() => pcl
  #   } = cmds_and_pcl

  #   graph = state.graph

  #   graph =
  #     draw_pcl_1(graph, pcl, cmds_and_pcl)
  #     |> draw_pcl_2(pcl, cmds_and_pcl)
  #     |> draw_pcl_3(pcl, cmds_and_pcl)
  #     |> draw_pcl_4(pcl, cmds_and_pcl)
  #     |> update_pilot_control_level(pcl)

  #   {:noreply, %{state | graph: graph}, push: graph}
  # end

  # def handle_cast({:tx_battery, battery_id, voltage_V, current_A, energy_mAh}, state) do
  #   voltage = ViaUtils.Format.eftb(voltage_V, 2)
  #   current = ViaUtils.Format.eftb(current_A, 2)
  #   mAh = ViaUtils.Format.eftb(energy_mAh, 0)
  #   {battery_type, _battery_channel} = Health.Hardware.Battery.get_type_channel_for_id(battery_id)
  #   # Logger.debug("tx battery type: #{battery_type}")
  #   graph =
  #     state.graph
  #     |> Scenic.Graph.modify({battery_type, :V}, &text(&1,voltage <> "V"))
  #     |> Scenic.Graph.modify({battery_type, :I}, &text(&1,current <> "A"))
  #     |> Scenic.Graph.modify({battery_type, :mAh}, &text(&1,mAh <> "mAh"))
  #   {:noreply, %{state | graph: graph}, push: graph}
  # end

  def handle_cast({:cluster_status, cluster_status}, state) do
    fill = if cluster_status == 1, do: :green, else: :red

    graph =
      state.graph
      |> Scenic.Graph.modify(:cluster_status, &update_opts(&1, fill: fill))

    {:noreply, %{state | graph: graph}, push: graph}
  end

  def draw_pos_vel(graph, values) do
    %{
      SVN.latitude_rad() => latitude_rad,
      SVN.longitude_rad() => longitude_rad,
      SVN.altitude_m() => altitude_m,
      SVN.agl_m() => agl_m,
      SVN.airspeed_mps() => airspeed_mps,
      SVN.groundspeed_mps() => groundspeed_mps,
      SVN.course_rad() => course_rad
    } = values

    # Logger.debug("#{__MODULE__} pos-vel values: #{ViaUtils.Format.eftb_map(values, 2)}")
    lat = latitude_rad |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(5)

    lon = longitude_rad |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(5)

    alt = altitude_m |> ViaUtils.Format.eftb(2)
    agl = agl_m |> ViaUtils.Format.eftb(2)

    # v_down = ViaUtils.Format.eftb(velocity.down,1)
    airspeed = airspeed_mps |> ViaUtils.Format.eftb(1)
    # Logger.debug("disp #{airspeed}")
    speed = groundspeed_mps |> ViaUtils.Format.eftb(1)

    course =
      course_rad
      |> ViaUtils.Math.rad2deg()
      |> ViaUtils.Format.eftb(1)

    Scenic.Graph.modify(graph, :lat, &text(&1, lat <> @degrees))
    |> Scenic.Graph.modify(:lon, &text(&1, lon <> @degrees))
    |> Scenic.Graph.modify(:alt, &text(&1, alt <> @meters))
    |> Scenic.Graph.modify(:agl, &text(&1, agl <> @meters))
    |> Scenic.Graph.modify(:airspeed, &text(&1, airspeed <> @mps))
    |> Scenic.Graph.modify(:speed, &text(&1, speed <> @mps))
    |> Scenic.Graph.modify(:course, &text(&1, course <> @degrees))
  end

  def draw_attitude(graph, values) do
    %{
      SVN.roll_rad() => roll_rad,
      SVN.pitch_rad() => pitch_rad,
      SVN.yaw_rad() => yaw_rad
      # SVN.vehicle_id() => vehicle_id
    } = values

    # Logger.debug("#{__MODULE__} id: #{vehicle_id}")
    # attitude = Map.take(values, [SVN.roll_rad(), SVN.pitch_rad(), SVN.yaw_rad()])
    roll = roll_rad |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)
    pitch = pitch_rad |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

    yaw =
      yaw_rad
      |> ViaUtils.Math.constrain_angle_to_compass()
      |> ViaUtils.Math.rad2deg()
      |> ViaUtils.Format.eftb(1)

    graph
    |> Scenic.Graph.modify(:roll, &text(&1, roll <> @degrees))
    |> Scenic.Graph.modify(:pitch, &text(&1, pitch <> @degrees))
    |> Scenic.Graph.modify(:yaw, &text(&1, yaw <> @degrees))
  end

  def handle_draw_commands(state, draw_fn, cmds) do
    %{pilot_control_level: pcl_prev, graph: graph} = state
    %{SVN.pilot_control_level() => pcl} = cmds

    graph =
      apply(__MODULE__, draw_fn, [graph, pcl, cmds])
      |> update_pilot_control_level(pcl, pcl_prev)

    {:noreply, %{state | graph: graph, pilot_control_level: pcl}, push: graph}
  end

  def draw_pcl_1(graph, pcl, cmds) do
    if pcl < CT.pilot_control_level_1() do
      clear_text_values(graph, [:rollrate_cmd, :pitchrate_cmd, :yawrate_cmd, :throttle_cmd])
    else
      # Logger.info("#{__MODULE__} pcl1 cmds: #{inspect(cmds)}")

      rollrate =
        Map.get(cmds, SGN.rollrate_rps(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(0)

      pitchrate =
        Map.get(cmds, SGN.pitchrate_rps(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(0)

      yawrate =
        Map.get(cmds, SGN.yawrate_rps(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(0)

      throttle =
        Map.get(cmds, SGN.throttle_scaled(), 0)
        |> ViaUtils.Math.get_one_sided_from_two_sided()
        |> Kernel.*(100)
        |> ViaUtils.Format.eftb(0)

      graph
      |> Scenic.Graph.modify(:rollrate_cmd, &text(&1, rollrate <> @dps))
      |> Scenic.Graph.modify(:pitchrate_cmd, &text(&1, pitchrate <> @dps))
      |> Scenic.Graph.modify(:yawrate_cmd, &text(&1, yawrate <> @dps))
      |> Scenic.Graph.modify(:throttle_cmd, &text(&1, throttle <> @pct))
    end
  end

  def draw_pcl_2(graph, pcl, cmds) do
    if pcl < CT.pilot_control_level_2() do
      clear_text_values(graph, [:roll_cmd, :pitch_cmd, :deltayaw_cmd, :thrust_cmd])
    else
      roll =
        Map.get(cmds, SGN.roll_rad(), 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

      pitch =
        Map.get(cmds, SGN.pitch_rad(), 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(0)

      deltayaw =
        Map.get(cmds, SGN.deltayaw_rad(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(0)

      thrust = (Map.get(cmds, SGN.thrust_scaled(), 0) * 100) |> ViaUtils.Format.eftb(0)

      graph
      |> Scenic.Graph.modify(:roll_cmd, &text(&1, roll <> @degrees))
      |> Scenic.Graph.modify(:pitch_cmd, &text(&1, pitch <> @degrees))
      |> Scenic.Graph.modify(:deltayaw_cmd, &text(&1, deltayaw <> @degrees))
      |> Scenic.Graph.modify(:thrust_cmd, &text(&1, thrust <> @pct))
    end
  end

  def draw_pcl_3(graph, pcl, cmds) do
    if pcl < CT.pilot_control_level_3() do
      clear_text_values(graph, [:speed_3_cmd, :course_cmd, :altitude_cmd, :sideslip_3_cmd])
    else
      speed = Map.get(cmds, SGN.groundspeed_mps(), 0) |> ViaUtils.Format.eftb(1)

      course =
        Map.get(cmds, SGN.course_rad(), 0) |> ViaUtils.Math.rad2deg() |> ViaUtils.Format.eftb(1)

      altitude = Map.get(cmds, SGN.altitude_m(), 0) |> ViaUtils.Format.eftb(1)

      sideslip =
        Map.get(cmds, SGN.sideslip_rad(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(1)

      graph
      |> Scenic.Graph.modify(:speed_3_cmd, &text(&1, speed <> @mps))
      |> Scenic.Graph.modify(:course_cmd, &text(&1, course <> @degrees))
      |> Scenic.Graph.modify(:altitude_cmd, &text(&1, altitude <> @meters))
      |> Scenic.Graph.modify(:sideslip_3_cmd, &text(&1, sideslip <> @degrees))
    end
  end

  def draw_pcl_4(graph, pcl, cmds) do
    if pcl < CT.pilot_control_level_4() do
      clear_text_values(graph, [
        :speed_4_cmd,
        :course_rate_cmd,
        :altitude_rate_cmd,
        :sideslip_4_cmd
      ])
    else
      speed = Map.get(cmds, SGN.groundspeed_mps(), 0) |> ViaUtils.Format.eftb(1)

      course_rate =
        Map.get(cmds, SGN.course_rate_rps(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(1)

      altitude_rate = Map.get(cmds, SGN.altitude_rate_mps(), 0) |> ViaUtils.Format.eftb(1)

      sideslip =
        Map.get(cmds, SGN.sideslip_rad(), 0)
        |> ViaUtils.Math.rad2deg()
        |> ViaUtils.Format.eftb(1)

      graph
      |> Scenic.Graph.modify(:speed_4_cmd, &text(&1, speed <> @mps))
      |> Scenic.Graph.modify(:course_rate_cmd, &text(&1, course_rate <> @dps))
      |> Scenic.Graph.modify(:altitude_rate_cmd, &text(&1, altitude_rate <> @mps))
      |> Scenic.Graph.modify(:sideslip_4_cmd, &text(&1, sideslip <> @degrees))
    end
  end

  def update_pilot_control_level(graph, pilot_control_level, pilot_control_level_prev) do
    if pilot_control_level == pilot_control_level_prev do
      graph
    else
      Enum.reduce(CT.pilot_control_level_4()..CT.pilot_control_level_1(), graph, fn pcl, acc ->
        if pcl == pilot_control_level do
          Scenic.Graph.modify(
            acc,
            {:goals, pcl},
            &update_opts(&1, stroke: {@rect_border, :green})
          )
        else
          Scenic.Graph.modify(
            acc,
            {:goals, pcl},
            &update_opts(&1, stroke: {@rect_border, :white})
          )
        end
      end)
    end
  end

  def clear_text_values(graph, value_ids) do
    Enum.reduce(
      value_ids,
      graph,
      fn id, acc ->
        Scenic.Graph.modify(acc, id, &text(&1, ""))
      end
    )
  end

  # @impl Scenic.Scene
  # def filter_event({:click, :save_log}, _from, state) do
  #   Logger.debug("Save Log to file: #{state.save_log_file} (NOT CONNECTED)")
  #   # save_log_proto = ViaDisplayScenic.Gcs.Protobuf.SaveLog.new([filename: state.save_log_file])
  #   # save_log_encoded =ViaDisplayScenic.Gcs.Protobuf.SaveLog.encode(save_log_proto)
  #   # Peripherals.Uart.Generic.construct_and_send_proto_message(:save_log_proto, save_log_encoded, Peripherals.Uart.Telemetry.Operator)
  #   {:cont, :event, state}
  # end

  # @impl Scenic.Scene
  # def filter_event({:click, {:peri_ctrl, action}}, _from, state) do
  #   Logger.debug("Change PeriCtrl #{action} (NOT CONNECTED)")
  #   # control_value =
  #   #   case action do
  #   #     :allow -> 1
  #   #     :deny -> 0
  #   #   end
  #   # Peripherals.Uart.Generic.construct_and_send_message(:change_peripheral_control, [control_value], Peripherals.Uart.Telemetry.Operator)
  #   {:cont, :event, state}
  # end

  @impl Scenic.Scene
  def filter_event({:click, :reset_estimation} = event, _from, state) do
    Logger.debug("Reset Estimation")

    GenServer.cast(Estimation.Estimator, :reset_estimation)
    {:cont, event, state}
    # {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, {:modify_realflight_ip, value_to_add}} = event, _from, state) do
    Logger.debug("Change IP by #{value_to_add}")

    cond do
      !is_nil(state.realflight_ip) ->
        host_ip = state.host_ip

        ip_address =
          ViaDisplayScenic.Utils.add_to_ip_address_last_byte(
            state.realflight_ip,
            value_to_add
          )

        ip_address =
          if ip_address == host_ip do
            ViaDisplayScenic.Utils.add_to_ip_address_last_byte(host_ip, value_to_add)
          else
            ip_address
          end

        GenServer.cast(self(), {Groups.realflight_ip_address(), ip_address})

      !is_nil(state.host_ip) ->
        ip_address =
          ViaDisplayScenic.Utils.add_to_ip_address_last_byte(state.host_ip, value_to_add)

        GenServer.cast(self(), {Groups.realflight_ip_address(), ip_address})

      true ->
        :ok
    end

    {:cont, event, state}
    # {:noreply, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, :set_realflight_ip} = event, _from, state) do
    Logger.debug("Set IP #{state.realflight_ip}")

    ViaUtils.Comms.cast_local_msg_to_group(
      __MODULE__,
      {:set_realflight_ip_address, state.realflight_ip},
      self()
    )

    {:cont, event, state}
  end

  @impl Scenic.Scene
  def filter_event({:click, :go_to_planner}, _from, state) do
    Logger.debug("Go To Planner")
    vp = state.viewport

    args =
      state.args
      |> Keyword.put(:gcs_state, Map.drop(state, [:graph]))

    planner_scene = args[:planner_scene]
    Scenic.ViewPort.set_root(vp, {planner_scene, args})
    # {:cont, event, state}
    {:noreply, state}
  end
end
