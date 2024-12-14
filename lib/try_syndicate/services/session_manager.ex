defmodule TrySyndicate.SessionManager do
  @callback start_session() :: {:ok, String.t()} | {:error, String.t()}
  @callback execute_code(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}

  def start_session(), do: impl().start_session()
  def execute_code(session_id, code), do: impl().execute_code(session_id, code)
  defp impl, do: Application.get_env(:try_syndicate, :session_manager, TrySyndicate.ExternalSessionManager)
end
