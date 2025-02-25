defmodule TrySyndicateWeb.TraceViewComponent do
  use TrySyndicateWeb, :live_component

  alias TrySyndicate.Syndicate.DataspaceTrace
  alias TrySyndicateWeb.{DataspaceComponent, FacetTreeComponent}

  def trace_view(assigns) do
    ~H"""
    <div class="mt-4 w-auto mx-auto flex flex-col gap-4 items-center">
      <h2 class="text-center text-2xl">Execution State</h2>
      <div class="flex flex-row items-center gap-4">
        <.trace_button label="First" action="step_first" disabled={@current_trace_step == 0} />
        <.trace_button label="Previous" action="step_prev" disabled={@current_trace_step == 0} />
        <span class="text-lg text-center">
          <%= @current_trace_step + 1 %> / <%= map_size(@trace_steps.filtered) %>
        </span>
        <.trace_button
          label="Next"
          action="step_next"
          disabled={@current_trace_step == map_size(@trace_steps.filtered) - 1}
        />
        <.trace_button
          label="Current"
          action="step_current"
          disabled={@current_trace_step == map_size(@trace_steps.filtered) - 1}
        />
      </div>
      <div class="w-dvw h-auto mx-auto overflow-x-auto">
        <DataspaceComponent.dataspace dataspace={elem(@trace_steps.filtered[@current_trace_step], 0)} />
      </div>
      <div class="flex flex-row items-start w-full ml-20">
        <.trace_filter trace_steps={@trace_steps} trace_filter_open={@trace_filter_open} />
      </div>
      <div class="flex flex-col w-full h-auto mx-auto overflow-x-auto">
        <.actor_explorer
          trace={@trace_steps}
          current_step={@current_trace_step}
          selected_actor={@selected_actor}
        />
        <.actors_view trace={@trace_steps} current_step={@current_trace_step} />
      </div>
    </div>
    """
  end

  def trace_button(assigns) do
    ~H"""
    <button
      type="button"
      class={"rounded bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 #{if @disabled, do: "invisible", else: ""}"}
      phx-click={@action}
      disabled={@disabled}
    >
      <%= @label %>
    </button>
    """
  end

  def trace_filter(assigns) do
    ~H"""
    <div class="mt-4 p-4">
      <button type="button" class="mb-2 font-bold gap-2" phx-click="toggle_trace_filter">
        Trace Filter
        <%= if @trace_filter_open do %>
          <i class="fas fa-chevron-up"></i>
        <% else %>
          <i class="fas fa-chevron-down"></i>
        <% end %>
      </button>
      <div class={"#{if @trace_filter_open, do: "", else: "hidden"} divide-y divide-gray-200 border rounded"}>
        <span class="text-xs uppercase">
          <.filter_grid_row type_label="Type" value_label="Value" />
        </span>
        <%= for name <- @trace_steps.filter.names do %>
          <.filter_grid_row type_label="Name" value_label={name} remove_action="remove_trace_filter" />
        <% end %>
        <%= for pid <- @trace_steps.filter.pids do %>
          <.filter_grid_row type_label="PID" value_label={pid} remove_action="remove_trace_filter" />
        <% end %>
        <.filter_grid_input_row />
      </div>
    </div>
    """
  end

  attr :type_label, :any, required: true
  attr :value_label, :any, required: true
  attr :remove_action, :any, required: false, default: nil

  def filter_grid_row(assigns) do
    ~H"""
    <div
      class={"grid grid-cols-6 p-2 font-medium #{if @remove_action, do: "", else: "bg-slate-50"}"}
      style=""
    >
      <div><%= @type_label %></div>
      <div class="col-span-4"><%= @value_label %></div>
      <div>
        <button
          :if={@remove_action}
          type="button"
          class="text-red-600 hover:text-red-900"
          phx-click={@remove_action}
          phx-value-filter_type={@type_label}
          phx-value-filter_value={@value_label}
        >
          Remove
        </button>
      </div>
    </div>
    """
  end

  def filter_grid_input_row(assigns) do
    ~H"""
    <form phx-submit="add_trace_filter">
      <div class="grid grid-cols-6 p-2 font-medium">
        <div class="mr-2 justify-start">
          <select id="new-filter-type" name="filter_type" class="w-fit">
            <option value="Name">Name</option>
            <option value="PID">PID</option>
          </select>
        </div>
        <div class="col-span-4 items-center mx-4">
          <input
            id="new-filter-value"
            name="filter_value"
            placeholder="New filter value"
            class="p-2 w-full"
          />
        </div>
        <div>
          <button type="submit" class="text-green-600 hover:text-green-900 my-2">
            Add
          </button>
        </div>
      </div>
    </form>
    """
  end

  # Expects:
  #   :trace - a DataspaceTrace.t() struct
  #   :selected_actor - the pid currently chosen by the user, or false
  #   :current_step - the current trace step
  attr :trace, :any, required: true
  attr :selected_actor, :any, default: nil
  attr :current_step, :integer, required: true

  def actor_explorer(assigns) do
    ~H"""
    <div class="space-y-4 p-4">
      <div class="flex items-center space-x-2">
        <label for="actor_select" class="font-semibold">Actor:</label>
        <select
          id="actor_select"
          name="actor_select"
          class="border px-2 py-1"
          phx-hook="Formless"
          data-event="select_actor"
        >
          <option value="">-- Choose an actor --</option>
          <%= for {pid, name?} <- DataspaceTrace.all_unfiltered_actors(@trace) do %>
              <option value={pid} selected={@selected_actor == pid}>
                <%= actor_label(pid, name?) %>
              </option>
          <% end %>
        </select>
      </div>

      <div class="space-x-2">
        <.trace_button label="Earliest" action="actor_to_first" disabled={!@selected_actor} />
        <.trace_button label="Previous" action="actor_to_prev_distinct" disabled={!@selected_actor} />
        <.trace_button label="Next" action="actor_to_next_distinct" disabled={!@selected_actor} />
        <.trace_button label="Latest" action="actor_to_last" disabled={!@selected_actor} />
      </div>

      <%= if @selected_actor do %>
        <div class="border p-2">
          <%= if DataspaceTrace.actor_present?(@trace, @current_step, @selected_actor) do %>
            <FacetTreeComponent.tree actor={DataspaceTrace.actor_at(@trace, @current_step, @selected_actor)} />
          <% else %>
            <p class="text-gray-600">This actor is not active at step <%= @current_step %>.</p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp actor_label(pid, name?) do
    if name? && name? != "false" do
      "#{name?} #{pid}"
    else
      pid
    end
  end


  def actors_view(assigns) do
    ~H"""
    <div class="flex flex-col w-full h-auto gap-4">
      <h2 class="text-center text-2xl">Actors</h2>
      <%= for {pid, actor} <- DataspaceTrace.actors_at_step(@trace, @current_step) do %>
        <div class="flex flex-row items-center gap-4">
          <span class="font-bold">PID:</span> <code><pre><%= pid %></pre></code>
          <span class="font-bold">State:</span>
          <code><pre><%= inspect(actor, pretty: true) %></pre></code>
        </div>
      <% end %>
    </div>
    """
  end
end
