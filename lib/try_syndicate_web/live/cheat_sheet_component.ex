defmodule TrySyndicateWeb.CheatSheetComponent do
  use TrySyndicateWeb, :live_component

  def render(assigns) do
    assigns = assign(assigns, tables: [
      {"REPL Commands", repl_commands_rows()},
      {"Syndicate Basics", syndicate_basics_rows()}
    ])

    ~H"""
    <div class="my-4">
      <button phx-click="toggle_cheatsheet" class="flex items-center gap-2">
        <h2 class="text-xl font-bold">Cheat Sheet</h2>
        <%= if @open do %>
          <i class="fas fa-chevron-up"></i>
        <% else %>
          <i class="fas fa-chevron-down"></i>
        <% end %>
      </button>
      <div :if={@open} class="flex flex-row gap-20 justify-center mt-2 p-2 bg-slate-50 border border-black rounded-lg">
        <%= for {title, rows} <- @tables do %>
          <%= render_table(assign(assigns, title: title, rows: rows)) %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_table(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-bold"><%= @title %></h3>
      <table class="table-auto">
        <thead>
          <tr>
            <th class="px-4 py-2">Command</th>
            <th class="px-4 py-2">Description</th>
          </tr>
        </thead>
        <tbody>
          <%= for {command, description} <- @rows do %>
            <tr>
              <%= table_cell(command) %>
              <%= table_cell(description) %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp table_cell(content) do
    assigns = []

    ~H"""
    <td class="border px-4 py-2"><%= content %></td>
    """
  end

  defp syndicate_basics_rows do
    assigns = []
    [
      {~H"(spawn <i>expr</i> ...)", "Spawn an actor"},
      {~H"(react <i>expr</i> ...)", "Start a new facet for an actor"},
      {~H"(assert <i>expr</i>)", "Assert a value to the dataspace"},
      {~H"(send! <i>expr</i>)", "Broadcast a message to the dataspace"},
      {~H"(field [<i>field-name</i> <i>init-expr</i>] ...)",
       ~H"""
       Define a mutable field, or fields, with an initial value
       <ul class="list-disc list-inside ml-4 space-y-1">
         <li><code>(<i>field-name</i>)</code> - Read the current value of a field</li>
         <li><code>(<i>field-name</i> <i>expr</i>)</code> - Assign a new value to a field</li>
       </ul>
       """},
      {~H"(on <i>event</i> <i>expr</i> ...)",
       ~H"""
       Install an event handler. An <code><i>event</i></code>
       may be one of the following:
       <ul class="list-disc list-inside ml-4">
         <li>
           <code>(asserted <i>pattern</i>)</code>
           - Matches detection of an assertion matching the <i>pattern</i>
         </li>
         <li>
           <code>(retracted <i>pattern</i>)</code>
           - Matches detection of the removal of an assertion matching the <i>pattern</i>
         </li>
         <li>
           <code>(message <i>pattern</i>)</code>
           - Matches a message broadcast matching the <i>pattern</i>
         </li>
         Within a <i>pattern</i>, a <code>$</code>
         prefix creates a binding variable
       </ul>
       """},
      {~H"(on-start <i>expr</i> ...)", "Adds a handler that runs when the facet starts"},
      {~H"(on-stop <i>expr</i> ...)", "Adds a handler that runs when the facet terminates"},
      {~H"(stop <i>facet-id</i>))",
       ~H"""
       Terminate the designated facet and its children
       <ul class="list-disc list-inside ml-4">
         <li><code>(current-facet-id)</code> - Returns the ID of the current facet</li>
       </ul>
       """},
      {~H"(stop-current-facet)", "Terminate the current facet"}
    ]
  end

  defp repl_commands_rows do
    assigns = []
    [
      {~H"(spawn <i>expr</i> ...)", "Spawn an actor"},
      {~H"(assert <i>expr</i>)", "Inject assertion"},
      {~H"(retract <i>expr</i>)", "Withdraw injected assertion"},
      {~H"(send <i>expr</i>)", "Broadcast message"},
      {~H"(query/set <i>pattern</i> <i>expr</i>)", "Build a set based on matching assertions"}
    ]
  end
end
