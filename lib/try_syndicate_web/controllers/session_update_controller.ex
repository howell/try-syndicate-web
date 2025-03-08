defmodule TrySyndicateWeb.SessionUpdateController do
  use TrySyndicateWeb, :controller

  alias TrySyndicate.Syndicate.{Json, TraceNotification}
  alias TrySyndicate.SessionManager
  require Logger

  def receive_update(conn, params) do
    case params do
      %{"session_id" => session_id, "outputs" => outputs} ->
        Logger.info(
          "Received update for session #{session_id}"
        )

        case decode_output(outputs) do
          {:ok, decoded} ->
            send_outputs(session_id, decoded)
            send_resp(conn, 200, "")

          {:error, reason} ->
            Logger.warning("Failed to decode outputs: #{inspect(reason)}")
            send_resp(conn, 400, reason)
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

  def send_outputs(session_id, outputs) do
    for output <- outputs do
      Logger.debug("Session #{session_id} received #{length(output.entries)} update for #{output.type}")
      SessionManager.receive_outputs(session_id, output.type, output.entries)
    end
  end

  @type output_data() :: %{type: String.t(), entries: [{integer(), term()}]}

  @spec decode_output(term()) :: {:ok, [output_data()]} | {:error, String.t()}
  def decode_output(data) do
    with {:ok, outputs} <- Json.parse_list(data, &decode_output_item/1) do
      {:ok, outputs}
    else
      {:error, reason} ->
        {:error, "Failed to decode outputs: #{reason}"}
    end
  end

  @spec decode_output_item(term()) :: {:ok, output_data()} | {:error, String.t()}
  def decode_output_item(data) do
    with {:ok, type} <- Json.parse_field(data, "type"),
         {:ok, entries} <- Json.parse_field(data, "entries", fn list_json ->
            Json.parse_list(list_json, fn json ->
           with {:ok, seq_no} <- Json.parse_field(json, "seq_no"),
                {:ok, data} <- Json.parse_field(json, "data", &decode_data_for(type, &1)) do
             {:ok, {seq_no, data}}
           else
             {:error, reason} ->
               {:error, "Failed to decode output item: #{reason}"}
             end
           end)
         end) do
      {:ok, %{type: type, entries: entries}}
    else
      {:error, reason} ->
        {:error, "Failed to decode output data: #{reason}"}
    end
  end

  def decode_data_for("trace", data) do
    TraceNotification.from_json(data)
  end

  def decode_data_for(_, data) do
    if is_binary(data) do
      {:ok, data}
    else
      {:error, "Received non-binary data"}
    end
  end
end
