defmodule TrySyndicateWeb.ActorExplorer do
  use TrySyndicateWeb, :html

  alias TrySyndicate.Syndicate.DataspaceTrace
  alias TrySyndicateWeb.FacetTreeComponent

  # Expects:
  #   :trace - a DataspaceTrace.t() struct
  #   :selected_actor - the pid currently chosen by the user, or false
  #   :current_step - the current trace step
  attr :trace, :any, required: true
  attr :selected_actor, :any, default: nil
  attr :current_step, :integer, required: true

  def component(assigns) do
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
        <button phx-click="actor_to_first" phx-value-pid={@selected_actor} class="border px-2 py-1">
          Earliest
        </button>
        <button phx-click="actor_to_prev_distinct" phx-value-pid={@selected_actor} class="border px-2 py-1">
          Prev Distinct
        </button>
        <button phx-click="actor_to_next_distinct" phx-value-pid={@selected_actor} class="border px-2 py-1">
          Next Distinct
        </button>
        <button phx-click="actor_to_last" phx-value-pid={@selected_actor} class="border px-2 py-1">
          Latest
        </button>
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

end
