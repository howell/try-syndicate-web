defmodule TrySyndicateWeb.EditorLive do
  use TrySyndicateWeb, :live_view

  alias TrySyndicate.SessionManager
  import TrySyndicateWeb.Components.Helpers

  def mount(_params, _session, socket) do
    if connected?(socket) do
      session_id = SessionManager.start_session()
      TrySyndicateWeb.Endpoint.subscribe("session:#{session_id}")
      {:ok, assign(socket, session_id: session_id, submissions: [], program_output: "", program_error: "")}
    else
      {:ok, assign(socket, submissions: [], program_output: "", program_error: "")}
    end
  end

  def handle_event("run_code", %{"code" => code}, socket) do
    case SessionManager.execute_code(socket.assigns.session_id, code) do
      {:ok, result} ->
        submissions = socket.assigns.submissions ++ [%{code: code, output: result}]
        {:noreply, assign(socket, output: "", submissions: submissions)}
      {:error, reason} -> {:noreply, assign(socket, :output, reason)}
    end
  end

  def handle_info(%{event: "update", payload: %{type: update_type, data: update_data}}, socket) do
    key = case update_type do
      "stdout" -> :program_output
      "stderr" -> :program_error
    end
    {:noreply, update(socket, key, fn existing -> existing <> update_data end)}
  end

end
