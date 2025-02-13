defmodule TrySyndicateWeb.EditorLive do
  alias TrySyndicate.ExampleSupport
  use TrySyndicateWeb, :live_view

  alias TrySyndicate.SessionManager
  alias TrySyndicate.Syndicate.DataspaceTrace
  alias TrySyndicate.ExampleSupport
  alias TrySyndicateWeb.{CheatSheetComponent, DataspaceComponent}

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

        {:ok, init_assigns(socket, init_session_state(session_id))}
    end
  end

  @type session_state() :: %{
          session_id: String.t(),
          program_output: String.t(),
          program_error: String.t(),
          stale: boolean(),
          trace_steps: DataspaceTrace.t(),
          current_trace_step: integer() | false
        }

  @default_trace_filter %{
    names: ["repl-supervisor", "drivers/repl", "drivers/timer", "drivers/timestate"],
    pids: ["()", "(meta)"]
  }

  @spec init_session_state(String.t()) :: session_state()
  def init_session_state(session_id) do
    %{
      session_id: session_id,
      stale: false,
      program_output: "",
      program_error: "",
      trace_steps: DataspaceTrace.new(@default_trace_filter),
      current_trace_step: false
    }
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
      trace_steps: DataspaceTrace.new(@default_trace_filter),
      current_trace_step: false,
      current_trace_filter: @default_trace_filter
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

  def handle_event("example_selected", %{"value" => example_name}, socket) do
    case ExampleSupport.fetch_example(socket.assigns.current_flavor, example_name) do
      {:ok, content} ->
        Logger.debug("Loaded example: #{example_name}")

        socket =
          socket
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

  def handle_event("step_first", _params, socket) do
    {:noreply, assign(socket, current_trace_step: 0)}
  end

  def handle_event("step_prev", _params, socket) do
    {:noreply, assign(socket, current_trace_step: socket.assigns.current_trace_step - 1)}
  end

  def handle_event("step_next", _params, socket) do
    {:noreply, assign(socket, current_trace_step: socket.assigns.current_trace_step + 1)}
  end

  def handle_event("step_current", _params, socket) do
    {:noreply,
     assign(socket, current_trace_step: map_size(socket.assigns.trace_steps.filtered) - 1)}
  end

  def handle_info(%{event: "update", payload: %{type: update_type, data: update_data}}, socket) do
    next_sock =
      case update_type do
        "trace" -> add_step(socket, update_data)
        "stdout" -> add_output(socket, :program_output, update_data)
        "stderr" -> add_output(socket, :program_error, update_data)
      end

    {:noreply, next_sock}
  end

  def handle_info(%{event: "terminate", payload: %{reason: _reason}}, socket) do
    {:noreply, assign(socket, stale: true)}
  end

  def add_output(socket, key, data) do
    update(socket, key, fn existing -> existing <> Enum.join(data, "") end)
  end

  @spec add_step(map(), [any()]) :: map()
  def add_step(socket, data) do
    update(socket, :trace_steps, fn existing ->
      Enum.reduce(data, existing, fn step, existing -> DataspaceTrace.add_step(existing, step) end)
    end)
    |> update(:current_trace_step, fn curr -> curr || 0 end)
  end

  def code_mirror_line(assigns) do
    ~H"""
    <div class="flex flex-row justify-between mt-4 px-2">
      <div class="w-4 min-w-4 mr-2">
        <%= @label %>
      </div>
      <div class="flex flex-col gap-2 w-full">
        <div class="w-full">
          <%= live_component(%{
            module: TrySyndicateWeb.CodeMirrorComponent,
            id: @id,
            content: @content,
            active: @active
          }) %>
        </div>
        <div class="">
          <pre><%= @output %></pre>
        </div>
      </div>
    </div>
    """
  end

  def example_select(assigns) do
    ~H"""
    <div class="mb-4 flex flex-row items-center w-min-content gap-2">
      <label for="example-select" class="block font-medium text-gray-700">Examples:</label>
      <select
        phx-hook="Formless"
        data-event="example_selected"
        id="example-select"
        name="selection"
        class="mt-1 block w-auto pl-3 pr-10 py-2 text-base
            border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
      >
        <option value="" selected disabled>Try an Example</option>
        <%= for example <- Enum.sort(ExampleSupport.available_examples(@flavor)) do %>
          <option value={example}><%= example %></option>
        <% end %>
      </select>
    </div>
    """
  end

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
      <DataspaceComponent.dataspace dataspace={elem(@trace_steps.filtered[@current_trace_step], 0)} />
      <pre><%= inspect(elem(@trace_steps.filtered[@current_trace_step], 0), pretty: true) %></pre>
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
