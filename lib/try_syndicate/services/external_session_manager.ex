defmodule TrySyndicate.ExternalSessionManager do
  use GenServer
  @behaviour TrySyndicate.SessionManager

  require Logger

  defmodule OutputStatus do
    @type t() :: %__MODULE__{
            next_expected_seq: non_neg_integer(),
            pending: [{non_neg_integer(), any()}]
          }
    defstruct [:next_expected_seq, :pending]

    def new(expected_seq) do
      %__MODULE__{next_expected_seq: expected_seq, pending: []}
    end

    @spec handle_session_output(OutputStatus.t(), non_neg_integer(), any()) ::
            {[any()], OutputStatus.t()}
    def handle_session_output(
          %__MODULE__{next_expected_seq: expected_seq, pending: pending} = status,
          seq_no,
          data
        ) do
      cond do
        seq_no < expected_seq ->
          Logger.info("Received duplicate output \##{seq_no}")
          {[], status}

        seq_no > expected_seq ->
          Logger.info("Received future output \##{seq_no}")

          {
            [],
            %__MODULE__{status | pending: [{seq_no, data} | pending]}
          }

        true ->
          new_expected_seq = expected_seq + 1
          {collected, leftover, final_seq} = collect_ready(pending, new_expected_seq)

          {
            [data | collected],
            %__MODULE__{next_expected_seq: final_seq, pending: leftover}
          }
      end
    end

    @spec collect_ready([{non_neg_integer(), any()}], non_neg_integer()) ::
            {[any()], [{non_neg_integer(), any()}], non_neg_integer()}
    def collect_ready(pending, expected_seq) do
      sorted = Enum.sort_by(pending, &elem(&1, 0))

      Enum.reduce_while(sorted, {[], expected_seq}, fn {seq, data}, {acc, current_seq} ->
        if seq == current_seq do
          {:cont, {[data | acc], current_seq + 1}}
        else
          {:halt, {acc, current_seq}}
        end
      end)
      |> then(fn {ready, new_seq} ->
        {Enum.reverse(ready), Enum.drop(sorted, length(ready)), new_seq}
      end)
    end
  end

  defmodule Session do
    @type output_status() :: OutputStatus.t()
    @type t() :: %__MODULE__{
            id: String.t(),
            sources: %{TrySyndicate.SessionManager.output_src() => output_status()}
          }
    defstruct [:id, :sources]

    def new(id) do
      %__MODULE__{
        id: id,
        sources: %{
          "stdout" => OutputStatus.new(0),
          "stderr" => OutputStatus.new(0),
          "trace" => OutputStatus.new(0)
        }
      }
    end
  end

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

  def execute_code(session_id, code, name) do
    GenServer.call(__MODULE__, {:execute_code, session_id, code, name})
  end

  def session_status(session_id) do
    GenServer.call(__MODULE__, {:session_status, session_id})
  end

  def receive_outputs(session_id, src, outputs) do
    GenServer.cast(__MODULE__, {:receive_outputs, session_id, src, outputs})
  end

  def handle_call({:start_session, session_id}, _from, state) do
    Logger.info("Starting session: #{session_id}")

    case start_repl_session(session_id) do
      :ok -> {:reply, :ok, Map.put(state, session_id, Session.new(session_id))}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:execute_code, session_id, code, name}, _from, state) do
    if Map.get(state, session_id) do
      case send_code(session_id, code, name) do
        {:ok, output} -> {:reply, {:ok, output}, state}
        {:error, reason} -> {:reply, {:error, reason}, Map.delete(state, session_id)}
      end
    else
      {:reply, {:error, "Session expired"}, state}
    end
  end

  def handle_call({:session_status, session_id}, _from, state) do
    if Map.get(state, session_id) do
      query_session_status(session_id, state)
    else
      {:reply, {:ok, :inactive}, state}
    end
  end

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
    if Map.get(state, session_id) do
      if send_keep_alive(session_id) == :ok do
        {:noreply, state}
      else
        {:noreply, Map.delete(state, session_id)}
      end
    else
      {:noreply, state}
    end
  end

  def handle_cast({:receive_outputs, session_id, src, outputs}, state) do
    {:noreply, handle_outputs(session_id, src, outputs, state)}
  end

  defp send_keep_alive(session_id) do
    url = "#{sandbox_url()}/keep_alive"
    body = Jason.encode!(%{session_id: session_id})
    headers = [{"Content-Type", "application/json"}]

    case Finch.build(:post, url, headers, body) |> Finch.request(TrySyndicate.Finch) do
      {:ok, %Finch.Response{status: 200}} -> :ok
      {:ok, %Finch.Response{status: s}} -> {:error, "Session not found (#{s})"}
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

  defp send_code(session_id, code, name) do
    url = "#{sandbox_url()}/submit"
    body = Jason.encode!(%{session_id: session_id, code: code, name: name})
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

  defp handle_outputs(session_id, src, outputs, state) do
    case Map.get(state, session_id) do
      nil ->
        Logger.warning("Received outputs for unknown session: #{session_id}")
        state

      session ->
        {outputs, new_status} = Enum.reduce(outputs, {[], session.sources[src]}, fn {seq_no, data}, {ready_outputs, status} ->
          {more_ready, new_status} = OutputStatus.handle_session_output(status, seq_no, data)
          {ready_outputs ++ more_ready, new_status}
        end)

        if outputs != [] do
          TrySyndicateWeb.Endpoint.broadcast("session:#{session_id}", "update", %{
            type: src,
            data: outputs
          })
        end

        new_session = put_in(session.sources[src], new_status)
        Map.put(state, session_id, new_session)
    end
  end
end
