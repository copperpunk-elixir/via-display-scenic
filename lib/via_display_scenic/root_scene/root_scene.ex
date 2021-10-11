defmodule ViaDisplayScenic.RootScene do
  use Scenic.Scene
  require Logger
  import Scenic.Primitives

  @impl Scenic.Scene
  def init(args, opts) do
    Logger.debug("Init root scene")
    viewport = opts[:viewport]
    {:ok, %Scenic.ViewPort.Status{size: {vp_width, vp_height}}} = Scenic.ViewPort.info(viewport)

    Logger.debug("args: #{inspect(args)}")

    graph =
      Scenic.Graph.build()
      |> rect({vp_width, vp_height})

    Logger.debug("scene pid: #{inspect(self())}")
    ViaUtils.Comms.start_operator(__MODULE__)
    ViaUtils.Comms.join_group(__MODULE__, :load_gcs)

    {:ok, %{graph: graph}, push: graph}
  end

  @impl true
  def handle_cast(:load_gcs, state) do
    Logger.debug("Load GCS")
    Logger.debug(inspect(state.graph))
    graph =
      state.graph
      |> scene_ref(:gcs_scene, translate: {0, 0})

    Logger.debug(inspect(graph))

    {:noreply, state, push: graph}
  end

  def load_gcs() do
    GenServer.cast(__MODULE__, :load_gcs)
  end
end
