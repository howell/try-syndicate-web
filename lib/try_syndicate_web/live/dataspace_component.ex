defmodule TrySyndicateWeb.DataspaceComponent do
  use TrySyndicateWeb, :live_component
  alias TrySyndicate.Syndicate.{Dataspace, Actor, Core, SpaceTime}

  def dims() do
    dataspace_width = 1000
    assertion_action_width = dataspace_width * 2 / 5

    %{
      actor_box_width: 150,
      actor_box_height: 50,
      actor_x_offset: 100,
      vertical_spacing: 30,
      vertical_padding: 40,
      horizontal_padding: 40,
      assertions_box_x_offset: 10,
      assertions_box_width: assertion_action_width,
      assertions_box_height: 20,
      assertions_box_padding: 4,
      dataspace_box_width: dataspace_width,
      dataspace_box_x: 300,
      pending_actions_box_width: assertion_action_width,
      action_height: 16,
      action_padding: 4
    }
  end

  attr :dataspace, Dataspace, required: true

  def dataspace(assigns) do
    the_dims = dims()
    {layout_actors, actor_height} = sort_and_layout_actors(assigns.dataspace.actors, the_dims)

    {layout_actions, actions_height} =
      compute_pending_actions_layout(assigns.dataspace.pending_actions, the_dims)

    assigns
    |> assign(:svg_height, svg_height(assigns.dataspace, the_dims, actor_height, actions_height))
    |> assign(:dims, the_dims)
    |> assign(:actor_height, actor_height)
    |> assign(:layout_actors, layout_actors)
    |> assign(:layout_actions, layout_actions)
    |> assign(:actions_height, actions_height)
    |> render_dataspace_with_dims()
  end

  attr :svg_height, :integer, required: true
  attr :dataspace, Dataspace, required: true
  attr :layout_actors, :list, required: true
  attr :actor_height, :integer, required: true
  attr :dims, :map, required: true

  def render_dataspace_with_dims(assigns) do
    ~H"""
    <svg id="ds_diagram" width="100%" height={@svg_height}>
      <g id="actors">
        <%= for {id, actor, layout} <- @layout_actors do %>
          <.actor_box id={id} actor={actor} layout={layout} dims={@dims} />
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

  @spec sort_and_layout_actors(%{Dataspace.actor_id() => Actor.t()}, map()) ::
          {[{Dataspace.actor_id(), Actor.t(), actor_layout()}], integer()}
  def sort_and_layout_actors(actors, dims) do
    {actors, height} = compute_actor_layout(actors, dims)
    {Enum.sort_by(actors, fn {_, _, layout} -> layout.c_y end), height}
  end

  attr :dataspace, Dataspace, required: true
  attr :svg_height, :integer, required: true
  attr :dims, :map, required: true

  def dataspace_box(assigns) do
    ~H"""
    <g id="dataspace-state">
      <rect
        x={@dims.dataspace_box_x}
        y="0"
        width={@dims.dataspace_box_width}
        height={@svg_height}
        fill="none"
        stroke="black"
        stroke-width="2"
      />
      <text
        x={@dims.dataspace_box_x + @dims.dataspace_box_width / 2}
        y="20"
        text-anchor="middle"
        font-weight="bold"
      >
        Dataspace
      </text>
      <.pending_actions_box dims={@dims} pending_actions={@layout_actions} actions_height={@actions_height} />
    </g>
    """
  end

  attr :id, :string, required: true
  attr :actor, Actor, required: true
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
        fill="#eef"
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
    </g>
    """
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
          class="width-full height-full text-left text-xs overflow-auto p-2"
        >
          <ul>
            <%= for assertion <- @assertions do %>
              <li><code><pre><%= assertion %></pre></code></li>
            <% end %>
          </ul>
        </div>
      </foreignObject>
    </g>
    """
  end

  def actor_y(n, dims) do
    dims.vertical_padding + n * (dims.actor_box_height + dims.vertical_spacing)
  end

  attr :dims, :map, required: true
  attr :pending_actions, :list, required: true

  def pending_actions_box(assigns) do
    ~H"""
    <g
      id="pending-actions"
      transform={"translate(#{@dims.dataspace_box_x + @dims.dataspace_box_width - @dims.pending_actions_box_width - @dims.horizontal_padding}, #{0})"}
    >
      <text
        x={@dims.pending_actions_box_width / 2}
        y={@dims.vertical_padding / 2}
        dominant-baseline="middle"
        text-anchor="middle"
        fill="#000"
        font-size="12"
      >
        Pending Actions
      </text>
      <%= for {origin, actions, layout} <- Enum.sort_by(@pending_actions, fn {st, _, _} -> st.time end) do %>
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
        y={@dims.assertions_box_height / 2}
        dominant-baseline="middle"
        text-anchor="end"
        fill="#000"
        font-size="12"
        font-family="monospace"
      >
        <%= @origin.space %>
      </text>

      <rect
        x={0}
        y={0}
        width={@dims.pending_actions_box_width}
        height={@layout.height}
        fill="none"
        stroke="black"
        stroke-width="1"
      />
      <foreignObject width={@dims.pending_actions_box_width} height={@layout.height}>
        <div
          xmlns="http://www.w3.org/1999/xhtml"
          class="text-left text-xs overflow-auto p-2"
        >
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

  # Calculate the height of the SVG based on the number of actors and states
  def svg_height(ds, dims, actor_height, actions_height) do

    max(
      actor_height + 2 * dims.vertical_padding,
      actions_height + 2 * dims.vertical_padding

    )
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

      {:quit} ->
        "quit"

      {:message, message} ->
        "message #{message}"

      {added, removed} ->
        "patch #{render_trie(added, "+", "\n      ")}\n#{render_trie(removed, "-", "\n      ")}"
    end
  end

  def render_trie(trie, prefix \\ "", joiner \\ "") do
    Enum.map(trie, &(prefix <> &1))
    |> Enum.join(joiner)
  end

  @spec lines_for_action(Core.action()) :: non_neg_integer()
  def lines_for_action(act) do
    case act do
      {:spawn, trie} -> max(1, trie_size(trie))
      {:quit} -> 1
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
          block_height: integer()
        }

  @spec compute_actor_layout(%{Dataspace.actor_id() => Actor.t()}, map()) ::
          {[{Dataspace.actor_id(), Actor.t(), actor_layout()}], integer()}
  def compute_actor_layout(actors, dims) do
    actor_box_height = dims[:actor_box_height]
    state_item_height = dims[:assertions_box_height]
    assertions_box_padding = dims[:assertions_box_padding]
    vertical_spacing = dims[:vertical_spacing]
    vertical_padding = dims[:vertical_padding]

    Enum.map_reduce(actors, vertical_padding, fn {id, actor}, y_offset ->
      assertions_box_height =
        assertions_box_padding * 2 + max(length(actor.assertions), 1) * state_item_height

      actor_height = actor_box_height

      block_height = max(actor_box_height, assertions_box_height)
      c_y = y_offset + (block_height - actor_height) / 2
      s_y = y_offset + (block_height - assertions_box_height) / 2

      layout = %{
        c_y: c_y,
        s_y: s_y,
        assertions_box_height: assertions_box_height,
        block_height: block_height
      }

      {{id, actor, layout}, y_offset + block_height + vertical_spacing}
    end)
  end

  @type pending_actions_layout() :: %{y: integer(), height: integer()}

  @spec compute_pending_actions_layout([{SpaceTime.t(), [Core.action()]}], map()) ::
          {[{SpaceTime.t(), [Core.action()], pending_actions_layout()}], integer()}
  def compute_pending_actions_layout(pending_actions, dims) do
    action_height = dims[:action_height]
    action_padding = dims[:action_padding]
    vertical_padding = dims[:vertical_padding]

    Enum.map_reduce(pending_actions, vertical_padding, fn {st, actions}, y_offset ->
      action_lines = Enum.sum(Enum.map(actions, &lines_for_action/1))
      height = action_height * max(1, action_lines) + 2 * action_padding + action_padding * length(actions)
      layout = %{y: y_offset, height: height}

      {{st, actions, layout}, y_offset + height}
    end)
  end
end
