defmodule TrySyndicate.SessionManager do
  @moduledoc """
  A module that defines the interface for the session manager.

  A session manager provides an interface to the external execution environment.
  It is responsible for managing the lifecycle of sessions and sending data back and forth.
  """

  @type session_id() :: String.t()
  @type name() :: String.t()
  @type output_src() :: String.t()

  @callback start_session() :: {:ok, session_id()} | {:error, session_id()}
  @callback execute_code(session_id(), String.t(), name()) :: {:ok, String.t()} | {:error, String.t()}
  @callback session_status(session_id()) :: {:ok, :running | :finished} | {:error, String.t()}
  @callback notify_termination(session_id(), String.t()) :: :ok
  @callback keep_alive(session_id()) :: :ok
  @callback receive_output(session_id(), output_src(), non_neg_integer(), String.t()) :: :ok

  @doc """
  Request to start a new session.
  Returns
    - {:ok, session_id()} if successful
    - {:error, reason} if unsuccessful
  """
  def start_session(), do: impl().start_session()

  @doc """
  Execute code in the session.
  Arguments:
    - session_id: the ID of the session
    - code: the code to execute
    - name: a name to associate with this code which will appear in source locations
  Returns
    - {:ok, result} if successful
    - {:error, reason} if unsuccessful
  """
  def execute_code(session_id, code, name), do: impl().execute_code(session_id, code, name)

  @doc """
  Get the status of the session.
  Arguments:
    - session_id: the ID of the session
    - reason: the reason for the termination
  Returns
    - {:ok, :running | :finished} if successful, indicating the session as running or had already finished
    - {:error, reason} if unsuccessful
  """
  def notify_termination(session_id, reason), do: impl().notify_termination(session_id, reason)

  @doc """
  Request to keep the session alive.
  Arguments:
    - session_id: the ID of the session
  Returns :ok
  """
  def keep_alive(session_id), do: impl().keep_alive(session_id)

  @doc """
  Receive output from the session.
  Arguments:
    - session_id: the ID of the session
    - src: the source type of the output
    - seq_no: the sequence number of the output
    - data: the data to receive
  Returns :ok
  """
  def receive_output(session_id, src, seq_no, data), do: impl().receive_output(session_id, src, seq_no, data)
  defp impl, do: Application.get_env(:try_syndicate, :session_manager, TrySyndicate.ExternalSessionManager)
end
