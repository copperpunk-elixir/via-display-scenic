defmodule ViaDisplayScenic.Messages.Utils do
  require ViaUtils.Shared.Groups, as: Groups
  require ViaUtils.Shared.ValueNames, as: SVN
  require ViaTelemetry.Ubx.Actions.SubscribeToMsg, as: SubscribeToMsg
  require ViaTelemetry.Ubx.MsgClasses, as: MsgClasses

  require Logger

  def subscribe_to_message(operator, msg_class, msg_id, msg_freq_hz) do
    Logger.debug("#{__MODULE__} subscribe to #{msg_class}/#{msg_id} @ #{msg_freq_hz}Hz")
    values = %{
      SVN.vehicle_id() => 0,
      SVN.time_since_boot_s() => ViaUtils.Process.time_since_boot_s(),
      SVN.message_class() => msg_class,
      SVN.message_id() => msg_id,
      SVN.message_frequency_hz() => msg_freq_hz
    }

    Logger.info("sub values: #{inspect(values)}")

    ubx_message =
      UbxInterpreter.construct_message_from_map(
        MsgClasses.actions(),
        SubscribeToMsg.id(),
        SubscribeToMsg.bytes(),
        SubscribeToMsg.multipliers(),
        SubscribeToMsg.keys(),
        values
      )

    ViaUtils.Comms.cast_local_msg_to_group(
      operator,
      {Groups.telemetry_ground_send_message(), ubx_message},
      self()
    )
  end
end
