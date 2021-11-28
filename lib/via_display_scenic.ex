defmodule ViaDisplayScenic do
  @size {800, 480}
  def child_spec(config) do
    # Display.Scenic.Planner
    vehicle_type = Keyword.fetch!(config, :vehicle_type)
    gcs_scene = Module.concat(["ViaDisplayScenic.Gcs", vehicle_type])

    opts =
      Keyword.take(config, [:realflight_sim])
      |> Keyword.put(:gcs_scene, gcs_scene)
      |> Keyword.put(:planner_scene, ViaDisplayScenic.Planner)
      |> Keyword.put(:messages_scene, ViaDisplayScenic.Messages)

    viewports = [gcs_config(opts)]

    Supervisor.child_spec({Scenic, viewports: viewports}, id: :scenic_app)
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

  def messages_config(opts) do
    %{
      name: :planner,
      size: @size,
      default_scene: {ViaDisplayScenic.Messages, opts},
      drivers: drivers("Messages")
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
