defmodule ViaDisplayScenicTest do
  use ExUnit.Case
  doctest ViaDisplayScenic

  setup do
    ViaUtils.Registry.start_link()
    Process.sleep(100)
    ViaUtils.Comms.Supervisor.start_link(nil)
    {:ok, []}
  end

  test "greets the world" do
    config = [
      display_module: ViaDisplayScenic,
      vehicle_type: "FixedWing",
      realflight_sim: false
    ]

    ViaDisplayScenic.RootScene.Supervisor.start_link()
    Process.sleep(1500)

    ViaDisplayScenic.start_link(config)

    Process.sleep(1_000_000)
  end
end
