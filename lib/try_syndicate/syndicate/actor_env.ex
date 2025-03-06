defmodule TrySyndicate.Syndicate.ActorEnv do
  alias TrySyndicate.Syndicate.{Dataspace, Json, ActorDetail}

  @type t() :: %{Dataspace.actor_id() => ActorDetail.t()}

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    case Json.parse_list(json, &parse_actor_env_item/1) do
      {:ok, items} -> {:ok, Map.new(items)}
      {:error, reason} -> {:error, "Invalid actor environment JSON: #{reason}"}
    end
  end

  def parse_actor_env_item(json) do
    with {:ok, actor_id} <- Json.parse_field(json, "actor_id"),
         {:ok, actor_detail} <- Json.parse_field(json, "detail", &ActorDetail.from_json/1) do
      {:ok, {actor_id, actor_detail}}
    else
      {:error, reason} -> {:error, "Invalid actor detail: #{reason}"}
    end
  end

end
