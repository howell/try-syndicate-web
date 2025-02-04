defmodule TrySyndicate.Syndicate.Dataspace do
  @moduledoc """
  This module defines the data used to represent a dataspace.
  """
  alias TrySyndicate.Syndicate.{Actor, SpaceTime, Core}

  @type actor_id() :: binary()

  @type t() :: %__MODULE__{
          actors: %{actor_id() => Actor.t()},
          active_actor: :none | {actor_id(), Core.event()},
          recent_messages: [String.t()],
          pending_actions: [{SpaceTime.t(), [Core.action()]}]
        }

  @fields [
    :actors,
    :active_actor,
    :recent_messages,
    :pending_actions
  ]

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) and Enum.all?(@fields, &Map.has_key?(json, to_string(&1))) do
      with {:ok, actors} <- parse_actors(json["actors"]),
           {:ok, active_actor} <- parse_active_actor(json["active_actor"]),
           {:ok, recent_messages} <- parse_recent_messages(json["recent_messages"]),
           {:ok, pending_actions} <- parse_pending_acts(json["pending_actions"]) do
        {:ok, %__MODULE__{
          actors: actors,
          active_actor: active_actor,
          recent_messages: recent_messages,
          pending_actions: pending_actions
        }}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, "Invalid JSON: missing required fields"}
    end
  end

  @spec parse_actors(term()) :: {:ok, %{actor_id() => Actor.t()}} | {:error, String.t()}
  def parse_actors(json) do
    if is_list(json) and Enum.all?(json, &is_map/1) do
      Enum.reduce_while(json, {:ok, %{}}, fn actor_json, {:ok, acc} ->
        case Actor.from_json(actor_json) do
          {:ok, actor} ->
            if Map.has_key?(actor_json, "id") and is_binary(actor_json["id"]) do
              {:cont, {:ok, Map.put(acc, actor_json["id"], actor)}}
            else
              {:halt, {:error, "Invalid actor: missing valid 'id'"}}
            end
          {:error, reason} ->
            {:halt, {:error, "Invalid actor: " <> reason}}
        end
      end)
    else
      {:error, "Invalid actors JSON: expected a list of maps"}
    end
  end

  @spec parse_active_actor(term()) :: {:ok, :none | {actor_id(), Core.event()}} | {:error, String.t()}
  def parse_active_actor(json) do
    cond do
      json == false ->
        {:ok, :none}

      is_map(json) and is_binary(json["actor"]) and json["event"] ->
        case Core.json_to_event(json["event"]) do
          {:ok, event} -> {:ok, {json["actor"], event}}
          {:error, reason} -> {:error, "Invalid active actor event: " <> reason}
        end

      true ->
        {:error, "Invalid active actor JSON"}
    end
  end

  @spec parse_recent_messages(term()) :: {:ok, [String.t()]} | {:error, String.t()}
  def parse_recent_messages(json) do
    if is_list(json) and Enum.all?(json, &is_binary/1) do
      {:ok, json}
    else
      {:error, "Invalid recent_messages: expected a list of strings"}
    end
  end

  @spec parse_pending_acts(term()) :: {:ok, [{SpaceTime.t(), [Core.action()]}]} | {:error, String.t()}
  def parse_pending_acts(json) do
    if is_list(json) and Enum.all?(json, &is_map/1) do
      Enum.reduce_while(json, {:ok, []}, fn action_json, {:ok, acc} ->
        case SpaceTime.from_json(action_json["origin"]) do
          {:ok, space_time} ->
            actions_result =
              Enum.reduce_while(action_json["actions"], {:ok, []}, fn act, {:ok, acts_acc} ->
                case Core.json_to_action(act) do
                  {:ok, action} ->
                    {:cont, {:ok, acts_acc ++ [action]}}
                  {:error, reason} ->
                    {:halt, {:error, "Invalid action: " <> reason}}
                end
              end)

            case actions_result do
              {:ok, actions} ->
                {:cont, {:ok, [{space_time, actions} | acc]}}
              {:error, reason} ->
                {:halt, {:error, reason}}
            end

          {:error, reason} ->
            {:halt, {:error, "Invalid origin in pending act: " <> reason}}
        end
      end)
      |> (fn
            {:ok, acts} -> {:ok, Enum.reverse(acts)}
            error -> error
          end).()
    else
      {:error, "Invalid pending_actions: expected a list of maps"}
    end
  end
end
