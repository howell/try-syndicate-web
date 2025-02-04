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
          pending_acts: [{SpaceTime.t(), [Core.action()]}]
        }

  @fields [
    :actors,
    :active_actor,
    :recent_messages,
    :pending_acts
  ]

  @enforce_keys @fields
  defstruct @fields

  @spec from_json(term()) :: t() | nil
  def from_json(json) do
    if is_map(json) and Enum.all?(@fields, &Map.has_key?(json, &1)) do
      actors = parse_actors(json["actors"])
      active_actor = parse_active_actor(json["active_actor"])
      recent_messages = parse_recent_messages(json["recent_messages"])
      pending_acts = parse_pending_acts(json["pending_actions"])

      if actors && active_actor && recent_messages && pending_acts do
        %__MODULE__{
          actors: actors,
          active_actor: active_actor,
          recent_messages: recent_messages,
          pending_acts: pending_acts
        }
      else
        nil
      end
    else
      nil
    end
  end

  @spec parse_actors(term()) :: %{actor_id() => Actor.t()} | nil
  def parse_actors(json) do
    if is_list(json) and Enum.all?(json, &is_map/1) do
      Enum.reduce(json, %{}, fn actor_json, acc ->
        acc &&
          case Actor.from_json(actor_json) do
            nil ->
              nil

            actor ->
              if Map.has_key?(actor_json, "id") and is_binary(actor_json["id"]) do
                Map.put(acc, actor_json["id"], actor)
              else
                nil
              end
          end
      end)
    else
      nil
    end
  end

  @spec parse_active_actor(term()) :: :none | {actor_id(), Core.event()} | nil
  def parse_active_actor(json) do
    cond do
      json == false ->
        :none

      is_map(json) and is_binary(json["actor"]) and json["event"] ->
        {json["actor"], Core.json_to_event(json["event"])}
    end
  end

  @spec parse_recent_messages(term()) :: [String.t()] | nil
  def parse_recent_messages(json) do
    if is_list(json) and Enum.all?(json, &is_binary/1) do
      json
    else
      nil
    end
  end

  @spec parse_pending_acts(term()) :: [{SpaceTime.t(), [Core.action()]}] | nil
  def parse_pending_acts(json) do
    if is_list(json) and Enum.all?(json, &is_map/1) do
      Enum.reduce(json, [], fn action_json, acc ->
        case SpaceTime.from_json(action_json["origin"]) do
          nil ->
            nil

          space_time ->
            actions = Enum.map(action_json["actions"], &Core.json_to_action/1)
            if Enum.all?(actions), do: [{space_time, actions} | acc], else: nil
        end
      end)
    else
      nil
    end
  end
end
