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
    ~H"""
    <div class="my-4">
      <button phx-click="toggle_cheatsheet">
        <h2 class="text-xl font-bold">Cheat Sheet</h2>
      </button>
      <%= if @open do %>
        <div class="flex flex-row gap-20 justify-center mt-2">
          <div>
            <h3 class="text-lg font-bold">Syndicate Basics</h3>
            <ul class="list-disc list-inside space-y-2">
              <li><code>(spawn <i>expr</i> ...)</code> - Spawn an actor</li>
              <li><code>(react <i>expr</i> ...)</code> - Start a new facet for an actor</li>
              <p>
                Inside of <code>spawn</code>
                and <code>react</code>, use the following forms to define behavior:
              </p>
              <li><code>(assert <i>expr</i>)</code> - Assert a value to the dataspace</li>
              <li><code>(send! <i>expr</i>)</code> - Broadcast a message to the dataspace</li>
              <li>
                <code>(field [<i>field-name</i> <i>init-expr</i>] ...)</code>
                - Define a mutable field, or fields, with an initial value
                <ul class="list-disc list-inside ml-4 space-y-1">
                  <li><code>(<i>field-name</i>)</code> - Read the current value of a field</li>
                  <li>
                    <code>(<i>field-name</i> <i>expr</i>)</code> - Assign a new value to a field
                  </li>
                </ul>
              </li>
              <li>
                <code>(on <i>event</i> <i>expr</i> ...)</code>
                - Install an event handler. An <code><i>event</i></code>
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
                  Within a <i>pattern</i>, a <code>$</code> prefix creates a binding variable
                </ul>
              </li>
              <li>
                <code>(on-start <i>expr</i> ...)</code>
                - Adds a handler that runs when the facet starts
              </li>
              <li>
                <code>(on-stop <i>expr</i> ...)</code>
                - Adds a handler that runs when the facet terminates
              </li>
              <li>
                <code>(stop <i>facet-id</i>))</code>
                - Terminate the designated facet and its children
                <ul class="list-disc list-inside ml-4">
                  <li><code>(current-facet-id)</code> - Returns the ID of the current facet</li>
                </ul>
              </li>
              <li><code>(stop-current-facet)</code> - Terminate the current facet</li>
            </ul>
          </div>
          <div>
            <h3 class="text-lg font-bold">REPL Commands</h3>
            <ul class="list-disc list-inside">
              <li><code>(spawn <i>expr</i> ...)</code></li>
              <li><code>(assert <i>expr</i>)</code></li>
              <li><code>(retract <i>expr</i>)</code></li>
              <li><code>(send <i>expr</i>)</code></li>
              <li><code>(query/set <i>pattern</i> <i>expr</i>)</code></li>
            </ul>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
