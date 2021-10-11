defmodule ViaDisplayScenic.Dubins.DisplayMissionTest do
  use ExUnit.Case
  require Logger
  require ViaNavigation.Dubins.Shared.PathFollowerValues, as: PFV
  require ViaUtils.Shared.Groups, as: Groups
  alias ViaNavigation.Dubins

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
      realflight_sim: false
    ]

    ViaDisplayScenic.Supervisor.start_link(config)

    Process.sleep(1000)
    speed = 5
    turn_rate = :math.pi() / 10

    path_follower_params = [
      {PFV.k_path(), 0.05},
      {PFV.k_orbit(), 2.0},
      {PFV.chi_inf_rad(), 1.05},
      {PFV.lookahead_dt_s(), 0.5}
    ]

    dx = 100
    dy = 100
    Logger.debug("WP2-3, and WP4-5 should be should be Right-Right points")
    latlon1 = ViaUtils.Location.new_degrees(45.0, -120.0, 100)
    latlon2 = ViaUtils.Location.location_from_point_with_dx_dy(latlon1, dx, 0)
    latlon3 = ViaUtils.Location.location_from_point_with_dx_dy(latlon1, dx, dy)
    latlon4 = ViaUtils.Location.location_from_point_with_dx_dy(latlon1, 0, dy)
    latlon5 = ViaUtils.Location.location_from_point_with_dx_dy(latlon1, 0, 0)

    wp1 = Dubins.Waypoint.new_flight(latlon1, speed, 0, "wp1")
    wp2 = Dubins.Waypoint.new_flight(latlon3, speed, 0, "wp2")
    wp3 = Dubins.Waypoint.new_flight(latlon2, speed, -:math.pi(), "wp3")
    wp4 = Dubins.Waypoint.new_flight(latlon4, speed, -:math.pi(), "wp4")
    wp5 = Dubins.Waypoint.new_flight(latlon5, speed, 0, "wp5")

    mission = ViaNavigation.new_mission("default", [wp1, wp2, wp3, wp4, wp5], turn_rate)

    Logger.debug("send display_mission message")

    ViaUtils.Comms.send_local_msg_to_group(
      __MODULE__,
      {Groups.display_mission(), mission},
      self()
    )

    # route = ViaNavigation.calculate_route(mission, "Dubins", path_follower_params)
    # Logger.debug(inspect(route))
    Process.sleep(1_000_000)
  end
end
