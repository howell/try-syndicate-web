defmodule TrySyndicateWeb.SessionUpdateController do
  use TrySyndicateWeb, :controller

  alias TrySyndicate.SessionManager
  require Logger

  def receive_update(conn, params) do
    case params do
      %{"session_id" => session_id, "type" => update_type, "seq_no" => seq_no, "data" => data} ->
        Logger.info(
          "Received update for session #{session_id} on #{inspect(update_type)}(#{seq_no}): #{inspect(data)}"
        )

        SessionManager.receive_output(session_id, update_type, seq_no, data)
        send_resp(conn, 200, "")

      _ ->
        Logger.warning("Received unknown update message: #{inspect(params)}")
        send_resp(conn, 400, "")
    end
  end

  def terminate_session(conn, params) do
    session_id = params["session_id"]
    reason = Map.get(params, "reason")
    Logger.info("Received termination notice for session #{session_id}")
    SessionManager.notify_termination(session_id, reason)
    TrySyndicateWeb.Endpoint.broadcast("session:#{session_id}", "terminate", %{reason: reason})
    send_resp(conn, 200, "")
  end
end
