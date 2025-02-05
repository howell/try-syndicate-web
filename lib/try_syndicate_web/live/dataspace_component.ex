defmodule TrySyndicateWeb.DataspaceComponent do
  use TrySyndicateWeb, :live_component
  alias TrySyndicate.Syndicate.{Dataspace, Actor, Core, SpaceTime}

  def dims() do
    %{
      actor_box_width: 150,
      actor_box_height: 50,
      actor_x_offset: 100,
      vertical_spacing: 20,
      vertical_padding: 40,
      horizontal_padding: 40,
      assertions_box_x_offset: 10,
      assertions_box_width: 100,
      assertions_box_height: 40,
      dataspace_box_width: 800,
      dataspace_box_x: 300,
      pending_actions_box_width: 300,
      action_height: 20
    }
  end

  attr :dataspace, Dataspace, required: true

  def dataspace(assigns) do
    the_dims = dims()

    assigns
    |> assign(:svg_height, svg_height(assigns.dataspace, the_dims))
    |> assign(:dims, the_dims)
    |> render_dataspace_with_dims()
  end

  attr :svg_height, :integer, required: true
  attr :dataspace, Dataspace, required: true
  attr :dims, :map, required: true

  def render_dataspace_with_dims(assigns) do
    ~H"""
    <svg id="ds_diagram" width="100%" height={@svg_height}>
      <g id="actors">
        <%= for {{id, actor}, i} <- Enum.with_index(@dataspace.actors) do %>
          <.actor_box n={i} id={id} actor={actor} dims={@dims} />
        <% end %>
      </g>
      <.dataspace_box dataspace={@dataspace} dims={@dims} svg_height={@svg_height} />
    </svg>
    """
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
      <.pending_actions_box dims={@dims} pending_actions={@dataspace.pending_actions} />
    </g>
    """
  end

  attr :id, :string, required: true
  attr :n, :integer, required: true
  attr :actor, Actor, required: true
  attr :dims, :map, required: true

  def actor_box(assigns) do
    ~H"""
    <g id={"actor_#{@id}"}>
      <text
        x={@dims.actor_x_offset + @dims.actor_box_width / 2}
        y={actor_y(@n, @dims) - 5}
        text-anchor="middle"
        font-size="12"
        fill="gray"
      >
        <%= @id %>
      </text>
      <rect
        x={@dims.actor_x_offset}
        y={actor_y(@n, @dims)}
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
        y={actor_y(@n, @dims) + @dims.actor_box_height / 2}
        dominant-baseline="middle"
        text-anchor="middle"
        fill="#000"
        font-size="12"
      >
        <%= @actor.name %>
      </text>
      <line
        x1={@dims.actor_x_offset + @dims.actor_box_width}
        y1={actor_y(@n, @dims) + @dims.actor_box_height / 2}
        x2={@dims.dataspace_box_x + @dims.assertions_box_x_offset}
        y2={actor_y(@n, @dims) + @dims.actor_box_height / 2}
        stroke="black"
      />
      <.assertions_box n={@n} assertions={@actor.assertions} dims={@dims} />
    </g>
    """
  end

  attr :n, :integer, required: true
  attr :dims, :map, required: true
  attr :assertions, :any, required: true

  def assertions_box(assigns) do
    ~H"""
    <g
      id={"assertions_#{@n}"}
      transform={"translate(#{@dims.dataspace_box_x + @dims.assertions_box_x_offset}, #{actor_y(@n, @dims) + @dims.actor_box_height / 2 - @dims.assertions_box_height / 2})"}
    >
      <rect
        width={@dims.assertions_box_width}
        height={@dims.assertions_box_height}
        fill="white"
        stroke="#333"
        rx="3"
        ry="3"
        style="cursor:pointer;"
      />
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
      transform={"translate(#{@dims.dataspace_box_x + @dims.dataspace_box_width - @dims.pending_actions_box_width - @dims.horizontal_padding}, #{@dims.vertical_padding})"}
    >
      <text
        x={@dims.pending_actions_box_width / 2}
        y={-6}
        dominant-baseline="middle"
        text-anchor="middle"
        fill="#000"
        font-size="12"
      >
        Pending Actions
      </text>
      <%= for {{origin, actions}, i} <- Enum.sort_by(@pending_actions, fn {st, _} -> st.time end) |> Enum.with_index() do %>
        <rect
          x={0}
          y={i * @dims.assertions_box_height}
          width={@dims.pending_actions_box_width}
          height={max(@dims.action_height, @dims.action_height * length(actions))}
          fill="none"
          stroke="black"
          stroke-width="1"
        />
        <text
          x={-2}
          y={i * (@dims.assertions_box_height + @dims.vertical_spacing) + @dims.action_height / 2}
          dominant-baseline="middle"
          text-anchor="end"
          fill="#000"
          font-size="12"
          font-family="monospace"
        >
          <%= origin.space %>
        </text>
        <%= for {action, j} <- Enum.with_index(actions) do %>
          <text
            dominant-baseline="middle"
            text-anchor="start"
            fill="#000"
            font-size="12"
            font-family="monospace"
            x={2}
            y={
              i * (@dims.assertions_box_height + @dims.vertical_spacing) + j * @dims.action_height +
                @dims.action_height / 2
            }
          >
            <%= truncate(render_action(action), 35) %>
          </text>
        <% end %>
      <% end %>
    </g>
    """
  end

  # Calculate the height of the SVG based on the number of actors and states
  def svg_height(ds, dims) do
    num_actors = map_size(ds.actors)
    num_states = length(ds.pending_actions)

    actor_height = dims.actor_box_height + dims.vertical_spacing
    state_height = dims.assertions_box_height + dims.vertical_spacing

    max(
      num_actors * actor_height + dims.vertical_padding,
      num_states * state_height + dims.vertical_padding
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
      {:spawn, trie} -> "spawn #{render_trie(trie)}"
      {:quit} -> "quit"
      {:message, message} -> "message #{message}"
      {added, removed} -> "patch +#{render_trie(added)}, -#{render_trie(removed)}"
    end
  end

  def render_trie(trie) do
    "{#{Enum.join(trie, ",")}}"
  end
end
