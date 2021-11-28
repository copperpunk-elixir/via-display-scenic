defmodule ViaDisplayScenic.Operator do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups

  def start_link(config) do
    Logger.debug("Start ViaDisplayScenic.Operator GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, config, __MODULE__)
  end

  @impl GenServer
  def init(config) do
    Logger.debug("#{__MODULE__} config: #{inspect(config)}")
    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)
    default_messages = Keyword.get(config, :default_messages, %{})
    :erlang.send_after(2000, self(), {:subscribe_to_default_messages, default_messages})

    state = %{
      ubx: UbxInterpreter.new(),
      mission: nil
    }

    ViaUtils.Comms.join_group(__MODULE__, Groups.clear_mission())
    ViaUtils.Comms.join_group(__MODULE__, Groups.display_mission())

    # Default messages

    Logger.warn("Disply OP PID: #{inspect(self())}")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({Groups.display_mission(), mission}, state) do
    # Logger.debug("#{__MODULE__} display mission: #{inspect(mission)}")
    {:noreply, %{state | mission: mission}}
  end

  @impl GenServer
  def handle_call(:retrieve_mission, _from, state) do
    Logger.debug("Retrieve mission: #{inspect(state.mission)}")
    {:reply, state.mission, state}
  end

  @impl GenServer
  def handle_info({:subscribe_to_default_messages, default_messages}, state) do
    Enum.each(default_messages, fn {msg_module, freq} ->
      msg_class = msg_module.get_class()
      msg_id = msg_module.get_id()
      ViaDisplayScenic.Messages.Utils.subscribe_to_message(__MODULE__, msg_class, msg_id, freq)
    end)

    {:noreply, state}
  end
end
