defmodule ViaDisplayScenic.Gcs.FixedWing.Utils do
  import Scenic.Primitives
  require ViaDisplayScenic.Ids, as: Ids
  @font_size 19
  @battery_font_size 20

  def build_graph(vp_width, vp_height, args) do
    label_value_width = 125
    label_value_height = 40
    goals_width = 400
    goals_height = 40
    battery_width = 400
    battery_height = 40
    ip_width = 100
    ip_height = 30
    modify_ip_width = 50
    modify_ip_height = ip_height
    reset_estimation_width = 160
    reset_estimation_height = ip_height - 5
    go_to_planner_width = 80
    go_to_planner_height = ip_height * 2
    cluster_status_side = 100
    # build the graph
    offset_x_origin = 10
    offset_y_origin = 10
    spacer_y = 20
    sidebar_width = 70
    sidebar_height = 50

    graph =
      Scenic.Graph.build()
      |> rect({vp_width, vp_height})

    {graph, _offset_x, offset_y} =
      ViaDisplayScenic.Utils.add_button_text_columns_to_graph(graph,
        width: label_value_width,
        height: 4 * label_value_height,
        offset_x: offset_x_origin,
        offset_y: offset_y_origin,
        spacer_y: spacer_y,
        labels: ["latitude", "longitude", "altitude", "AGL"],
        text_ids: [
          Ids.text_lat_deg(),
          Ids.text_lon_deg(),
          Ids.text_altitude_m(),
          Ids.text_agl_m()
        ],
        font_size: @font_size
      )

    {graph, _offset_x, offset_y} =
      ViaDisplayScenic.Utils.add_button_text_columns_to_graph(graph,
        width: label_value_width,
        height: 3 * label_value_height,
        offset_x: offset_x_origin,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["airspeed", "speed", "course"],
        text_ids: [Ids.text_airspeed_mps(), Ids.text_groundspeed_mps(), Ids.text_course_deg()],
        font_size: @font_size
      )

    {graph, _offset_x, _offset_y} =
      ViaDisplayScenic.Utils.add_button_text_columns_to_graph(graph,
        width: label_value_width,
        height: 3 * label_value_height,
        offset_x: offset_x_origin,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["roll", "pitch", "yaw"],
        text_ids: [Ids.text_roll_deg(), Ids.text_pitch_deg(), Ids.text_yaw_deg()],
        font_size: @font_size
      )

    goals_offset_x = 60 + 2 * label_value_width

    {graph, _offset_x, offset_y} =
      ViaDisplayScenic.Utils.add_rows_to_graph(graph,
        id: {:goals, 4},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y_origin,
        spacer_y: spacer_y,
        labels: ["speed", "course rate", "altitude rate", "sideslip"],
        ids: [
          Ids.text_groundspeed_4_cmd_mps(),
          Ids.text_courserate_cmd_dps(),
          Ids.text_altrate_cmd_mps(),
          Ids.text_sideslip_4_cmd_deg()
        ],
        font_size: @font_size
      )

    {graph, _offset_x, offset_y} =
      ViaDisplayScenic.Utils.add_rows_to_graph(graph,
        id: {:goals, 3},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["speed", "course", "altitude", "sideslip"],
        ids: [
          Ids.text_groundspeed_3_cmd_mps(),
          Ids.text_course_cmd_deg(),
          Ids.text_altitude_cmd_m(),
          Ids.text_sideslip_3_cmd_deg()
        ],
        font_size: @font_size
      )

    {graph, _offset_x, offset_y} =
      ViaDisplayScenic.Utils.add_rows_to_graph(graph,
        id: {:goals, 2},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["thrust", "roll", "pitch", "yaw"],
        ids: [
          Ids.text_thrust_cmd_pct(),
          Ids.text_roll_cmd_deg(),
          Ids.text_pitch_cmd_deg(),
          Ids.text_deltayaw_cmd_deg()
        ],
        font_size: @font_size
      )

    {graph, _offset_x, offset_y} =
      ViaDisplayScenic.Utils.add_rows_to_graph(graph,
        id: {:goals, 1},
        width: goals_width,
        height: 2 * goals_height,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ["throttle", "rollrate", "pitchrate", "yawrate"],
        ids: [
          Ids.text_throttle_cmd_pct(),
          Ids.text_rollrate_cmd_dps(),
          Ids.text_pitchrate_cmd_dps(),
          Ids.text_yawrate_cmd_dps()
        ],
        font_size: @font_size
      )

    {graph, _offset_x, _offset_y} = ViaDisplayScenic.Utils.add_sidebar(graph, vp_width, Ids.button_go_to_gcs)

    {ip_labels, ip_text, ip_ids} =
      if Keyword.get(args, :realflight_sim, false) do
        {["Host IP", "RealFlight IP"], ["searching...", "waiting..."],
         [Ids.text_host_ip(), Ids.text_realflight_ip()]}
      else
        {["Host IP"], ["searching..."], [Ids.text_host_ip()]}
      end

    offset_y_bottom_row = offset_y

    {graph, offset_x, _offset_y} =
      ViaDisplayScenic.Utils.add_button_text_columns_to_graph(graph,
        width: 100,
        width_text: ip_width,
        height: ip_height * 2,
        offset_x: goals_offset_x,
        offset_y: offset_y,
        spacer_y: spacer_y,
        labels: ip_labels,
        text: ip_text,
        ids: ip_ids,
        font_size: @font_size
      )

    {graph, offset_x_reset_est, offset_y} =
      ViaDisplayScenic.Utils.add_button_to_graph(graph,
        text: "Reset Estimation",
        id: Ids.button_reset_estimation(),
        theme: %{text: :black, background: :white, active: :grey, border: :white},
        width: reset_estimation_width,
        height: reset_estimation_height,
        font_size: @font_size,
        offset_x: offset_x + 30,
        offset_y: offset_y
      )

    offset_y = offset_y + 5

    graph =
      if Keyword.get(args, :realflight_sim, false) do
        {graph, offset_x, _offset_y} =
          ViaDisplayScenic.Utils.add_button_to_graph(graph,
            text: "+",
            id: {Ids.button_modify_realflight_ip(), 1},
            theme: %{text: :white, background: :green, active: :grey, border: :white},
            width: modify_ip_width,
            height: modify_ip_height,
            font_size: @font_size + 5,
            offset_x: offset_x + 30,
            offset_y: offset_y
          )

        {graph, offset_x, _offset_y} =
          ViaDisplayScenic.Utils.add_button_to_graph(graph,
            text: "-",
            id: {Ids.button_modify_realflight_ip(), -1},
            theme: %{text: :white, background: :red, active: :grey, border: :white},
            width: modify_ip_width,
            height: modify_ip_height,
            font_size: @font_size + 5,
            offset_x: offset_x + 5,
            offset_y: offset_y
          )

        # {graph, offset_x, _offset_y} =
        ViaDisplayScenic.Utils.add_button_to_graph(graph,
          text: "Set IP",
          id: Ids.button_set_realflight_ip(),
          theme: %{text: :white, background: :blue, active: :grey, border: :white},
          width: modify_ip_width,
          height: modify_ip_height,
          font_size: @font_size,
          offset_x: offset_x + 5,
          offset_y: offset_y
        )

        # {graph, _offset_x, _offset_y} =
        #   ViaDisplayScenic.Utils.add_button_to_graph(graph, [
        #     text: "Planner",
        #     id: :go_to_planner,
        #     theme: %{text: :white, background: :blue, active: :grey, border: :white},
        #     width: go_to_planner_width,
        #     height: go_to_planner_height,
        #     font_size: @font_size,
        #     offset_x: offset_x + 5,
        #     offset_y: offset_y_bottom_row
        #   ])

        graph
      else
        graph
      end

    graph
    # cluster_status_offset_x = vp_width - cluster_status_side - 40
    # cluster_status_offset_y = vp_height - cluster_status_side - 20

    # {graph, _offset_x, _offset_y} =
    #   ViaDisplayScenic.Utils.add_rectangle_to_graph(graph, %{
    #     id: :cluster_status,
    #     width: cluster_status_side,
    #     height: cluster_status_side,
    #     offset_x: cluster_status_offset_x,
    #     offset_y: cluster_status_offset_y,
    #     fill: :red
    #   })

    # # Save Log
    # {graph, _offset_x, button_offset_y} =
    #   ViaDisplayScenic.Utils.add_save_log_to_graph(graph, %{
    #     button_id: :save_log,
    #     text_id: :save_log_filename,
    #     button_width: 100,
    #     button_height: 35,
    #     offset_x: 10,
    #     offset_y: vp_height - 100,
    #     font_size: @font_size,
    #     text_width: 400
    #   })

    # {graph, _offset_x, _offset_y} =
    #   ViaDisplayScenic.Utils.add_peripheral_control_to_graph(graph, %{
    #     allow_id: {:peri_ctrl, :allow},
    #     deny_id: {:peri_ctrl, :deny},
    #     button_width: 150,
    #     button_height: 35,
    #     offset_x: 10,
    #     offset_y: button_offset_y + 10,
    #     font_size: @font_size,
    #     text_width: 400
    #   })

    # batteries = ["cluster", "motor"]

    # {graph, _offset_x, _offset_y} =
    #   Enum.reduce(batteries, {graph, goals_offset_x, offset_y}, fn battery,
    #                                                                {graph, off_x, off_y} ->
    #     ids = [{battery, :V}, {battery, :I}, {battery, :mAh}]
    #     # battery_str = Atom.to_string(battery)
    #     labels = [battery <> " V", battery <> " I", battery <> " mAh"]

    #     ViaDisplayScenic.Utils.add_rows_to_graph(graph, %{
    #       id: {:battery, battery},
    #       width: battery_width,
    #       height: 2 * battery_height,
    #       offset_x: off_x,
    #       offset_y: off_y,
    #       spacer_y: spacer_y,
    #       labels: labels,
    #       ids: ids,
    #       font_size: @battery_font_size
    #     })
    #   end)
  end
end
