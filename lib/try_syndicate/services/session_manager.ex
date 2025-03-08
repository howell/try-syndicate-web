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
  @callback receive_outputs(session_id(), output_src(), [{non_neg_integer(), term()}]) :: :ok

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
  Returns
    - {:ok, :running | :finished} if successful, indicating the session as running or finished
    - {:error, reason} if unsuccessful
  """
  def session_status(session_id), do: impl().session_status(session_id)

  @doc """
  Notify the session manager that the session has terminated.
  Arguments:
    - session_id: the ID of the session
    - reason: the reason for the termination
  Returns :ok
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
  Receive multiple outputs from the session.
  Arguments:
    - session_id: the ID of the session
    - src: the source type of the outputs
    - outputs: a list of tuples containing the sequence number and data
  Returns :ok
  """
  def receive_outputs(session_id, src, outputs), do: impl().receive_outputs(session_id, src, outputs)

  defp impl, do: Application.get_env(:try_syndicate, :session_manager, TrySyndicate.ExternalSessionManager)
end
