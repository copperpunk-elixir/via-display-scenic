defmodule ViaDisplayScenic.Utils do
  require Logger
  import Scenic.Primitives
  import Scenic.Components
  require ViaDisplayScenic.Ids, as: Ids

  @rect_border 6

  def add_button_text_columns_to_graph(graph, config) do
    offset_x = config[:offset_x]
    offset_y = config[:offset_y]
    width = config[:width]
    width_text = Keyword.get(config, :width_text, width)
    height = config[:height]
    labels = config[:labels]
    font_size = config[:font_size]
    button_ids = Keyword.get(config, :button_ids, [])
    text_ids = Keyword.get(config, :text_ids, [])
    row = height / length(labels)
    v_spacing = 1
    h_spacing = 3
    label_text = Keyword.get(config, :text, Enum.map(text_ids, fn _ -> "" end))
    theme = Keyword.get(config, :theme, :secondary)

    graph =
      Enum.reduce(Enum.with_index(labels), graph, fn {label, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> button(
              label,
              id: Enum.at(button_ids, index),
              width: width - 2 * h_spacing,
              height: row - 2 * v_spacing,
              theme: theme,
              translate: {0, index * (row + v_spacing)}
            )
          end,
          translate: {offset_x + h_spacing, offset_y},
          button_font_size: font_size
        )
      end)

    graph =
      Enum.reduce(Enum.with_index(text_ids), graph, fn {id, index}, acc ->
        Logger.warn("text_id/index: #{id}/#{index}")

        group(
          acc,
          fn g ->
            g
            |> text(
              Enum.at(label_text, index),
              width: width_text,
              text_align: :center_middle,
              font_size: font_size,
              id: id,
              translate: {0, index * row}
            )
          end,
          translate: {offset_x + 1.5 * width + h_spacing, offset_y + row / 2},
          button_font_size: font_size
        )
      end)

    {graph, offset_x + width + width_text + h_spacing, offset_y + height + config[:spacer_y]}
  end

  def add_button_dropdown_columns_to_graph(graph, config) do
    offset_x = config[:offset_x]
    offset_y = config[:offset_y]
    width = config[:width]
    width_text = Keyword.get(config, :width_text, width)
    height = config[:height]
    labels = config[:labels]
    font_size = config[:font_size]
    button_ids = Keyword.get(config, :button_ids, [])
    dropdown_ids = config[:dropdown_ids]
    dropdown_items = config[:dropdown_items]
    v_spacing = 1
    h_spacing = 3
    theme = Keyword.get(config, :theme, :secondary)

    graph =
      Enum.reduce(Enum.with_index(labels), graph, fn {label, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> button(
              label,
              id: Enum.at(button_ids, index),
              width: width - 2 * h_spacing,
              height: height,
              theme: theme,
              translate: {index*width, 0}
            )
          end,
          translate: {offset_x, offset_y},
          button_font_size: font_size
        )
      end)

    graph =
      Enum.reduce(Enum.with_index(dropdown_ids), graph, fn {id, index}, acc ->
        items = dropdown_items
        initial_item = Enum.at(items, 0) |> elem(1)

        group(
          acc,
          fn g ->
            Logger.debug("items: #{inspect(items)}")

            g
            |> dropdown(
              {items, initial_item},
              width: width_text - 2*h_spacing,
              text_align: :center_middle,
              font_size: font_size,
              id: id,
              translate: {index*width, 0}
            )
          end,
          translate: {offset_x, offset_y + height}
        )
      end)

    {graph, offset_x + length(labels)*width_text + h_spacing, offset_y + 2*height + config[:spacer_y]}
  end

  def add_rows_to_graph(graph, config) do
    id = config[:id]
    offset_x = config[:offset_x]
    offset_y = config[:offset_y]
    width = config[:width]
    height = config[:height]
    labels = config[:labels]
    font_size = config[:font_size]
    ids = config[:ids]
    col = width / length(labels)
    row = height / 2
    v_spacing = 1
    h_spacing = 3
    label_text = Keyword.get(config, :text, Enum.map(ids, fn _ -> "" end))

    graph =
      Enum.reduce(Enum.with_index(ids), graph, fn {id, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> text(
              Enum.at(label_text, index),
              text_align: :center_middle,
              font_size: font_size,
              id: id,
              translate: {index * (col + h_spacing), 0}
            )
          end,
          translate: {offset_x + 0.5 * col + h_spacing, offset_y + row / 2},
          button_font_size: font_size
        )
      end)

    graph =
      Enum.reduce(Enum.with_index(labels), graph, fn {label, index}, acc ->
        group(
          acc,
          fn g ->
            g
            |> button(
              label,
              width: col - 2 * h_spacing,
              height: row - 2 * v_spacing,
              theme: :primary,
              translate: {index * (col + h_spacing), row}
            )
          end,
          translate: {offset_x + h_spacing, offset_y},
          button_font_size: font_size
        )
      end)

    graph =
      rect(
        graph,
        {width + 2 * h_spacing, height},
        id: id,
        translate: {offset_x, offset_y},
        stroke: {@rect_border, :white}
      )

    {graph, offset_x + width + 2 * h_spacing, offset_y + height + config[:spacer_y]}
  end

  def add_button_to_graph(graph, config) do
    # Logger.debug(inspect(config))

    graph =
      button(
        graph,
        config[:text],
        id: config[:id],
        width: config[:width],
        height: config[:height],
        theme: config[:theme],
        button_font_size: config[:font_size],
        translate: {config[:offset_x], config[:offset_y]}
      )

    {graph, config[:offset_x] + config[:width], config[:offset_y] + config[:height]}
  end

  def add_rectangle_to_graph(graph, config) do
    graph =
      rect(
        graph,
        {config[:width], config[:height]},
        id: config[:id],
        translate: {config[:offset_x], config[:offset_y]},
        fill: config[:fill]
      )

    {graph, config[:offset_x], config[:offset_y]}
  end

  def add_save_log_to_graph(graph, config) do
    graph =
      button(
        graph,
        "Save Log",
        id: config[:button_id],
        width: config[:button_width],
        height: config[:button_height],
        theme: :primary,
        button_font_size: config[:font_size],
        translate: {config[:offset_x], config[:offset_y]}
      )
      |> text_field(
        "",
        id: config[:text_id],
        translate: {config[:offset_x] + config[:button_width] + 10, config[:offset_y]},
        font_size: config[:font_size],
        text_align: :left,
        width: config[:text_width]
      )

    {graph, config[:offset_x], config[:offset_y] + config[:button_height]}
  end

  def add_peripheral_control_to_graph(graph, config) do
    graph =
      button(
        graph,
        "Allow PeriCtrl",
        id: config[:allow_id],
        width: config[:button_width],
        height: config[:button_height],
        theme: %{text: :white, background: :green, border: :green, active: :grey},
        button_font_size: config[:font_size],
        translate: {config[:offset_x], config[:offset_y]}
      )
      |> button(
        "Deny PeriCtrl",
        id: config[:deny_id],
        width: config[:button_width],
        height: config[:button_height],
        theme: %{text: :white, background: :red, border: :red, active: :grey},
        button_font_size: config[:font_size],
        translate: {config[:offset_x] + config[:button_width] + 10, config[:offset_y]}
      )

    {graph, config[:offset_x], config[:offset_y]}
  end

  # = :math.pi/2 + :math.atan(ratio)
  @interior_angle 2.677945
  @ratio_sq 4
  @spec draw_arrow(map(), number(), number(), number(), integer(), atom(), boolean(), atom()) ::
          Scenic.Graph.t()
  def draw_arrow(graph, x, y, heading, size, id, is_new \\ false, fill \\ :yellow) do
    # Center of triangle at X/Y
    tail_size = :math.sqrt(size * size * (1 + @ratio_sq))
    head = {x + size * :math.sin(heading), y - size * :math.cos(heading)}

    tail_1 =
      {x + tail_size * :math.sin(heading + @interior_angle),
       y - tail_size * :math.cos(heading + @interior_angle)}

    tail_2 =
      {x + tail_size * :math.sin(heading - @interior_angle),
       y - tail_size * :math.cos(heading - @interior_angle)}

    if is_new do
      triangle(graph, {head, tail_1, tail_2}, fill: fill, id: id)
    else
      Scenic.Graph.modify(graph, id, fn p ->
        triangle(p, {head, tail_1, tail_2}, fill: fill, id: id)
      end)
    end
  end

  def add_to_ip_address_last_byte(ip_address, value_to_add) do
    ip_list = String.split(ip_address, ".")
    last_byte = ip_list |> Enum.at(3) |> String.to_integer() |> Kernel.+(value_to_add)

    last_byte =
      cond do
        last_byte > 255 -> 255
        last_byte < 100 -> 100
        true -> last_byte
      end

    List.replace_at(ip_list, 3, Integer.to_string(last_byte)) |> Enum.join(".")
  end

  def go_to_scene(dest_scene_id, current_state_key, state) do
    Logger.debug("Go To #{dest_scene_id}")
    vp = state.viewport

    args =
      state.args
      |> Keyword.put(current_state_key, Map.drop(state, [:graph]))

    dest_scene = args[dest_scene_id]
    Scenic.ViewPort.set_root(vp, {dest_scene, args})
    # {:cont, event, state}
  end

  def add_sidebar(graph, vp_width, id_to_remove) do
    labels = ["MSGs", "GCS", "Planner"]
    ids = [Ids.button_go_to_msgs(), Ids.button_go_to_gcs(), Ids.button_go_to_planner()]

    {labels, ids} =
      Enum.reduce(Enum.zip(labels, ids), {[], []}, fn {label, id}, {labels_acc, ids_acc} ->
        if id != id_to_remove do
          {labels_acc ++ [label], ids_acc ++ [id]}
        else
          {labels_acc, ids_acc}
        end
      end)

    Logger.debug("#{inspect(labels)}/#{inspect(ids)}")
    ViaDisplayScenic.Utils.add_button_text_columns_to_graph(graph,
      width: 70,
      height: 3 * 50,
      offset_x: vp_width - 75,
      offset_y: 10,
      spacer_y: 20,
      theme: %{text: :white, background: :blue, active: :grey, border: :white},
      labels: labels,
      button_ids: ids,
      font_size: 19
    )
  end
end
