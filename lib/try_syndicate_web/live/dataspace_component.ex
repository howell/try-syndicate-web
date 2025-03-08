defmodule TrySyndicateWeb.DataspaceComponent do
  use TrySyndicateWeb, :html
  alias TrySyndicate.Syndicate.{Dataspace, Actor, Core, SpaceTime}

  def dims() do
    dataspace_width = 1000
    assertion_action_width = dataspace_width * 2 / 5
    actor_x_offset = 10
    actor_width = 150
    dataspace_x = actor_x_offset + actor_width + 50

    %{
      actor_box_width: actor_width,
      actor_box_height: 50,
      actor_x_offset: actor_x_offset,
      vertical_spacing: 30,
      vertical_padding: 40,
      horizontal_padding: 40,
      assertions_box_x_offset: 50,
      assertions_box_width: assertion_action_width,
      assertions_line_height: 16,
      assertions_line_spacing: 10,
      assertions_box_padding: 4,
      dataspace_box_width: dataspace_width,
      dataspace_box_x: dataspace_x,
      pending_actions_box_width: assertion_action_width,
      action_height: 16,
      action_padding: 4
    }
  end

  def event_green(), do: "#50d979"
  def event_opacity(), do: "0.75"
  def action_red(), do: "#ff6161"

  attr :dataspace, Dataspace, required: true

  def dataspace(assigns) do
    the_dims = dims()

    {layout_actors, actor_height} =
      sort_and_layout_actors(assigns.dataspace.actors, assigns.dataspace.active_actor, the_dims)

    {layout_actions, actions_height} =
      sort_and_layout_actions(assigns.dataspace.pending_actions, the_dims)

    assigns
    |> assign(:svg_height, svg_height(the_dims, actor_height, actions_height))
    |> assign(:svg_width, svg_width(the_dims))
    |> assign(:dims, the_dims)
    |> assign(:actor_height, actor_height)
    |> assign(:layout_actors, layout_actors)
    |> assign(:layout_actions, layout_actions)
    |> assign(:actions_height, actions_height)
    |> render_dataspace_with_dims()
  end

  attr :svg_height, :integer, required: true
  attr :svg_width, :integer, required: true
  attr :dataspace, Dataspace, required: true
  attr :layout_actors, :list, required: true
  attr :actor_height, :integer, required: true
  attr :dims, :map, required: true

  def render_dataspace_with_dims(assigns) do
    ~H"""
    <svg
      id="ds_diagram"
      width={@svg_width}
      height={@svg_height + 40}
      viewBox={"0 0 #{@svg_width} #{@svg_height}"}
      preserveAspectRatio="xMinYMin meet"
    >
      <defs>
        <marker
          id="arrowhead-green-down"
          markerWidth="6"
          markerHeight="6"
          refX="3"
          refY="0"
          orient="0"
        >
          <polygon points="0 0, 3 6, 6 0" fill={event_green()} />
        </marker>
        <marker
          id="arrowhead-red-right"
          markerWidth="6"
          markerHeight="6"
          refX="3"
          refY="0"
          orient="-90"
        >
          <polygon points="0 0, 3 6, 6 0" fill={action_red()} />
        </marker>
      </defs>
      <g id="actors">
        <%= for {id, actor, layout} <- @layout_actors do %>
          <.actor_box
            id={id}
            actor={actor}
            layout={layout}
            dims={@dims}
            active={@dataspace.active_actor}
          />
        <% end %>
      </g>
      <.dataspace_box
        dataspace={@dataspace}
        dims={@dims}
        svg_height={@svg_height}
        layout_actions={@layout_actions}
        actions_height={@actions_height}
      />
    </svg>
    """
  end

  @spec sort_and_layout_actors(%{Dataspace.actor_id() => Actor.t()}, term(), map()) ::
          {[{Dataspace.actor_id(), Actor.t(), actor_layout()}], integer()}
  def sort_and_layout_actors(actors, active_actor, dims) do
    {actors, height} = compute_actor_layout(actors, active_actor, dims)
    {Enum.sort_by(actors, fn {_, _, layout} -> layout.c_y end), height}
  end

  attr :dataspace, Dataspace, required: true
  attr :layout_actions, :list, required: true
  attr :actions_height, :integer, required: true
  attr :svg_height, :integer, required: true
  attr :dims, :map, required: true

  def dataspace_box(assigns) do
    ~H"""
    <g id="dataspace-state">
      <rect
        x={@dims.dataspace_box_x}
        y="1"
        width={@dims.dataspace_box_width}
        height={@svg_height}
        fill="none"
        stroke="black"
        stroke-width="2"
      />
      <text
        x={@dims.dataspace_box_x + @dims.dataspace_box_width / 2}
        y="24"
        text-anchor="middle"
        font-size="18"
        font-weight="bold"
      >
        Dataspace
      </text>
      <.pending_actions_box
        dims={@dims}
        pending_actions={@layout_actions}
        actions_height={@actions_height}
      />
      <text
        :if={@dataspace.last_op}
        x={@dims.dataspace_box_x + @dims.dataspace_box_width / 2}
        y={@svg_height - 16}
        text-anchor="middle"
        font-size="16"
        font-family="monospace"
      >
        Last Operation: <%= @dataspace.last_op %>
      </text>
    </g>
    """
  end

  attr :id, :string, required: true
  attr :actor, Actor, required: true
  attr :active, :any, required: true
  attr :layout, :map, required: true
  attr :dims, :map, required: true

  def actor_box(assigns) do
    ~H"""
    <g id={"actor_#{@id}"}>
      <text
        x={@dims.actor_x_offset + @dims.actor_box_width / 2}
        y={@layout.c_y - 5}
        text-anchor="middle"
        font-size="12"
        fill="gray"
      >
        <%= @id %>
      </text>
      <rect
        x={@dims.actor_x_offset}
        y={@layout.c_y}
        width={@dims.actor_box_width}
        height={@dims.actor_box_height}
        fill={if is_active?(@id, @active), do: event_green(), else: "#eef"}
        opacity=".75"
        stroke="#333"
        rx="5"
        ry="5"
        stroke-width="2"
      />
      <text
        x={@dims.actor_x_offset + @dims.actor_box_width / 2}
        y={@layout.c_y + @dims.actor_box_height / 2}
        dominant-baseline="middle"
        text-anchor="middle"
        fill="#000"
        font-size="12"
      >
        <%= @actor.name %>
      </text>
      <line
        x1={@dims.actor_x_offset + @dims.actor_box_width}
        y1={@layout.c_y + @dims.actor_box_height / 2}
        x2={@dims.dataspace_box_x + @dims.assertions_box_x_offset}
        y2={@layout.s_y + @layout.assertions_box_height / 2}
        stroke="black"
      />
      <.assertions_box assertions={@actor.assertions} layout={@layout} dims={@dims} />
      <.event_dispatch
        :if={is_receiving_event?(@id, @active)}
        id={@id}
        dims={@dims}
        layout={@layout}
        active={@active}
      />
      <.produced_actions
        :if={is_producing_actions?(@id, @active)}
        id={@id}
        dims={@dims}
        layout={@layout}
        active={@active}
      />
    </g>
    """
  end

  def event_dispatch(assigns) do
    ~H"""
    <g>
      <.boxed_actions
        x={@dims.dataspace_box_x + @dims.assertions_box_x_offset}
        y={@layout.event_y}
        actions={[elem(@active, 1)]}
        width={@dims.assertions_box_width}
        height={@layout.event_height}
        opacity={event_opacity()}
        fill={event_green()}
      />
      <polyline
        points={event_to_actor_points(@dims, @layout)}
        stroke={event_green()}
        fill="none"
        stroke-width="2"
        marker-end="url(#arrowhead-green-down)"
      />
    </g>
    """
  end

  def produced_actions(assigns) do
    ~H"""
    <g>
      <.boxed_actions
        x={@dims.dataspace_box_x + @dims.assertions_box_x_offset}
        y={@layout.actions_y}
        actions={elem(@active, 2)}
        width={@dims.assertions_box_width}
        height={@layout.actions_height}
        opacity={event_opacity()}
        fill={action_red()}
      />
      <polyline
        points={actor_to_actions_points(@dims, @layout)}
        stroke={action_red()}
        fill="none"
        stroke-width="2"
        marker-end="url(#arrowhead-red-right)"
      />
    </g>
    """
  end

  def is_active?(actor_id, active_actor) do
    active_actor != :none && elem(active_actor, 0) == actor_id
  end

  def is_receiving_event?(actor_id, active_actor) do
    is_active?(actor_id, active_actor) && elem(active_actor, 1) != :boot
  end

  def is_producing_actions?(actor_id, active_actor) do
    is_active?(actor_id, active_actor) && elem(active_actor, 2)
  end

  def event_to_actor_points(dims, layout) do
    event_box_x = dims.dataspace_box_x + dims.assertions_box_x_offset
    event_box_mid_y = layout.event_y + layout.event_height / 2
    actor_mid_x = dims.actor_x_offset + dims.actor_box_width / 2
    before_actor_id_y = layout.c_y - 28

    "#{event_box_x},#{event_box_mid_y} #{actor_mid_x},#{event_box_mid_y} #{actor_mid_x},#{before_actor_id_y}"
  end

  defp actor_to_actions_points(dims, layout) do
    actor_box_mid_x = dims.actor_x_offset + dims.actor_box_width / 2
    actor_box_end_y = layout.c_y + dims.actor_box_height
    actions_box_x = dims.dataspace_box_x + dims.assertions_box_x_offset - 10
    actions_box_mid_y = layout.actions_y + layout.actions_height / 2

    "#{actor_box_mid_x},#{actor_box_end_y} #{actor_box_mid_x},#{actions_box_mid_y} #{actions_box_x},#{actions_box_mid_y}"
  end

  attr :dims, :map, required: true
  attr :assertions, :any, required: true
  attr :layout, :map, required: true

  def assertions_box(assigns) do
    ~H"""
    <g transform={"translate(#{@dims.dataspace_box_x + @dims.assertions_box_x_offset}, #{@layout.s_y})"}>
      <rect
        width={@dims.assertions_box_width}
        height={@layout.assertions_box_height}
        fill="white"
        stroke="#333"
        rx="3"
        ry="3"
        style="cursor:pointer;"
      />
      <foreignObject width={@dims.assertions_box_width} height={@layout.assertions_box_height}>
        <div
          xmlns="http://www.w3.org/1999/xhtml"
          class="width-full height-full text-left truncate text-xs overflow-auto"
        >
          <ul class="space-y-1 divide-y divide-slate-300 divide-dashed">
            <%= for assertion <- @assertions do %>
              <li class="pl-2 pt-1 last:pb-1"><code><pre><%= assertion %></pre></code></li>
            <% end %>
          </ul>
        </div>
      </foreignObject>
    </g>
    """
  end

  attr :dims, :map, required: true
  attr :pending_actions, :list, required: true
  attr :actions_height, :integer, required: true

  def pending_actions_box(assigns) do
    ~H"""
    <g
      id="pending-actions"
      transform={"translate(#{@dims.dataspace_box_x + @dims.dataspace_box_width - @dims.pending_actions_box_width - @dims.horizontal_padding}, #{0})"}
    >
      <text
        x={@dims.pending_actions_box_width / 2}
        y={@dims.vertical_padding / 2 + 4}
        dominant-baseline="middle"
        text-anchor="middle"
        fill="#000"
        font-size="14"
        font-weight="bold"
      >
        Pending Actions
      </text>
      <%= for {origin, actions, layout} <- @pending_actions do %>
        <.pending_actions_item origin={origin} actions={actions} layout={layout} dims={@dims} />
      <% end %>
    </g>
    """
  end

  attr :origin, SpaceTime, required: true
  attr :actions, :list, required: true
  attr :layout, :map, required: true
  attr :dims, :map, required: true

  def pending_actions_item(assigns) do
    ~H"""
    <g transform={"translate(0, #{@layout.y})"}>
      <text
        x={-2}
        y={@dims.assertions_line_height / 2}
        dominant-baseline="middle"
        text-anchor="end"
        fill="#000"
        font-size="12"
        font-family="monospace"
      >
        <%= @origin.space %>
      </text>

      <.boxed_actions
        actions={@actions}
        width={@dims.pending_actions_box_width}
        height={@layout.height}
      />
    </g>
    """
  end

  attr :x, :integer, required: false, default: 0
  attr :y, :integer, required: false, default: 0
  attr :width, :integer, required: true
  attr :height, :integer, required: true
  attr :actions, :list, required: true
  attr :fill, :string, required: false, default: "none"
  attr :opacity, :string, required: false, default: "1"

  def boxed_actions(assigns) do
    ~H"""
    <g transform={"translate(#{@x}, #{@y})"}>
      <rect
        x={0}
        y={0}
        width={@width}
        height={@height}
        fill={@fill}
        opacity={@opacity}
        stroke="black"
        stroke-width="1"
      />
      <foreignObject width={@width} height={@height}>
        <div xmlns="http://www.w3.org/1999/xhtml" class="text-left text-xs truncate overflow-auto p-2">
          <ul class="gap-y-2 divide-y divide-slate-300 divide-dashed">
            <%= for action <- @actions do %>
              <li><code><pre><%= render_action(action) %></pre></code></li>
            <% end %>
          </ul>
        </div>
      </foreignObject>
    </g>
    """
  end

  def svg_height(dims, actor_height, actions_height) do
    max(
      actor_height + 2 * dims.vertical_padding,
      actions_height + 2 * dims.vertical_padding
    )
  end

  def svg_width(dims) do
    2 * dims.dataspace_box_x + dims.dataspace_box_width
  end

  def truncate(string, length) do
    if String.length(string) > length do
      String.slice(string, 0..(length - 1)) <> "..."
    else
      string
    end
  end

  def render_action(action) do
    case action do
      {:spawn, trie} ->
        "spawn #{render_trie(trie, "", "\n      ")}"

      {:message, message} ->
        "message #{message}"

      {added, removed} ->
        updates = Enum.join(prefix_all(added, "+") ++ prefix_all(removed, "-"), "\n      ")
        "patch #{updates}"

      :quit ->
        "quit"

      :boot ->
        "boot"
    end
  end

  def render_trie(trie, prefix \\ "", joiner \\ "") do
    prefix_all(trie, prefix)
    |> Enum.join(joiner)
  end

  def prefix_all(l, prefix) do
    Enum.map(l, &(prefix <> &1))
  end

  @spec lines_for_action(Core.action()) :: non_neg_integer()
  def lines_for_action(act) do
    case act do
      {:spawn, trie} -> max(1, trie_size(trie))
      :quit -> 1
      :boot -> 1
      {:message, _message} -> 1
      {added, removed} -> max(1, trie_size(added) + trie_size(removed))
    end
  end

  @spec trie_size(Core.trie()) :: non_neg_integer()
  def trie_size(trie) do
    length(trie)
  end

  @type actor_layout() :: %{
          c_y: integer(),
          s_y: integer(),
          assertions_box_height: integer(),
          block_height: integer(),
          event_y: integer(),
          event_height: integer(),
          actions_y: integer(),
          actions_height: integer()
        }

  @spec compute_actor_layout(%{Dataspace.actor_id() => Actor.t()}, term(), map()) ::
          {[{Dataspace.actor_id(), Actor.t(), actor_layout()}], integer()}
  def compute_actor_layout(actors, active_actor, dims) do
    actor_box_height = dims[:actor_box_height]
    state_item_height = dims[:assertions_line_height]
    state_item_spacing = dims[:assertions_line_spacing]
    assertions_box_padding = dims[:assertions_box_padding]
    vertical_spacing = dims[:vertical_spacing]
    vertical_padding = dims[:vertical_padding]

    Enum.map_reduce(actors, vertical_padding, fn
      {id, actor}, y_offset ->
        assertions_box_height =
          assertions_box_padding * 2 +
            max(length(actor.assertions), 1) * state_item_height +
            max(length(actor.assertions) - 1, 0) * state_item_spacing

        {event_height, actions_height} =
          case(active_actor) do
            {^id, evt, acts} ->
              {if(is_receiving_event?(id, active_actor),
                 do: height_for_actions([evt], dims.action_height, dims.action_padding),
                 else: 0
               ),
               if(acts,
                 do: height_for_actions(acts, dims.action_height, dims.action_padding),
                 else: 0
               )}

            _ ->
              {0, 0}
          end

        event_space = if event_height > 0, do: event_height + vertical_padding, else: 0
        action_space = if actions_height > 0, do: actions_height + vertical_padding, else: 0

        block_height = max(actor_box_height, assertions_box_height + event_space + action_space)
        c_y = y_offset + event_space + max(0, assertions_box_height - actor_box_height) / 2
        s_y = y_offset + event_space + max(0, actor_box_height - assertions_box_height) / 2

        event_y =
          c_y - event_height - vertical_padding / 2 -
            max(actor_box_height, assertions_box_height) / 2

        actions_y =
          c_y + actor_box_height / 2 + max(actor_box_height, assertions_box_height) / 2 +
            vertical_padding

        layout = %{
          c_y: c_y,
          s_y: s_y,
          assertions_box_height: assertions_box_height,
          event_y: event_y,
          event_height: event_height,
          actions_y: actions_y,
          actions_height: actions_height,
          block_height: block_height
        }

        {{id, actor, layout}, y_offset + block_height + vertical_spacing + vertical_padding}
    end)
  end

  @type pending_actions_layout() :: %{y: integer(), height: integer()}

  @spec sort_and_layout_actions([{SpaceTime.t(), [Core.action()]}], map()) ::
          {[{SpaceTime.t(), [Core.action()], pending_actions_layout()}], integer()}
  def sort_and_layout_actions(pending_actions, dims) do
    action_height = dims[:action_height]
    action_padding = dims[:action_padding]
    vertical_padding = dims[:vertical_padding]

    pending_actions
    |> Enum.sort_by(fn {st, _} -> st.time end)
    |> Enum.map_reduce(vertical_padding, fn {st, actions}, y_offset ->
      height = height_for_actions(actions, action_height, action_padding)

      layout = %{y: y_offset, height: height}

      {{st, actions, layout}, y_offset + height}
    end)
  end

  def height_for_actions(actions, line_height, padding) do
    action_lines = Enum.sum(Enum.map(actions, &lines_for_action/1))
    line_height * max(1, action_lines) + 2 * padding + padding * max(0, length(actions) - 1)
  end
end
