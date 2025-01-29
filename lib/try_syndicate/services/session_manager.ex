defmodule TrySyndicate.SessionManager do
  @type session_id() :: String.t()
  @type output_src() :: String.t()

  @callback start_session() :: {:ok, session_id()} | {:error, session_id()}
  @callback execute_code(session_id(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback session_status(session_id()) :: {:ok, :running | :finished} | {:error, String.t()}
  @callback notify_termination(session_id(), String.t()) :: :ok
  @callback keep_alive(session_id()) :: :ok
  @callback receive_output(session_id(), output_src(), non_neg_integer(), String.t()) :: :ok


  def start_session(), do: impl().start_session()
  def execute_code(session_id, code), do: impl().execute_code(session_id, code)
  def session_status(session_id), do: impl().session_status(session_id)
  def notify_termination(session_id, reason), do: impl().notify_termination(session_id, reason)
  def keep_alive(session_id), do: impl().keep_alive(session_id)
  def receive_output(session_id, src, seq_no, data), do: impl().receive_output(session_id, src, seq_no, data)
  defp impl, do: Application.get_env(:try_syndicate, :session_manager, TrySyndicate.ExternalSessionManager)
end
