defmodule TrySyndicateWeb.SessionUpdateController do
  use TrySyndicateWeb, :controller

  alias TrySyndicate.SessionManager
  require Logger

  def receive_update(conn, params) do
    session_id = params["session_id"]
    update_type = Map.get(params, "type")
    update_data = Map.get(params, "data")

    Logger.info(
      "Received update for session #{session_id} with #{inspect(update_type)}: #{inspect(update_data)}"
    )

    TrySyndicateWeb.Endpoint.broadcast("session:#{session_id}", "update", %{
      type: update_type,
      data: update_data
    })

    send_resp(conn, 200, "")
  end

  def terminate_session(conn, params) do
    session_id = params["session_id"]
    reason = Map.get(params, "reason")
    Logger.info("Received termination notice for session #{session_id}")
    SessionManager.notify_termination(session_id, reason)
    TrySyndicateWeb.Endpoint.broadcast("session:#{session_id}", "terminate", %{})
    send_resp(conn, 200, "")
  end
end
