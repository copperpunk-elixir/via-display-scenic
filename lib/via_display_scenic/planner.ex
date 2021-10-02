defmodule ViaDisplayScenic.Planner do
  use Scenic.Scene
  require Logger
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
      ViaDisplayScenic.Gcs.Utils.add_button_to_graph(
        graph,
        %{
          text: "GCS",
          id: :go_to_gcs,
          theme: %{text: :white, background: :blue, active: :grey, border: :white},
          width: go_to_gcs_width,
          height: go_to_gcs_height,
          font_size: 19,
          offset_x: 10,
          offset_y: 10
        }
      )

    state = %{
      graph: graph,
      viewport: viewport,
      args: Keyword.drop(args, [:planner_state])
    }

    {:ok, state, push: graph}
  end

  @impl Scenic.Scene
  def terminate(reason, state) do
    Logger.warn("Planner terminate: #{inspect(reason)}")
    {:noreply, state}
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
end
