defmodule TrySyndicateWeb.EditorLive do
  use TrySyndicateWeb, :live_view

  alias TrySyndicate.SessionManager

  def mount(_params, _session, socket) do
    if connected?(socket) do
      session_id = SessionManager.start_session()
      {:ok, assign(socket, session_id: session_id, output: "")}
    else
      {:ok, assign(socket, output: "")}
    end
  end

  def handle_event("run_code", %{"code" => code}, socket) do
    case SessionManager.execute_code(socket.assigns.session_id, code) do
      {:ok, result} -> {:noreply, assign(socket, :output, result)}
      {:error, reason} -> {:noreply, assign(socket, :output, reason)}
    end
  end

end
