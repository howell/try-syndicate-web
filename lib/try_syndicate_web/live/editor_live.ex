defmodule TrySyndicateWeb.EditorLive do
  use TrySyndicateWeb, :live_view

  alias TrySyndicate.SessionManager

  require Logger

  def mount(_params, _session, socket) do
    if connected?(socket) do
      if Map.get(socket.assigns, :session_id) do
        Logger.info("Rejoining session: #{socket.assigns.session_id}")
        rejoin_session(socket, socket.assigns.session_id)
      else
        begin_session(socket)
      end
    else
      {:ok,
       assign(socket,
         session_id: nil,
         submissions: [],
         program_output: "",
         program_error: "",
         stale: false,
         cheatsheet_open: false
       )}
    end
  end

  def begin_session(socket) do
    case SessionManager.start_session() do
      {:error, reason} ->
        next_sock =
          put_flash(socket, :error, "Failed to start session: #{inspect(reason)}")
          |> assign(session_id: nil, submissions: [], program_output: "", program_error: "")

        {:ok, next_sock}

      {:ok, session_id} ->
        if Map.get(socket.assigns, :session_id) do
          TrySyndicateWeb.Endpoint.unsubscribe("session:#{socket.assigns.session_id}")
        end

        TrySyndicateWeb.Endpoint.subscribe("session:#{session_id}")

        {:ok,
         assign(socket,
           session_id: session_id,
           submissions: [],
           program_output: "",
           program_error: "",
           stale: false,
           cheatsheet_open: false
         )}
    end
  end

  def rejoin_session(socket, session_id) do
    case SessionManager.session_status(session_id) do
      {:ok, :running} ->
        {:ok, socket}

      {:ok, :finished} ->
        {:ok, assign(socket, stale: true)}

      {:error, reason} ->
        {:ok, put_flash(socket, :error, "Error connecting to session: #{reason}")}
    end
  end

  def handle_event("run_code", %{"code" => code}, socket) do
    case Map.get(socket.assigns, :session_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Session not started")}

      session_id ->
        case SessionManager.execute_code(session_id, code) do
          {:ok, result} ->
            submissions = socket.assigns.submissions ++ [%{code: code, output: result}]
            {:noreply, assign(socket, output: "", submissions: submissions)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Error running code: #{reason}")}
        end
    end
  end

  def handle_event("start_new_session", _params, socket) do
    begin_session(socket)
  end

  def handle_event("toggle_cheatsheet", _params, socket) do
    {:noreply, update(socket, :cheatsheet_open, &(!&1))}
  end

  def handle_info(%{event: "update", payload: %{type: update_type, data: update_data}}, socket) do
    key =
      case update_type do
        "stdout" -> :program_output
        "stderr" -> :program_error
      end

    {:noreply, update(socket, key, fn existing -> existing <> update_data end)}
  end

  def code_mirror_line(assigns) do
    ~H"""
    <div class="flex flex-row justify-between mt-4 px-2">
      <div class="w-4 min-w-4 mr-2">
        <%= @label %>
      </div>
      <div class="w-3/4">
        <%= live_component(%{
          module: TrySyndicateWeb.CodeMirrorComponent,
          id: @id,
          content: @content,
          active: @active
        }) %>
      </div>
      <div class="w-1/4 ml-2">
        <pre><%= @output %></pre>
      </div>
    </div>
    """
  end

  def cheatsheet(assigns) do
    assigns = assign(assigns, tables: [
      {"REPL Commands", repl_commands_rows()},
      {"Syndicate Basics", syndicate_basics_rows()}
    ])
    ~H"""
    <div class="my-4">
      <button phx-click="toggle_cheatsheet">
        <h2 class="text-xl font-bold">Cheat Sheet</h2>
      </button>
        <div :if={@open} class="flex flex-row gap-20 justify-center mt-2">
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
      {~H"(spawn <i>expr</i> ...)", ""},
      {~H"(assert <i>expr</i>)", ""},
      {~H"(retract <i>expr</i>)", ""},
      {~H"(send <i>expr</i>)", ""},
      {~H"(query/set <i>pattern</i> <i>expr</i>)", ""}
    ]
  end

end
