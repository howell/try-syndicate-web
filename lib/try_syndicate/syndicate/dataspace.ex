defmodule TrySyndicate.Syndicate.Dataspace do
  @moduledoc """
  This module defines the data used to represent a dataspace.
  """
  alias TrySyndicate.Syndicate.{Actor, SpaceTime, Core, Json}

  @type actor_id() :: binary()

  @type t() :: %__MODULE__{
          actors: %{actor_id() => Actor.t()},
          active_actor: :none | {actor_id(), Core.event(), false | [Core.action()]},
          pending_actions: [{SpaceTime.t(), [Core.action()]}],
          last_op: false | String.t()
        }

  @fields [
    :actors,
    :active_actor,
    :pending_actions,
    :last_op
  ]

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) and Enum.all?(@fields, &Map.has_key?(json, to_string(&1))) do
      with {:ok, actors} <- parse_actors(json["actors"]),
           {:ok, active_actor} <- parse_active_actor(json["active_actor"]),
           {:ok, pending_actions} <- parse_pending_acts(json["pending_actions"]),
           {:ok, last_op} <- parse_last_op(json["last_op"]) do
        {:ok,
         %__MODULE__{
           actors: actors,
           active_actor: active_actor,
           pending_actions: pending_actions,
           last_op: last_op
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

  @spec parse_active_actor(term()) ::
          {:ok, :none | {actor_id(), Core.event()}} | {:error, String.t()}
  def parse_active_actor(json) do
    cond do
      json == false ->
        {:ok, :none}

      is_map(json) and is_binary(json["actor"]) and Map.has_key?(json, "event") and
          Map.has_key?(json, "actions") ->
        with {:ok, event} <- Core.json_to_event(json["event"]),
             {:ok, actions} <-
               Json.parse_optional(json["actions"], fn json ->
                 Json.parse_list(json, &Core.json_to_action/1)
               end) do
          {:ok, {json["actor"], event, actions}}
        else
          {:error, reason} -> {:error, "Invalid active actor: " <> reason}
        end

      true ->
        {:error, "Invalid active actor JSON"}
    end
  end

  @spec parse_last_op(term()) :: {:ok, nil | atom()} | {:error, String.t()}
  def parse_last_op(json) do
    if json == false or is_binary(json) do
      {:ok, json}
    else
      {:error, "Invalid last_op JSON: expected a string or false"}
    end
  end

  @spec parse_pending_acts(term()) ::
          {:ok, [{SpaceTime.t(), [Core.action()]}]} | {:error, String.t()}
  def parse_pending_acts(json) do
    if is_list(json) and Enum.all?(json, &is_map/1) do
      Json.parse_list(json, &parse_pending_action/1)
    else
      {:error, "Invalid pending_actions: expected a list of maps"}
    end
  end

  def parse_pending_action(json) do
    if is_map(json) && json["origin"] && is_list(json["actions"]) do
      with {:ok, origin} <- SpaceTime.from_json(json["origin"]),
           {:ok, actions} <- Json.parse_list(json["actions"], &Core.json_to_action/1) do
        {:ok, {origin, actions}}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:error,
       "Invalid pending action JSON: expected an object with 'origin' and 'actions' fields #{inspect(json)}"}
    end
  end
end
