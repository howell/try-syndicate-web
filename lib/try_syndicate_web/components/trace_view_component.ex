defmodule TrySyndicateWeb.TraceViewComponent do
  use TrySyndicateWeb, :live_component

  alias TrySyndicate.Syndicate.DataspaceTrace
  alias TrySyndicateWeb.{DataspaceComponent, FacetTreeComponent}

  attr :trace_steps, :any, required: true
  attr :current_trace_step, :integer, required: true
  attr :selected_actor, :any, required: true
  attr :show_filtered, :boolean, required: true
  attr :submissions, :list, required: true

  def trace_view(assigns) do
    ~H"""
    <div
      :if={@trace_steps.filtered[@current_trace_step]}
      class="mt-4 w-auto mx-auto flex flex-col gap-4 border-2 border-gray-400 rounded-lg"
    >
      <.section title="Dataspace Trace" class="p-4 border-b-2 border-gray-400">
        <.dataspace_navigation current_trace_step={@current_trace_step} trace_steps={@trace_steps} />
        <div class="w-dvw h-auto mx-auto overflow-x-auto">
          <DataspaceComponent.dataspace dataspace={
            elem(@trace_steps.filtered[@current_trace_step], 0)
          } />
        </div>
      </.section>

      <.section title="Actor Explorer" class="border-b-2 border-gray-400">
        <div class="flex flex-col w-full h-auto mx-auto overflow-x-auto">
          <.actor_explorer
            trace={@trace_steps}
            current_step={@current_trace_step}
            selected_actor={@selected_actor}
            show_filtered={@show_filtered}
            submissions={@submissions}
          />
        </div>
      </.section>
    </div>
    """
  end

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
  attr :show_filtered, :boolean, required: true
  attr :submissions, :list, required: true
  def actor_explorer(assigns) do
    ~H"""
    <div class="flex flex-row divide-x divide-gray-300 border-t border-gray-300 min-h-44">
      <div class="w-1/3">
        <.actor_list trace={@trace} selected_actor={@selected_actor} show_filtered={@show_filtered} />
      </div>
      <div class="w-2/3 pl-4 overflow-hidden">
        <%= if @selected_actor do %>
          <div class="space-y-4 pt-4">
            <.actor_navigation
              trace={@trace}
              selected_actor={@selected_actor}
              current_step={@current_step}
              present={DataspaceTrace.actor_present?(@trace, @current_step, @selected_actor)}
              actor_idx={DataspaceTrace.actor_step_idx(@trace, @selected_actor, @current_step)}
              actor_count={DataspaceTrace.actor_step_count(@trace, @selected_actor)}
            />
            <div class="p-2 overflow-auto max-h-[600px]">
              <%= if DataspaceTrace.actor_present?(@trace, @current_step, @selected_actor) do %>
                <div class="overflow-auto min-w-full">
                  <FacetTreeComponent.tree actor={
                    DataspaceTrace.actor_at(@trace, @current_step, @selected_actor)
                  } submissions={@submissions} />
                </div>
              <% else %>
                <p class="text-gray-600">
                  This actor is not active at step <%= @current_step + 1 %>.
                </p>
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

  attr :show_filtered, :boolean, required: true
  attr :selected_actor, :any, required: true
  attr :trace, :any, required: true

  def actor_list(assigns) do
    ~H"""
    <div class="overflow-y-auto max-h-[500px]">
      <div class="p-2 flex items-center">
        <label class="flex items-center gap-2 text-sm text-gray-600">
          <input type="checkbox" phx-click="toggle_show_filtered" checked={@show_filtered} />
          Show filtered actors
        </label>
      </div>
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <.table_header class="text-left">Name</.table_header>
            <.table_header class="text-center">PID</.table_header>
            <.table_header class="text-center">Filter</.table_header>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for {pid, name?} <- Enum.sort_by(DataspaceTrace.all_actors(@trace), fn {id, _} -> {String.length(id), id} end) do %>
            <.actor_row
              :if={@show_filtered || !DataspaceTrace.filtered?(@trace, pid: pid, name: name?)}
              pid={pid}
              name={name?}
              selected={@selected_actor == pid}
              filtered={DataspaceTrace.filtered?(@trace, pid: pid, name: name?)}
            />
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def table_header(assigns) do
    ~H"""
    <th
      scope="col"
      class={"px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider #{@class}"}
    >
      <%= render_slot(@inner_block) %>
    </th>
    """
  end

  attr :pid, :string, required: true
  attr :name, :string, required: true
  attr :selected, :boolean, default: false
  attr :filtered, :boolean, default: false

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
      <.table_cell class="text-left">
        <%= if @name && @name != "false", do: @name, else: "-" %>
      </.table_cell>
      <.table_cell class="text-center text-gray-500">
        <%= @pid %>
      </.table_cell>
      <.table_cell class="text-center">
        <button
          type="button"
          class="text-gray-500 hover:text-gray-700"
          phx-click={if @filtered, do: "remove_trace_filter", else: "add_trace_filter"}
          phx-value-filter_type={if @name && @name != "false", do: "Name", else: "PID"}
          phx-value-filter_value={if @name && @name != "false", do: @name, else: @pid}
        >
          <i class={"fas #{if @filtered, do: "fa-eye-slash text-red-500", else: "fa-eye"}"}></i>
        </button>
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
      <.trace_button
        label="Earliest"
        action="step_actor_first"
        disabled={@present && @actor_idx == 0}
      />
      <.trace_button
        label="Previous"
        action="step_actor_prev"
        disabled={!@present || !@actor_idx || @actor_idx == 0}
      />
      <span class={"text-lg text-center #{if !@present || !@actor_idx, do: "invisible"}"}>
        <%= (@actor_idx || -1) + 1 %> / <%= @actor_count %>
      </span>
      <.trace_button
        label="Next"
        action="step_actor_next"
        disabled={!@present || !@actor_idx || @actor_idx == @actor_count - 1}
      />
      <.trace_button
        label="Latest"
        action="step_actor_last"
        disabled={@present && @actor_idx == @actor_count - 1}
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
end
