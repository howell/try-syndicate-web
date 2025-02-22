defmodule TrySyndicateWeb.FacetTreeComponent do
  use TrySyndicateWeb, :html

  # The actor attribute is expected to be a map of facet_id => Facet.t()
  attr :actor, :any, required: true

  @box_width 150
  @box_height 100
  @horizontal_gap 50
  @vertical_gap 50

  # Updated tree/1 to use dynamic SVG width from assign_coordinates
  def tree(assigns) do
    facets = assigns.actor

    # Compute the root facet (facet id not listed as a child anywhere)
    all_ids = Map.keys(facets)
    all_children = facets |> Map.values() |> Enum.flat_map(& &1.children)
    root_ids = all_ids -- all_children
    root_id = Enum.at(root_ids, 0) || hd(all_ids)

    {levels, edges} = build_levels(root_id, facets, 0, %{}, [])
    {coord_map, computed_width} = assign_coordinates(levels)

    margin = @horizontal_gap
    svg_width = computed_width + margin

    svg_height =
      (coord_map
       |> Map.values()
       |> Enum.map(fn %{y: y} -> y end)
       |> Enum.max(fn -> 0 end)) + @box_height + @vertical_gap

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
        # Only include children present in facets
        if Map.has_key?(facets, child) do
          new_edges = [{facet_id, child} | acc_edges]
          build_levels(child, facets, depth + 1, acc_levels, new_edges)
        else
          {acc_levels, acc_edges}
        end
      end)

    {levels, edges}
  end

  # Revised assign_coordinates: compute coordinates for each row and return {coord_map, total_width}
  defp assign_coordinates(levels) do
    # First, compute each row's total width (without centering)
    row_widths =
      Enum.map(levels, fn {depth, facet_ids} ->
        row_width = length(facet_ids) * @box_width + (length(facet_ids) - 1) * @horizontal_gap
        {depth, row_width}
      end)

    overall_width =
      row_widths
      |> Enum.map(fn {_depth, w} -> w end)
      |> Enum.max(fn -> 0 end)

    # Now build coordinate map with each row centered relative to the overall_width
    coord_map =
      Enum.reduce(levels, %{}, fn {depth, facet_ids}, acc ->
        row_width = length(facet_ids) * @box_width + (length(facet_ids) - 1) * @horizontal_gap
        shift = (overall_width - row_width) / 2
        y = depth * (@box_height + @vertical_gap) + @vertical_gap

        Enum.with_index(facet_ids)
        |> Enum.reduce(acc, fn {facet_id, index}, acc_inner ->
          x = shift + index * (@box_width + @horizontal_gap)
          Map.put(acc_inner, facet_id, %{x: x, y: y})
        end)
      end)

    {coord_map, overall_width}
  end

  # Render an edge line from parent to child.
  defp render_edge_line(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    # Connect from bottom center of parent to top center of child.
    x1_center = x1 + @box_width / 2
    y1_bottom = y1 + @box_height
    x2_center = x2 + @box_width / 2
    y2_top = y2

    Phoenix.HTML.raw(
      "<line x1='#{x1_center}' y1='#{y1_bottom}' x2='#{x2_center}' y2='#{y2_top}' stroke='black' stroke-width='1' marker-end='url(#arrow)' />"
    )
  end

  # Render a facet box with its ID, fields, and endpoints.
  defp render_facet_box(id, facet, %{x: x, y: y}) do
    fields =
      facet.fields
      |> Enum.map(fn field -> "#{field.name}: #{inspect(field.value)}" end)
      |> Enum.join("\n")

    endpoints =
      facet.eps
      |> Enum.map(fn ep -> ep.description end)
      |> Enum.join("\n")

    content = "ID: #{id}\n#{fields}\n#{endpoints}"

    Phoenix.HTML.raw("""
    <g transform="translate(#{x}, #{y})">
      <rect width="#{@box_width}" height="#{@box_height}" fill="#EEF" stroke="#333" rx="5" ry="5" />
      <text x="5" y="15" font-size="12" fill="#000" style="white-space: pre;">
        #{content}
      </text>
    </g>
    """)
  end
end
