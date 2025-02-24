defmodule TrySyndicateWeb.FacetTreeComponent do
  use TrySyndicateWeb, :html
  require Logger

  # New function that returns our "constants" as a map instead of module attributes.
  defp dims do
    %{
      box_width: 150,
      horizontal_gap: 50,
      vertical_gap: 50,
      line_height: 16,
      vertical_padding: 20
    }
  end

  attr :actor, :any, required: true

  def tree(assigns) do
    the_dims = dims()
    actor = assigns.actor
    root_id = compute_root(actor)
    {levels, edges} = build_levels(root_id, actor, 0, %{}, [])
    {coord_map, computed_width, computed_height} = assign_coordinates(levels, actor, the_dims)
    svg_width = computed_width + the_dims.horizontal_gap
    svg_height = computed_height + the_dims.horizontal_gap

    assigns
    |> assign(:actor, actor)
    |> assign(:svg_width, svg_width)
    |> assign(:svg_height, svg_height)
    |> assign(:edges, edges)
    |> assign(:coord_map, coord_map)
    |> assign(:dims, the_dims)
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
            <.edge_line
              parent_coord={@coord_map[parent]}
              child_coord={@coord_map[child]}
              dims={@dims}
            />
          <% end %>
        </g>
        <g>
          <%= for {id, coord} <- @coord_map do %>
            <.facet_box id={id} facet={@actor[id]} coord={coord} dims={@dims} />
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
  defp assign_coordinates(levels, facets, dims) do
    {overall_width, total_height, infos} = overall_dimensions(levels, facets, dims)

    {coord_map, _} =
      Enum.reduce(Enum.with_index(infos), {%{}, dims.vertical_gap}, fn
        {row_detail = {_fids, _width, row_height}, _depth}, {acc, current_y} ->
          new_coords = row_coords(facets, overall_width, row_detail, current_y, dims)
          {Map.merge(acc || %{}, new_coords), current_y + row_height + dims.vertical_gap}
      end)

    {coord_map, overall_width, total_height}
  end

  # Helper: computes the overall (max) row width and total height from all rows.
  defp overall_dimensions(levels, facets, dims) do
    depths = 0..(map_size(levels) - 1)
    infos = Enum.map(depths, &row_info(&1, levels, facets, dims))
    max_width = infos |> Enum.map(fn {_ids, w, _h} -> w end) |> Enum.max(fn -> 0 end)

    total_height =
      Enum.reduce(infos, dims.vertical_gap, fn {_ids, _w, h}, acc -> acc + h + dims.vertical_gap end)

    {max_width, total_height, infos}
  end

  # Helper: given a depth, returns {facet_ids, row_width, row_height}
  defp row_info(depth, levels, facets, dims) do
    facet_ids = Map.get(levels, depth, [])

    row_width =
      if facet_ids == [] do
        0
      else
        length(facet_ids) * dims.box_width + (length(facet_ids) - 1) * dims.horizontal_gap
      end

    box_heights = Enum.map(facet_ids, fn fid -> box_height(facets[fid], dims) end)
    row_height = Enum.max(box_heights ++ [0])
    {facet_ids, row_width, row_height}
  end

  defp row_coords(
         facets,
         overall_width,
         _row_info = {facet_ids, row_width, row_height},
         current_y,
         dims
       ) do
    shift = (overall_width - row_width) / 2

    Enum.with_index(facet_ids)
    |> Enum.reduce(%{}, fn {fid, idx}, inner_acc ->
      b_height = box_height(facets[fid], dims)
      x = shift + idx * (dims.box_width + dims.horizontal_gap)
      y = current_y + (row_height - b_height) / 2
      Map.put(inner_acc, fid, %{x: x, y: y})
    end)
  end

  # Compute dynamic box height based on content.
  defp box_height(facet, dims) do
    lines = 1 + 1 + length(facet.fields) + 1 + length(facet.eps)
    dims.vertical_padding + dims.line_height * lines
  end

  attr :parent_coord, :map, required: true
  attr :child_coord, :map, required: true
  attr :dims, :map, required: true

  def edge_line(assigns) do
    ~H"""
    <line
      x1={@parent_coord.x + @dims.box_width / 2}
      y1={@parent_coord.y + 50}
      x2={@child_coord.x + @dims.box_width / 2}
      y2={@child_coord.y}
      stroke="black"
      stroke-width="1"
      marker-end="url(#arrow)"
    />
    """
  end

  attr :id, :string, required: true
  attr :facet, :any, required: true
  attr :coord, :map, required: true
  attr :dims, :map, required: true

  def facet_box(assigns) do
    ~H"""
    <g transform={"translate(#{@coord.x}, #{@coord.y})"}>
      <rect
        width={@dims.box_width}
        height={box_height(@facet, @dims)}
        fill="#EEF"
        stroke="#333"
        rx="5"
        ry="5"
      />
      <foreignObject x="0" y="0" width={@dims.box_width} height={box_height(@facet, @dims)}>
        <div
          xmlns="http://www.w3.org/1999/xhtml"
          style="font-size:12px; padding:4px; box-sizing:border-box;"
        >
          <div style="text-align:center; font-weight:bold; margin-bottom:4px;"><%= @id %></div>
          <div style="font-weight:bold;">Fields:</div>
          <ul style="margin:0; padding-left:16px;">
            <%= for field <- @facet.fields do %>
              <li><%= field.name %>: <%= to_string(field.value) %></li>
            <% end %>
          </ul>
          <div style="font-weight:bold; margin-top:4px;">Endpoints:</div>
          <ul style="margin:0; padding-left:16px;">
            <%= for ep <- @facet.eps do %>
              <li><%= ep.description %></li>
            <% end %>
          </ul>
        </div>
      </foreignObject>
    </g>
    """
  end
end
