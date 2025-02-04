defmodule TrySyndicateWeb.SessionUpdateController do
  use TrySyndicateWeb, :controller

  alias TrySyndicate.SessionManager
  alias TrySyndicate.Syndicate.Dataspace
  require Logger

  def receive_update(conn, params) do
    case params do
      %{"session_id" => session_id, "type" => update_type, "seq_no" => seq_no, "data" => data} ->
        Logger.info(
          "Received update for session #{session_id} on #{inspect(update_type)}(#{seq_no})"
        )

        case decode_data_for(update_type, data) do
          {:ok, decoded} ->
            SessionManager.receive_output(session_id, update_type, seq_no, decoded)
            send_resp(conn, 200, "")

          {:error, reason} ->
            Logger.warning("Failed to decode data for #{update_type}: #{inspect(reason)}")
            send_resp(conn, 400, "")
        end

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

  def decode_data_for("trace", data) do
    Dataspace.from_json(data)
  end

  def decode_data_for(_, data) do
    if is_binary(data) do
      {:ok, data}
    else
      {:error, "Received non-binary data"}
    end
  end
end
