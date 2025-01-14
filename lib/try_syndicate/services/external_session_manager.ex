defmodule TrySyndicate.ExternalSessionManager do
  use GenServer
  @behaviour TrySyndicate.SessionManager

  require Logger

  def init(state) do
    {:ok, state}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def sandbox_url do
    Application.fetch_env!(:try_syndicate, :sandbox_url)
  end

  @spec start_session() :: {:ok, String.t()} | {:error, String.t()}
  def start_session() do
    session_id = UUID.uuid4()

    case GenServer.call(__MODULE__, {:start_session, session_id}) do
      :ok -> {:ok, session_id}
      {:error, reason} -> {:error, reason}
    end
  end

  def notify_termination(session_id, reason) do
    GenServer.cast(__MODULE__, {:terminate_session, session_id, reason})
  end

  def keep_alive(session_id) do
    GenServer.cast(__MODULE__, {:keep_alive, session_id})
  end

  def execute_code(session_id, code) do
    GenServer.call(__MODULE__, {:execute_code, session_id, code})
  end

  def session_status(session_id) do
    GenServer.call(__MODULE__, {:session_status, session_id})
  end

  def handle_call({:start_session, session_id}, _from, state) do
    Logger.info("Starting session: #{session_id}")

    case start_repl_session(session_id) do
      :ok -> {:reply, :ok, Map.put(state, session_id, :active)}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:execute_code, session_id, code}, _from, state) do
    if Map.get(state, session_id) == :active do
      case send_code(session_id, code) do
        {:ok, output} -> {:reply, {:ok, output}, state}
        {:error, reason} -> {:reply, {:error, reason}, Map.delete(state, session_id)}
      end
    else
      {:reply, {:error, "Session expired"}, state}
    end
  end

  def handle_call({:session_status, session_id}, _from, state) do
    if Map.get(state, session_id) == :active do
      query_session_status(session_id, state)
    else
      {:reply, {:ok, :inactive}, state}
    end
  end

  @spec query_session_status(any(), any()) ::
          {:reply,
           {:error, %{:__exception__ => true, :__struct__ => atom(), optional(atom()) => any()}}
           | {:ok, :active | :inactive}, any()}
  @spec query_session_status(any(), any()) ::
          {:reply,
           {:error, %{:__exception__ => true, :__struct__ => atom(), optional(atom()) => any()}}
           | {:ok, :active | :inactive}, any()}
  def query_session_status(session_id, state) do
    url = "#{sandbox_url()}/status/#{session_id}"

    case Finch.build(:get, url) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{status: 200}} ->
        {:reply, {:ok, :active}, state}

      {:ok, %Finch.Response{status: 404}} ->
        {:reply, {:ok, :inactive}, Map.delete(state, session_id)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_cast({:terminate_session, session_id, _reason}, state) do
    {:noreply, Map.delete(state, session_id)}
  end

  def handle_cast({:keep_alive, session_id}, state) do
    if Map.get(state, session_id) == :active do
      if send_keep_alive(session_id) == :ok do
        {:noreply, state}
      else
        {:noreply, Map.delete(state, session_id)}
      end
    else
      {:noreply, state}
    end
  end

  defp send_keep_alive(session_id) do
    url = "#{sandbox_url()}/keep_alive"
    body = Jason.encode!(%{session_id: session_id})
    headers = [{"Content-Type", "application/json"}]

    case Finch.build(:post, url, headers, body) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{status: 200}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_repl_session(session_id) do
    url = "#{sandbox_url()}/new"
    body = Jason.encode!(%{session_id: session_id})
    headers = [{"Content-Type", "application/json"}]

    case Finch.build(:post, url, headers, body) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{status: 200}} ->
        :ok

      {:ok, %Finch.Response{status: 500, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"reason" => reason}} -> {:error, reason}
          _ -> {:error, "Unknown error"}
        end

      {:ok, %Finch.Response{status: status}} ->
        {:error, "Unexpected status code: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp send_code(session_id, code) do
    url = "#{sandbox_url()}/submit"
    body = Jason.encode!(%{session_id: session_id, code: code})
    headers = [{"Content-Type", "application/json"}]

    case Finch.build(:post, url, headers, body) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"status" => "ok", "result" => output}} -> {:ok, output}
          {:ok, %{"status" => reason}} -> {:error, reason}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
