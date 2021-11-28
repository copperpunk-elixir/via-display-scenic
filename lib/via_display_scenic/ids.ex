defmodule ViaDisplayScenic.Ids do
  alias ViaTelemetry.Ubx.VehicleCmds, as: VehicleCmds
  alias ViaTelemetry.Ubx.VehicleState, as: VehicleState
  require VehicleState.AttitudeAttrateVal, as: AttitudeAttrateVal
  require VehicleState.PositionVelocityVal, as: PositionVelocityVal
  require VehicleCmds.AttitudeThrustCmd, as: AttitudeThrustCmd
  require VehicleCmds.BodyrateThrottleCmd, as: BodyrateThrottleCmd
  require VehicleCmds.SpeedCourseAltitudeSideslipCmd, as: SCASCmd
  require VehicleCmds.SpeedCourserateAltrateSideslipCmd, as: SCrArSCmd

  defmacro button_go_to(), do: :buttton_go_to
  defmacro planner_scene(), do: :planner_scene
  defmacro gcs_scene(), do: :gcs_scene
  defmacro messages_scene(), do: :messages_scene
  defmacro message_rate_dropdown(), do: :message_rate_

  defmacro button_go_to_gcs(), do: {button_go_to(), gcs_scene()}
  defmacro button_go_to_msgs(), do: {button_go_to(), messages_scene()}
  defmacro button_go_to_planner(), do: {button_go_to(), planner_scene()}
  defmacro button_load_racetrack(), do: :button_load_racetrack
  defmacro button_modify_realflight_ip(), do: :button_modify_realflight_ip
  defmacro button_reset_estimation(), do: :button_reset_estimation
  defmacro button_set_realflight_ip(), do: :button_set_realflight_ip

  defmacro dropdown_attitude_attrate_val(),
    do:
      Macro.escape({message_rate_dropdown(), AttitudeAttrateVal.class(), AttitudeAttrateVal.id()})

  defmacro dropdown_position_velocity_val(),
    do:
      Macro.escape(
        {message_rate_dropdown(), PositionVelocityVal.class(), PositionVelocityVal.id()}
      )

  defmacro dropdown_attitude_thrust_cmd(),
    do: Macro.escape({message_rate_dropdown(), AttitudeThrustCmd.class(), AttitudeThrustCmd.id()})

  defmacro dropdown_bodyrate_throttle_cmd(),
    do:
      Macro.escape(
        {message_rate_dropdown(), BodyrateThrottleCmd.class(), BodyrateThrottleCmd.id()}
      )

  defmacro dropdown_speed_course_altitude_sideslip_cmd(),
    do: Macro.escape({message_rate_dropdown(), SCASCmd.class(), SCASCmd.id()})

  defmacro dropdown_speed_courserate_altrate_sideslip_cmd(),
    do: Macro.escape({message_rate_dropdown(), SCrArSCmd.class(), SCrArSCmd.id()})

  defmacro text_agl_m(), do: :text_agl_m
  defmacro text_airspeed_mps(), do: :text_airspeed_mps
  defmacro text_altitude_m(), do: :text_altitude_m
  defmacro text_altitude_cmd_m(), do: :text_altitude_cmd_m
  defmacro text_altrate_cmd_mps(), do: :text_altrate_cmd_mps
  defmacro text_course_deg(), do: :text_course_deg
  defmacro text_course_cmd_deg(), do: :text_course_cmd_deg
  defmacro text_courserate_cmd_dps(), do: :text_courserate_cmd_dps
  defmacro text_deltayaw_cmd_deg(), do: :text_deltayaw_cmd_deg
  defmacro text_groundspeed_mps(), do: :text_groundspeed_mps
  defmacro text_groundspeed_3_cmd_mps(), do: :text_groundspeed_3_cmd_mps

  defmacro text_groundspeed_4_cmd_mps(), do: :text_groundspeed_4_cmd_mps
  defmacro text_host_ip(), do: :text_host_ip
  defmacro text_lat_deg(), do: :text_lat_deg
  defmacro text_lon_deg(), do: :text_lon_deg
  defmacro text_pitch_deg(), do: :text_pitch_deg
  defmacro text_pitch_cmd_deg(), do: :text_pitch_cmd_deg
  defmacro text_pitchrate_cmd_dps(), do: :text_pitchrate_cmd_dps
  defmacro text_realflight_ip(), do: :text_realflight_ip
  defmacro text_roll_deg(), do: :text_roll_deg
  defmacro text_roll_cmd_deg(), do: :text_roll_cmd_deg
  defmacro text_rollrate_cmd_dps(), do: :text_rollrate_cmd_dps
  defmacro text_sideslip_3_cmd_deg(), do: :text_sideslip_3_cmd_deg
  defmacro text_sideslip_4_cmd_deg(), do: :text_sideslip_4_cmd_deg
  defmacro text_throttle_cmd_pct(), do: :text_throttle_cmd_pct
  defmacro text_thrust_cmd_pct(), do: :text_thrust_cmd_pct
  defmacro text_yaw_deg(), do: :text_yaw_deg
  defmacro text_yawrate_cmd_dps(), do: :text_yawrate_dps
end
