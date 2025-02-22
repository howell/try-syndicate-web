defmodule TrySyndicateWeb.FacetTreeComponent do
  use TrySyndicateWeb, :html

  # The actor attribute is expected to be a map of facet_id => Facet.t()
  attr :actor, :any, required: true

  @box_width 150
  @horizontal_gap 50
  @vertical_gap 50
  @line_height 16
  @vertical_padding 20  # total top+bottom padding

  def tree(assigns) do
    facets = assigns.actor

    # Compute the root facet (facet id not listed as a child anywhere)
    all_ids = Map.keys(facets)
    all_children = facets |> Map.values() |> Enum.flat_map(& &1.children)
    root_ids = all_ids -- all_children
    root_id = Enum.at(root_ids, 0) || hd(all_ids)

    {levels, edges} = build_levels(root_id, facets, 0, %{}, [])
    {coord_map, computed_width, computed_height} = assign_coordinates(levels, facets)

    margin = @horizontal_gap
    svg_width = computed_width + margin
    svg_height = computed_height + margin

    ~H"""
    <svg width={svg_width} height={svg_height}>
      <defs>
        <marker id="arrow" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto">
          <path d="M0,0 L0,6 L6,3 z" fill="#000" />
        </marker>
      </defs>
      <g>
        <%= for {parent, child} <- edges do %>
          <%= render_edge_line(coord_map[parent], coord_map[child]) %>
        <% end %>
      </g>
      <g>
        <%= for {id, coord} <- coord_map do %>
          <%= render_facet_box(id, facets[id], coord) %>
        <% end %>
      </g>
    </svg>
    """
  end

  # Helper to build a levels map and edges list.
  # levels is a map: depth => [facet_id, ...]
  defp build_levels(facet_id, facets, depth, levels, edges) do
    levels = Map.update(levels, depth, [facet_id], fn list -> list ++ [facet_id] end)
    children = facets[facet_id].children || []
    {levels, edges} =
      Enum.reduce(children, {levels, edges}, fn child, {acc_levels, acc_edges} ->
        if Map.has_key?(facets, child) do
          new_edges = [{facet_id, child} | acc_edges]
          build_levels(child, facets, depth + 1, acc_levels, new_edges)
        else
          {acc_levels, acc_edges}
        end
      end)
    {levels, edges}
  end

  # Compute dynamic box height based on content.
  defp box_height(facet) do
    # Lines: one for the ID, one for "Fields:", then one per field,
    # one for "Endpoints:" then one per endpoint.
    lines = 1 + 1 + length(facet.fields) + 1 + length(facet.eps)
    @vertical_padding + @line_height * lines
  end

  # Return list of lines for display in a facet box.
  defp box_lines(facet, id) do
    field_lines = Enum.map(facet.fields, fn field -> "#{field.name}: #{field.value}" end)
    endpoint_lines = Enum.map(facet.eps, fn ep -> ep.description end)
    [id, "Fields:"] ++ field_lines ++ ["Endpoints:"] ++ endpoint_lines
  end

  # Revised assign_coordinates: compute coordinates for each row with dynamic box heights.
  # Returns {coord_map, overall_width, total_height}
  defp assign_coordinates(levels, facets) do
    # Build row info for each level.
    row_infos =
      Enum.map(0..(map_size(levels)-1), fn depth ->
        facet_ids = Map.get(levels, depth, [])
        row_width = if length(facet_ids) > 0, do: length(facet_ids) * @box_width + (length(facet_ids) - 1) * @horizontal_gap, else: 0
        box_heights = Enum.map(facet_ids, fn fid -> box_height(facets[fid]) end)
        row_height = Enum.max(box_heights ++ [0])
        {depth, facet_ids, row_width, row_height}
      end)

    overall_width = row_infos |> Enum.map(fn {_d, _ids, w, _h} -> w end) |> Enum.max(fn -> 0 end)
    total_height = Enum.reduce(row_infos, @vertical_gap, fn {_d, _ids, _w, row_height}, acc -> acc + row_height + @vertical_gap end)

    # Now assign coordinates for each facet.
    {coord_map, _} =
      Enum.reduce(row_infos, {%{}, @vertical_gap}, fn {depth, facet_ids, row_width, row_height}, {acc, current_y} ->
        shift = (overall_width - row_width) / 2
        new_coords =
          Enum.with_index(facet_ids)
          |> Enum.reduce(%{}, fn {fid, index}, inner_acc ->
            b_height = box_height(facets[fid])
            x = shift + index * (@box_width + @horizontal_gap)
            y = current_y + (row_height - b_height) / 2
            Map.put(inner_acc, fid, %{x: x, y: y})
          end)
        {Map.merge(acc, new_coords), current_y + row_height + @vertical_gap}
      end)

    {coord_map, overall_width, total_height}
  end

  # Render an edge line from parent to child.
  defp render_edge_line(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    x1_center = x1 + @box_width / 2
    y1_bottom = y1 + 50 # TODO: y origin of line
    x2_center = x2 + @box_width / 2
    y2_top = y2
    Phoenix.HTML.raw("<line x1='#{x1_center}' y1='#{y1_bottom}' x2='#{x2_center}' y2='#{y2_top}' stroke='black' stroke-width='1' marker-end='url(#arrow)' />")
  end

  # Render a facet box using dynamic height and multiple text lines.
  defp render_facet_box(id, facet, %{x: x, y: y}) do
    bh = box_height(facet)
    lines = box_lines(facet, id)
    # Build tspan elements: first line centered, rest left aligned.
    ts =
      Enum.with_index(lines)
      |> Enum.map(fn {line, idx} ->
        cond do
          idx == 0 ->
            # ID line: centered horizontally.
            "<tspan x='#{@box_width / 2}' dy='0' text-anchor='middle' font-weight='bold'>#{line}</tspan>"
          true ->
            "<tspan x='#{5}' dy='#{@line_height}'>#{line}</tspan>"
        end
      end)
      |> Enum.join("\n")

    Phoenix.HTML.raw("""
    <g transform="translate(#{x}, #{y})">
      <rect width="#{@box_width}" height="#{bh}" fill="#EEF" stroke="#333" rx="5" ry="5" />
      <text y="#{@line_height}"font-size="12" fill="#000" style="white-space: pre;">
        #{ts}
      </text>
    </g>
    """)
  end
end
