defmodule TrySyndicate.SessionManager do
  use GenServer

  require Logger

  @sandbox_url "http://localhost:4001"

  def init(state) do
    {:ok, state}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def start_session() do
    session_id = UUID.uuid4()
    Logger.info("Starting session: #{session_id}")
    :ok = start_repl_session(session_id)
    GenServer.cast(__MODULE__, {:add_session, session_id})
    session_id
  end

  def execute_code(session_id, code) do
    url = "#{@sandbox_url}/submit"
    body = Jason.encode!(%{session_id: session_id, code: code})
    headers = [{"Content-Type", "application/json"}]
    case Finch.build(:post, url, headers, body) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{body: body}} -> case Jason.decode(body) do
        {:ok, %{"status" => "ok", "result" => output}} -> {:ok, output}
        {:ok, %{"status" => reason}} -> {:error, reason}
        {:error, reason} -> {:error, reason}
      end
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_repl_session(session_id) do
    url = "#{@sandbox_url}/new"
    body = Jason.encode!(%{session_id: session_id})
    headers = [{"Content-Type", "application/json"}]
    case Finch.build(:post, url, headers, body) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{status: 200}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_cast({:add_session, session_id}, state) do
    {:noreply, Map.put(state, session_id, :active)}
  end
end
