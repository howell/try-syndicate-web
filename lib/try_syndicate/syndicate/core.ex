defmodule TrySyndicate.Syndicate.Core do
  @type trie() :: [String.t()]
  @type patch() :: {trie(), trie()}
  @type spawn() :: {:spawn, trie()}
  @type message() :: {:message, term()}
  @type action() :: patch() | :quit | spawn() | message()
  @type event() :: patch() | message() | false

  @spec json_to_trie(term()) :: {:ok, trie()} | {:error, String.t()}
  def json_to_trie(json) do
    if is_list(json) and Enum.all?(json, &is_binary/1) do
      {:ok, json}
    else
      {:error, "Invalid trie: expected list of strings"}
    end
  end

  @spec json_to_patch(term()) :: {:ok, patch()} | {:error, String.t()}
  def json_to_patch(json) do
    if is_map(json) and json["added"] && json["removed"] do
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
      {:ok, {:message, Enum.at(json, 1)}}
    else
      {:error, "Invalid message format"}
    end
  end

  @spec json_to_action(term()) :: {:ok, action()} | {:error, String.t()}
  def json_to_action(json) do
    case json_to_quit(json) do
      {:ok, result} -> {:ok, result}
      {:error, _} ->
        case json_to_message(json) do
          {:ok, result} -> {:ok, result}
          {:error, _} ->
            case json_to_spawn(json) do
              {:ok, result} -> {:ok, result}
              {:error, _} ->
                case json_to_patch(json) do
                  {:ok, result} -> {:ok, result}
                  {:error, _} -> {:error, "Invalid action"}
                end
            end
        end
    end
  end

  @spec json_to_event(term()) :: {:ok, event()} | {:error, String.t()}
  def json_to_event(json) do
    if json == false do
      {:ok, false}
    else
      case json_to_message(json) do
        {:ok, result} -> {:ok, result}
        {:error, _} ->
          case json_to_patch(json) do
            {:ok, result} -> {:ok, result}
            {:error, _} -> {:error, "Invalid event"}
          end
      end
    end
  end
end
