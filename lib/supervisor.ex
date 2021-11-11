defmodule ViaDisplayScenic.Supervisor do
  use Supervisor
  require Logger

  def start_link(config) do
    Logger.debug("Start Display Supervisor")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config, __MODULE__)
  end

  def init(config) do
    operator_config = Keyword.fetch!(config, :Operator)
    children = [
      apply(config[:display_module], :child_spec, [Keyword.drop(config, [:display_module, :Operator])]),
      {ViaDisplayScenic.Operator, operator_config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def load_test_env() do
    ViaUtils.Registry.start_link()
    Process.sleep(100)
    ViaUtils.Comms.Supervisor.start_link(nil)

    config = [
      display_module: ViaDisplayScenic,
      vehicle_type: "FixedWing",
      realflight_sim: false
    ]

    ViaDisplayScenic.Supervisor.start_link(config)
  end
end
