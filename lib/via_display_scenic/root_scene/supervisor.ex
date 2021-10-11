defmodule ViaDisplayScenic.RootScene.Supervisor do
  use Supervisor
  require Logger

  def start_link() do
    Logger.debug("Start Display Supervisor")
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, nil, __MODULE__)
  end

  def init(_) do
    viewports = [ViaDisplayScenic.root_config([])]

    children = [
      Supervisor.child_spec({Scenic, viewports: viewports}, id: :root_scene)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
