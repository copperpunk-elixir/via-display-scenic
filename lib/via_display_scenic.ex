defmodule ViaDisplayScenic do
  require Logger
  use Supervisor
  @size {800, 480}

  def start_link(config) do
    ViaUtils.Process.start_link_redundant(Supervisor, __MODULE__, config)
  end

  def init(config) do
    Logger.debug("VDS init")
    # Display.Scenic.Planner
    vehicle_type = Keyword.fetch!(config, :vehicle_type)
    gcs_scene = Module.concat(["ViaDisplayScenic.Gcs", vehicle_type])
    planner_scene = ViaDisplayScenic.Planner
    root_scene = ViaDisplayScenic.RootScene

    gcs_name = :gcs_scene
    planner_name = :planner_scene

    opts =
      Keyword.take(config, [:realflight_sim])
      |> Keyword.put(:gcs_scene, gcs_name)
      |> Keyword.put(:planner_scene, planner_name)

    children = [
      {gcs_scene, {opts, [name: gcs_name]}},
      {planner_scene, {opts, [name: planner_name]}}
    ]

    # viewports = [gcs_config(opts)]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def root_config(opts) do
    %{
      name: :main_viewport,
      size: @size,
      default_scene: {ViaDisplayScenic.RootScene, opts},
      drivers: drivers("Root")
    }
  end

  @spec gcs_config(list()) :: map()
  def gcs_config(opts) do
    %{
      name: :main_viewport,
      size: @size,
      default_scene: {opts[:gcs_scene], opts},
      drivers: drivers("GCS")
    }
  end

  def planner_config(opts) do
    %{
      name: :planner,
      size: @size,
      default_scene: {ViaDisplayScenic.Planner, opts},
      drivers: drivers("Planner")
    }
  end

  @spec driver_module :: Scenic.Driver.Glfw | Scenic.Driver.Nerves.Rpi
  def driver_module() do
    if ViaUtils.File.target?() do
      Scenic.Driver.Nerves.Rpi
    else
      Scenic.Driver.Glfw
    end
  end

  def drivers(title) do
    if ViaUtils.File.target?() do
      [
        %{
          module: driver_module(),
          name: :gcs_driver,
          opts: [resizeable: false, title: title]
        },
        %{
          module: Scenic.Driver.Nerves.Touch,
          opts: [
            device: "raspberrypi-ts",
            calibration: {{1, 0, 0}, {1, 0, 0}}
          ]
        }
      ]
    else
      [
        %{
          module: driver_module(),
          name: :gcs_driver,
          opts: [resizeable: false, title: title]
        }
      ]
    end
  end
end
