defmodule CureOMaticScenic.Scene.Home do
  use Scenic.Scene

  alias Scenic.Graph
  # alias LayoutOMatic.Layouts.Components.Layout, as: ComponentsLayout
  alias LayoutOMatic.Layouts.Grid

  @viewport Application.get_env(:cure_o_matic_scenic, :viewport)
            |> Map.get(:size)

  @grid %{
    grid_template: [{:equal, 2}],
    max_xy: @viewport,
    grid_ids: [:left_grid, :right_grid],
    starting_xy: {0, 0},
    opts: [draw: true]
  }

  @graph Graph.build()
         |> Scenic.Primitives.add_specs_to_graph(Grid.add_grid(@grid),
           id: :root_grid
         )

  def init(_, _opts) do
    Scene.call()
    graph =
      Graph.build()
    {:ok, graph, push: graph}
  end
end
