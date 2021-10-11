defmodule ViaDisplayScenic.Dubins.LoadRacetrackTest do
  use ExUnit.Case
  require Logger

  setup do
    ViaUtils.Registry.start_link()
    Process.sleep(100)
    ViaUtils.Comms.Supervisor.start_link(nil)
    Process.sleep(100)
    ViaUtils.Comms.start_operator(__MODULE__)
    {:ok, []}
  end

  test "Display Mission" do
    config = [
      display_module: ViaDisplayScenic,
      vehicle_type: "FixedWing",
      realflight_sim: true
    ]

    ViaDisplayScenic.Supervisor.start_link(config)

    # route = ViaNavigation.calculate_route(mission, "Dubins", path_follower_params)
    # Logger.debug(inspect(route))
    Process.sleep(1_000_000)
  end
end
