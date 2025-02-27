defmodule TrySyndicateWeb.TraceViewComponent do
  use TrySyndicateWeb, :live_component

  alias TrySyndicate.Syndicate.DataspaceTrace
  alias TrySyndicateWeb.{DataspaceComponent, FacetTreeComponent}

  attr :title, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class={"#{@class}"}>
      <h2 class="text-center text-2xl mb-4"><%= @title %></h2>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  def trace_view(assigns) do
    ~H"""
    <div
      :if={@trace_steps.filtered[@current_trace_step]}
      class="mt-4 w-auto mx-auto flex flex-col gap-4 border border-gray-400 rounded-lg"
    >
      <.section title="Dataspace Trace" class="p-4 border-b border-gray-400">
        <.dataspace_navigation current_trace_step={@current_trace_step} trace_steps={@trace_steps} />
        <div class="w-dvw h-auto mx-auto overflow-x-auto">
          <DataspaceComponent.dataspace dataspace={
            elem(@trace_steps.filtered[@current_trace_step], 0)
          } />
        </div>
      </.section>

      <.section title="Actor Explorer" class="border-b border-gray-400">
        <div class="flex flex-col w-full h-auto mx-auto overflow-x-auto">
          <.actor_explorer
            trace={@trace_steps}
            current_step={@current_trace_step}
            selected_actor={@selected_actor}
          />
        </div>
      </.section>

      <.section title="Trace Filter" class="p-4">
        <div class="flex flex-row items-start w-full">
          <.trace_filter trace_steps={@trace_steps} trace_filter_open={@trace_filter_open} />
        </div>
      </.section>
    </div>
    """
  end

  attr :trace_steps, :any, required: true
  attr :current_trace_step, :integer, required: true

  def dataspace_navigation(assigns) do
    ~H"""
    <div class="flex flex-row items-center gap-4 justify-center mb-4">
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
    <div class="flex flex-row divide-x divide-gray-300 border-t border-gray-300 min-h-44">
      <div class="w-1/3">
        <.actor_list trace={@trace} selected_actor={@selected_actor} />
      </div>
      <div class="w-2/3 pl-4">
        <%= if @selected_actor do %>
          <div class="space-y-4 pt-4">
            <.actor_navigation
              trace={@trace}
              selected_actor={@selected_actor}
              current_step={@current_step}
              actor_idx={DataspaceTrace.actor_step_idx(@trace, @selected_actor, @current_step)}
              actor_count={DataspaceTrace.actor_step_count(@trace, @selected_actor)}
            />
            <div class="p-2 flex justify-center">
              <%= if DataspaceTrace.actor_present?(@trace, @current_step, @selected_actor) do %>
                <FacetTreeComponent.tree actor={
                  DataspaceTrace.actor_at(@trace, @current_step, @selected_actor)
                } />
              <% else %>
                <p class="text-gray-600">This actor is not active at step <%= @current_step %>.</p>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="flex items-center justify-center h-full text-gray-500">
            Select an actor from the list to view details
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def actor_list(assigns) do
    ~H"""
    <div class="overflow-y-auto max-h-[500px]">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <.table_header>Name</.table_header>
            <.table_header>PID</.table_header>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for {pid, name?} <- DataspaceTrace.all_unfiltered_actors(@trace) do %>
            <.actor_row pid={pid} name={name?} selected={@selected_actor == pid} />
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  slot :inner_block, required: true

  def table_header(assigns) do
    ~H"""
    <th
      scope="col"
      class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
    >
      <%= render_slot(@inner_block) %>
    </th>
    """
  end

  attr :pid, :string, required: true
  attr :name, :string, required: true
  attr :selected, :boolean, default: false

  def actor_row(assigns) do
    ~H"""
    <tr
      class={[
        "cursor-pointer hover:bg-gray-50",
        @selected && "bg-blue-50"
      ]}
      phx-click="select_actor"
      phx-value-actor={@pid}
    >
      <.table_cell>
        <%= if @name && @name != "false", do: @name, else: "-" %>
      </.table_cell>
      <.table_cell class="text-gray-500">
        <%= @pid %>
      </.table_cell>
    </tr>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def table_cell(assigns) do
    ~H"""
    <td class={["px-6 py-4 whitespace-nowrap text-sm", @class]}>
      <%= render_slot(@inner_block) %>
    </td>
    """
  end

  def actor_navigation(assigns) do
    ~H"""
    <div :if={@selected_actor} class="flex justify-center gap-4">
      <.trace_button label="Earliest" action="step_actor_first" disabled={@actor_idx == 0} />
      <.trace_button
        label="Previous"
        action="step_actor_prev"
        disabled={!@actor_idx || @actor_idx == 0}
      />
      <span class={"text-lg text-center #{if !@actor_idx, do: "invisible"}"}>
        <%= (@actor_idx || -1) + 1 %> / <%= @actor_count %>
      </span>
      <.trace_button
        label="Next"
        action="step_actor_next"
        disabled={!@actor_idx || @actor_idx == @actor_count - 1}
      />
      <.trace_button
        label="Latest"
        action="step_actor_last"
        disabled={@actor_idx == @actor_count - 1}
      />
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
end
