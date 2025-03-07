defmodule TrySyndicateWeb.FacetTreeComponent do
  use TrySyndicateWeb, :html
  alias TrySyndicate.Syndicate.{ActorDetail, Endpoint, Facet, Srcloc}
  require Logger

  # New function that returns our "constants" as a map instead of module attributes.
  defp dims do
    %{
      box_width: 500,
      horizontal_gap: 50,
      vertical_gap: 50,
      line_height: 22,
      vertical_padding: 20
    }
  end

  attr :actor, :any, required: true
  attr :submissions, :list, required: true

  def tree(assigns) do
    the_dims = dims()
    actor = resolve_srclocs(assigns.actor, assigns.submissions)
    root_id = compute_root(actor.facets)
    {levels, edges} = build_levels(root_id, actor.facets, 0, %{}, [])

    {coord_map, computed_width, computed_height} =
      assign_coordinates(levels, actor.facets, the_dims)

    svg_width = computed_width + the_dims.horizontal_gap
    svg_height = computed_height + the_dims.horizontal_gap

    # Extract dataflow connections
    dataflow_edges = extract_dataflow_edges(actor.dataflow, actor.facets)

    Logger.warning(
      "Computing dataflow edges for actor #{inspect(actor, pretty: true, charlists: :as_lists)}"
    )

    Logger.warning(
      "Dataflow edges: #{inspect(dataflow_edges, pretty: true, charlists: :as_lists)}"
    )

    assigns
    |> assign(:actor, actor)
    |> assign(:svg_width, svg_width)
    |> assign(:svg_height, svg_height)
    |> assign(:edges, edges)
    |> assign(:dataflow_edges, dataflow_edges)
    |> assign(:coord_map, coord_map)
    |> assign(:dims, the_dims)
    |> facet_tree()
  end

  def facet_tree(assigns) do
    ~H"""
    <svg width={@svg_width + 200} height={@svg_height}>
      <defs>
        <marker id="arrow" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto">
          <path d="M0,0 L0,6 L6,3 z" fill="#000" />
        </marker>
        <marker id="dataflow-arrow" markerWidth="6" markerHeight="6" refX="0" refY="3" orient="auto">
          <path d="M0,0 L0,6 L6,3 z" fill="#3366CC" />
        </marker>
      </defs>
      <g transform="translate(200,0)">
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
            <.facet_box id={id} facet={@actor.facets[id]} coord={coord} dims={@dims} />
          <% end %>
        </g>
        <g>
          <%= for {src_fid, target_fid, source_y_offset, target_y_offset, _} <- @dataflow_edges do %>
            <.dataflow_edge_line
              source_coord={@coord_map[src_fid]}
              target_coord={@coord_map[target_fid]}
              source_y_offset={source_y_offset}
              target_y_offset={target_y_offset}
              dims={@dims}
            />
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
      Enum.reduce(infos, dims.vertical_gap, fn {_ids, _w, h}, acc ->
        acc + h + dims.vertical_gap
      end)

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
    lines = 1 + 1 + length(facet.fields) + 1 + endpoint_lines(facet.eps)
    dims.vertical_padding + dims.line_height * lines
  end

  defp endpoint_lines(endpoints) do
    endpoints
    |> Enum.map(&count_lines(&1.description))
    |> Enum.sum()
  end

  defp count_lines(description) do
    description
    |> String.split("\n")
    |> length()
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
          class={"width-[#{@dims.box_width}px] height-[#{box_height(@facet, @dims)}px] text-xs p-2 text-left text-nowrap overflow-auto"}
        >
          <div class="text-center font-bold">ID: <%= @id %></div>
          <.facet_subheader>Fields:</.facet_subheader>
          <.facet_box_list>
            <%= for field <- @facet.fields do %>
              <li class="pt-1">
                <.facet_box_line><%= field.name %>: <%= field.value %></.facet_box_line>
              </li>
            <% end %>
          </.facet_box_list>
          <.facet_subheader class="">Endpoints:</.facet_subheader>
          <.facet_box_list>
            <%= for ep <- @facet.eps do %>
              <li class="pt-1">
                <.facet_box_line><%= ep.description %></.facet_box_line>
              </li>
            <% end %>
          </.facet_box_list>
        </div>
      </foreignObject>
    </g>
    """
  end

  slot :inner_block, required: true

  def facet_box_list(assigns) do
    ~H"""
    <ul class="space-y-1 divide-y divide-black divide-dashed">
      <%= render_slot(@inner_block) %>
    </ul>
    """
  end

  slot :inner_block, required: true
  attr :class, :string, default: ""

  def facet_subheader(assigns) do
    ~H"""
    <div class={"text-sm font-bold #{@class}"}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  slot :inner_block, required: true

  def facet_box_line(assigns) do
    ~H"""
    <code><pre><%= render_slot(@inner_block) %></pre></code>
    """
  end

  @spec resolve_srclocs(ActorDetail.t(), [String.t()]) :: ActorDetail.t()
  @doc """
  Replace the description of each endpoint with the source code that generated it.
  """
  def resolve_srclocs(actor, submissions) do
    facets =
      for {fid, facet} <- actor.facets, into: %{} do
        {fid, %Facet{facet | eps: Enum.map(facet.eps, &resolve_srcloc(&1, submissions))}}
      end

    %ActorDetail{actor | facets: facets}
  end

  @spec resolve_srcloc(Endpoint.t(), [String.t()]) :: Endpoint.t()
  @doc """
  Replace the description of the endpoint with the source code that generated it.
  """
  def resolve_srcloc(ep, submissions) do
    case Integer.parse(ep.src.source) do
      {n, _} ->
        submission = Enum.at(submissions, n)

        if submission do
          orig = Srcloc.resolve(submission, ep.src)
          %Endpoint{ep | description: orig}
        else
          ep
        end

      _ ->
        ep
    end
  end

  # Extract dataflow edges for visualization
  def extract_dataflow_edges(dataflow, facets) do
    dataflow
    |> Enum.flat_map(fn {src, dests} ->
      Enum.map(dests, fn {target_facet_id, target_endpoint_id} ->
        # Find which facet contains the source and its position
        case find_field_position(facets, src) do
          nil ->
            nil

          {source_facet_id, field_y_offset} ->
            # Find target endpoint position in the target facet
            endpoint_y_offset =
              find_endpoint_position(facets[target_facet_id], target_endpoint_id)

            {source_facet_id, target_facet_id, field_y_offset, endpoint_y_offset,
             target_endpoint_id}
        end
      end)
    end)
    |> Enum.filter(&(&1 != nil))
  end

  # Find which facet contains a field with the given ID and its vertical position within the facet
  def find_field_position(facets, field_id, line_height \\ dims().line_height) do
    Enum.find_value(facets, fn {facet_id, facet} ->
      # Calculate line positions for the fields section
      # Start with header lines (ID and Fields header)
      header_offset = 2 * line_height

      # Try to find the field index in the list
      field_index = Enum.find_index(facet.fields, fn field -> field.id == field_id end)

      if field_index != nil do
        # Found the field - return its position
        field_y_offset = header_offset + (field_index + 0.5) * line_height
        {facet_id, field_y_offset}
      else
        nil
      end
    end)
  end

  # Find the vertical position of an endpoint within a facet
  def find_endpoint_position(facet, endpoint_id, line_height \\ dims().line_height) do
    # Start with header lines (ID, Fields header)
    header_offset = 2 * line_height

    # Add fields section height
    fields_offset = length(facet.fields) * line_height

    # Add endpoints header
    endpoints_header_offset = line_height

    base_offset = header_offset + fields_offset + endpoints_header_offset

    # Find the endpoint index and calculate its position
    ep_idx = Enum.find_index(facet.eps, fn ep -> ep.id == endpoint_id end)
    ep_height = line_height * count_lines(Enum.at(facet.eps, ep_idx).description)

    ep_offset =
      Enum.take(facet.eps, ep_idx)
      |> Enum.map(fn ep -> line_height * count_lines(ep.description) end)
      |> Enum.sum()

    base_offset + ep_offset + ep_height / 2
  end

  attr :source_coord, :map, required: true
  attr :target_coord, :map, required: true
  attr :source_y_offset, :float, required: true
  attr :target_y_offset, :float, required: true
  attr :dims, :map, required: true

  def dataflow_edge_line(assigns) do
    ~H"""
    <path
      d={"M#{@source_coord.x} #{@source_coord.y + @source_y_offset}
         Q#{(@source_coord.x + @target_coord.x) / 2 - 100} #{(@source_coord.y + @source_y_offset + @target_coord.y + @target_y_offset) / 2},
         #{@target_coord.x - 3} #{@target_coord.y + @target_y_offset - 10}"}
      fill="none"
      stroke="#3366CC"
      stroke-width="2"
      stroke-dasharray="5,5"
      marker-end="url(#dataflow-arrow)"
    />
    """
  end
end
