defmodule ViaDisplayScenic.Operator do
  use GenServer
  require Logger
  require ViaUtils.Shared.Groups, as: Groups

  def start_link(_) do
    Logger.debug("Start ViaDisplayScenic.Operator GenServer")
    ViaUtils.Process.start_link_redundant(GenServer, __MODULE__, nil, __MODULE__)
  end

  @impl GenServer
  def init(_) do
    state = %{
      mission: nil,
    }

    ViaUtils.Comms.Supervisor.start_operator(__MODULE__)

    ViaUtils.Comms.join_group(__MODULE__, Groups.clear_mission())
    ViaUtils.Comms.join_group(__MODULE__, Groups.display_mission())

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({Groups.display_mission(), mission}, state) do
    Logger.debug("#{__MODULE__} display mission: #{inspect(mission)}")
    {:noreply, %{state | mission: mission}}
  end

  @impl GenServer
  def handle_call(:retrieve_mission, _from, state) do
    Logger.debug("Retrieve mission: #{inspect(state.mission)}")
    {:reply, state.mission, state}
  end
end
