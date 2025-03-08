defmodule TrySyndicate.Syndicate.Core do
  alias TrySyndicate.Syndicate.Json

  @type trie() :: [String.t()]
  @type patch() :: {trie(), trie()}
  @type spawn() :: {:spawn, trie()}
  @type message() :: {:message, term()}
  @type action() :: event() | :quit | spawn()
  @type event() :: patch() | message() | false | :boot

  @spec json_to_formatted_value(term()) :: {:ok, String.t()} | {:error, String.t()}
  @doc """
    Accepts a JSON string representing a Racket value (but doesn't check it)
    and formats it in a more readable way. Specifically, it removes quote and struct prefixes
    '#s and #s.
  """
  def json_to_formatted_value(json) when is_binary(json) do
    quote_pattern = ~r/'?#s/
    {:ok, String.replace(json, quote_pattern, "")}
  end

  def json_to_formatted_value(_json), do: {:error, "Invalid value: not a string"}

  @spec json_to_trie(term()) :: {:ok, trie()} | {:error, String.t()}
  def json_to_trie(json) do
    Json.parse_list(json, &json_to_formatted_value/1)
  end

  @spec json_to_patch(term()) :: {:ok, patch()} | {:error, String.t()}
  def json_to_patch(json) do
    if (is_map(json) and json["added"]) && json["removed"] do
      with {:ok, added} <- json_to_trie(json["added"]),
           {:ok, removed} <- json_to_trie(json["removed"]) do
        {:ok, {added, removed}}
      else
        {:error, reason} -> {:error, "Invalid patch: " <> reason}
      end
    else
      {:error, "Invalid patch JSON: missing 'added' or 'removed'"}
    end
  end

  @spec json_to_spawn(term()) :: {:ok, spawn()} | {:error, String.t()}
  def json_to_spawn(json) do
    cond do
      not is_list(json) ->
        {:error, "Invalid spawn JSON: expected a list"}

      length(json) != 2 and hd(json) == "spawn" ->
        {:error, "Invalid spawn JSON: expected a list with two elements, starting with 'spawn'"}

      true ->
        with {:ok, trie} <- json_to_trie(hd(tl(json))) do
          {:ok, {:spawn, trie}}
        else
          {:error, reason} -> {:error, "Invalid spawn assertions: " <> reason}
        end
    end
  end

  @spec json_to_quit(term()) :: {:ok, :quit} | {:error, String.t()}
  def json_to_quit(json) do
    if json == "quit" do
      {:ok, :quit}
    else
      {:error, "Not a quit command"}
    end
  end

  @spec json_to_message(term()) :: {:ok, message()} | {:error, String.t()}
  def json_to_message(json) do
    if is_list(json) and length(json) == 2 and hd(json) == "message" do
      with {:ok, message} <- json_to_formatted_value(Enum.at(json, 1)) do
        {:ok, {:message, message}}
      else
        {:error, reason} -> {:error, "Invalid message: " <> reason}
      end
    else
      {:error, "Invalid message format"}
    end
  end

  @spec json_to_action(term()) :: {:ok, action()} | {:error, String.t()}
  def json_to_action(json) do
    case json_to_quit(json) do
      {:ok, result} ->
        {:ok, result}

      {:error, _} ->
        case json_to_message(json) do
          {:ok, result} ->
            {:ok, result}

          {:error, _} ->
            case json_to_spawn(json) do
              {:ok, result} ->
                {:ok, result}

              {:error, _} ->
                case json_to_patch(json) do
                  {:ok, result} -> {:ok, result}
                  {:error, _} -> {:error, "Invalid action: #{inspect(json)}"}
                end
            end
        end
    end
  end

  @spec json_to_event(term()) :: {:ok, event()} | {:error, String.t()}
  def json_to_event(json) do
    cond do
      json == false ->
        {:ok, false}

      json == "boot" ->
        {:ok, :boot}

      true ->
        case json_to_message(json) do
          {:ok, result} ->
            {:ok, result}

          {:error, _} ->
            case json_to_patch(json) do
              {:ok, result} -> {:ok, result}
              {:error, _} -> {:error, "Invalid event: #{inspect(json)}"}
            end
        end
    end
  end
end
