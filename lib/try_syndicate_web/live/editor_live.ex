defmodule TrySyndicateWeb.EditorLive do
  alias TrySyndicate.ExampleSupport
  use TrySyndicateWeb, :live_view

  alias TrySyndicate.SessionManager
  alias TrySyndicate.ExampleSupport
  alias TrySyndicateWeb.CheatSheetComponent

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
      {:ok, init_assigns(socket)}
    end
  end

  def begin_session(socket) do
    case SessionManager.start_session() do
      {:error, reason} ->
        next_sock =
          put_flash(socket, :error, "Failed to start session: #{inspect(reason)}")
          |> init_assigns()

        Logger.debug("Failed to start session: #{inspect(reason)}")

        {:ok, next_sock}

      {:ok, session_id} ->
        if Map.get(socket.assigns, :session_id) do
          TrySyndicateWeb.Endpoint.unsubscribe("session:#{socket.assigns.session_id}")
        end

        TrySyndicateWeb.Endpoint.subscribe("session:#{session_id}")

        {:ok, init_assigns(socket, session_id: session_id)}
    end
  end

  def init_assigns(socket, assigns \\ []) do
    defaults = [
      session_id: nil,
      submissions: [],
      program_output: "",
      program_error: "",
      stale: false,
      cheatsheet_open: false,
      current_flavor: :classic,
      editor_prefill: "",
    ]

    attrs =
      for {key, default_value} <- defaults, into: %{} do
        val = assigns[key] || socket.assigns[key] || default_value
        {key, val}
      end

    assign(socket, attrs)
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
    {:ok, socket} = begin_session(socket)
    {:noreply, socket}
  end

  def handle_event("toggle_cheatsheet", _params, socket) do
    {:noreply, update(socket, :cheatsheet_open, &(!&1))}
  end

  def handle_event("example_selected", %{"selection" => example_name}, socket) do
    case ExampleSupport.fetch_example(socket.assigns.current_flavor, example_name) do
      {:ok, content} ->
        Logger.debug("Loaded example: #{example_name}")
        socket = socket
        |> assign(editor_prefill: content)
        |> push_event("example_selected", %{content: content})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load example: #{reason}")}
    end
  end

  def handle_event("keep_alive", _params, socket) do
    if Map.get(socket.assigns, :session_id) && not Map.get(socket.assigns, :stale) do
      SessionManager.keep_alive(socket.assigns.session_id)
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "update", payload: %{type: update_type, data: update_data}}, socket) do
    key =
      case update_type do
        "stdout" -> :program_output
        "stderr" -> :program_error
      end

    {:noreply, update(socket, key, fn existing -> existing <> update_data end)}
  end

  def handle_info(%{event: "terminate", payload: %{reason: _reason}}, socket) do
    {:noreply, assign(socket, stale: true)}
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

  def example_select(assigns) do
    ~H"""
    <div class="mb-4">
      <form phx-change="example_selected">
        <label for="example-select" class="block text-sm font-medium text-gray-700">Examples:</label>
        <select
          id="example-select"
          name="selection"
          class="mt-1 block w-auto pl-3 pr-10 py-2 text-base
            border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" >
          <option value="" selected disabled>Try an Example</option>
          <%= for example <- ExampleSupport.available_examples(@flavor) do %>
            <option value={example}><%= example %></option>
          <% end %>
        </select>
      </form>
    </div>
    """
  end
end
