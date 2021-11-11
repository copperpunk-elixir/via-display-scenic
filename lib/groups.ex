defmodule ViaDisplayScenic.Groups do
  @prefix :via_display_scenic
  defmacro attitude_attrate_val, do: {@prefix, :attitude_attrate_val}
  defmacro position_velocity_val, do: {@prefix, :position_velocity_val}
  defmacro attitude_throttle_cmd, do: {@prefix, :attitude_throttle_cmd}
  defmacro bodyrate_thrust_cmd, do: {@prefix, :bodyrate_thrust_cmd}
  defmacro speed_course_altitude_sideslip_cmd, do: {@prefix, :scas_cmd}
  defmacro speed_courserate_altrate_sideslip_cmd, do: {@prefix, :scrars_cmd}
end
