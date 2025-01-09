defmodule TrySyndicate.SessionManager do
  @callback start_session() :: {:ok, String.t()} | {:error, String.t()}
  @callback execute_code(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  @callback session_status(String.t()) :: {:ok, :running | :finished} | {:error, String.t()}
  @callback notify_termination(String.t(), String.t()) :: :ok

  def start_session(), do: impl().start_session()
  def execute_code(session_id, code), do: impl().execute_code(session_id, code)
  def session_status(session_id), do: impl().session_status(session_id)
  def notify_termination(session_id, reason), do: impl().notify_termination(session_id, reason)
  defp impl, do: Application.get_env(:try_syndicate, :session_manager, TrySyndicate.ExternalSessionManager)
end
