defmodule TrySyndicateWeb.EditorLive do
  use TrySyndicateWeb, :live_view

  alias TrySyndicate.SessionManager

  def mount(_params, _session, socket) do
    if connected?(socket) do
      case SessionManager.start_session() do
        {:error, reason} ->
          next_sock =
            put_flash(socket, :error, "Failed to start session: #{inspect(reason)}")
            |> assign(session_id: nil, submissions: [], program_output: "", program_error: "")

          {:ok, next_sock}

        {:ok, session_id} ->
          TrySyndicateWeb.Endpoint.subscribe("session:#{session_id}")

          {:ok,
           assign(socket,
             session_id: session_id,
             submissions: [],
             program_output: "",
             program_error: ""
           )}
      end
    else
      {:ok, assign(socket, session_id: nil, submissions: [], program_output: "", program_error: "")}
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
           <%= live_component %{module: TrySyndicateWeb.CodeMirrorComponent, id: @id, content: @content, active: @active }%>
         </div>
         <div class="w-1/4 ml-2">
           <pre><%= @output %></pre>
         </div>
      </div>
    """
  end
end
