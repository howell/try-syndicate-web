defmodule TrySyndicateWeb.FacetTreeComponent do
require Logger
  use TrySyndicateWeb, :html

  @box_width 150
  @horizontal_gap 50
  @vertical_gap 50
  @line_height 16
  @vertical_padding 20

  attr :actor, :any, required: true

  def tree(assigns) do
    actor = assigns.actor
    root_id = compute_root(actor)
    {levels, edges} = build_levels(root_id, actor, 0, %{}, [])
    {coord_map, computed_width, computed_height} = assign_coordinates(levels, actor)
    svg_width = computed_width + @horizontal_gap
    svg_height = computed_height + @horizontal_gap

    assigns
    |> assign(:actor, actor)
    |> assign(:svg_width, svg_width)
    |> assign(:svg_height, svg_height)
    |> assign(:edges, edges)
    |> assign(:coord_map, coord_map)
    |> facet_tree()
  end

  def facet_tree(assigns) do
    ~H"""
    <svg width={@svg_width} height={@svg_height}>
      <defs>
        <marker id="arrow" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto">
          <path d="M0,0 L0,6 L6,3 z" fill="#000" />
        </marker>
      </defs>
      <g transform="translate(2,0)">
        <g>
          <%= for {parent, child} <- @edges do %>
            <%= render_edge_line(@coord_map[parent], @coord_map[child]) %>
          <% end %>
        </g>
        <g>
          <%= for {id, coord} <- @coord_map do %>
            <%= render_facet_box(id, @actor[id], coord) %>
          <% end %>
        </g>
      </g>
    </svg>
    """
  end

  # Helper to compute the root facet id.
  defp compute_root(facets) do
    all_ids = Map.keys(facets)
    all_children = facets |> Map.values() |> Enum.flat_map(& &1.children)

    case all_ids -- all_children do
      [] -> hd(all_ids)
      [root | _] -> root
    end
  end

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

  # Simplified assign_coordinates: assign coordinates per row using helpers.
  defp assign_coordinates(levels, facets) do
    {overall_width, total_height, infos} = overall_dimensions(levels, facets)

    {coord_map, _} =
      Enum.reduce(Enum.with_index(infos), {%{}, @vertical_gap}, fn
        {row_detail = {_fids, _width, row_height}, _depth}, {acc, current_y} ->
          new_coords = row_coords(facets, overall_width, row_detail, current_y)
          {Map.merge(acc || %{}, new_coords), current_y + row_height + @vertical_gap}
      end)

    {coord_map, overall_width, total_height}
  end

  # Helper: computes the overall (max) row width and total height from all rows.
  defp overall_dimensions(levels, facets) do
    depths = 0..(map_size(levels) - 1)
    infos = Enum.map(depths, &row_info(&1, levels, facets))
    max_width = infos |> Enum.map(fn {_ids, w, _h} -> w end) |> Enum.max(fn -> 0 end)

    total_height =
      Enum.reduce(infos, @vertical_gap, fn {_ids, _w, h}, acc -> acc + h + @vertical_gap end)

    {max_width, total_height, infos}
  end

  # Helper: given a depth, returns {facet_ids, row_width, row_height}
  defp row_info(depth, levels, facets) do
    facet_ids = Map.get(levels, depth, [])

    row_width =
      if facet_ids == [] do
        0
      else
        length(facet_ids) * @box_width + (length(facet_ids) - 1) * @horizontal_gap
      end

    box_heights = Enum.map(facet_ids, fn fid -> box_height(facets[fid]) end)
    row_height = Enum.max(box_heights ++ [0])
    {facet_ids, row_width, row_height}
  end

  defp row_coords(
         facets,
         overall_width,
         _row_info = {facet_ids, row_width, row_height},
         current_y
       ) do
    shift = (overall_width - row_width) / 2

    Enum.with_index(facet_ids)
    |> Enum.reduce(%{}, fn {fid, idx}, inner_acc ->
      b_height = box_height(facets[fid])
      x = shift + idx * (@box_width + @horizontal_gap)
      Logger.warning(("current_y: #{inspect(current_y)}, row_height: #{inspect(row_height)}, b_height: #{inspect(b_height)}"))
      y = current_y + (row_height - b_height) / 2
      Map.put(inner_acc, fid, %{x: x, y: y})
    end)
  end

  # Compute dynamic box height based on content.
  defp box_height(facet) do
    lines = 1 + 1 + length(facet.fields) + 1 + length(facet.eps)
    @vertical_padding + @line_height * lines
  end

  # Render an edge line from parent to child.
  defp render_edge_line(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    x1_center = x1 + @box_width / 2
    # Adjust y1_bottom by computing parent's dynamic height from box_height if needed.
    y1_bottom = y1 + 50
    x2_center = x2 + @box_width / 2
    y2_top = y2

    Phoenix.HTML.raw(
      "<line x1='#{x1_center}' y1='#{y1_bottom}' x2='#{x2_center}' y2='#{y2_top}' stroke='black' stroke-width='1' marker-end='url(#arrow)' />"
    )
  end

  # Revised render_facet_box to use foreignObject with HTML for rendering facet details.
  defp render_facet_box(id, facet, %{x: x, y: y}) do
    bh = box_height(facet)

    fields_html =
      facet.fields
      |> Enum.map(fn field -> "<li>#{field.name}: #{to_string(field.value)}</li>" end)
      |> Enum.join("")

    endpoints_html =
      facet.eps
      |> Enum.map(fn ep -> "<li>#{ep.description}</li>" end)
      |> Enum.join("")

    Phoenix.HTML.raw("""
    <g transform="translate(#{x}, #{y})">
      <rect width="#{@box_width}" height="#{bh}" fill="#EEF" stroke="#333" rx="5" ry="5" />
      <foreignObject x="0" y="0" width="#{@box_width}" height="#{bh}">
        <div xmlns="http://www.w3.org/1999/xhtml" style="font-size:12px; padding:4px; box-sizing:border-box;">
          <div style="text-align:center; font-weight:bold; margin-bottom:4px;">#{id}</div>
          <div style="font-weight:bold;">Fields:</div>
          <ul style="margin:0; padding-left:16px;">#{fields_html}</ul>
          <div style="font-weight:bold; margin-top:4px;">Endpoints:</div>
          <ul style="margin:0; padding-left:16px;">#{endpoints_html}</ul>
        </div>
      </foreignObject>
    </g>
    """)
  end

  # ...existing code for DataspaceComponent and others remains unchanged...
end
