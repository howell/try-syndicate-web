defmodule TrySyndicate.Syndicate.ActorEnv do
  alias TrySyndicate.Syndicate.{Dataspace, Facet, Json}

  @type t() :: %{Dataspace.actor_id() => actor_detail()}

  @type actor_detail() :: %{Facet.fid() => Facet.t()}

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    case Json.parse_list(json, &parse_actor_env_item/1) do
      {:ok, items} -> {:ok, Map.new(items)}
      {:error, reason} -> {:error, "Invalid actor environment JSON: #{reason}"}
    end
  end

  def parse_actor_env_item(json) do
    with {:ok, actor_id} <- Json.parse_field(json, "actor_id"),
         {:ok, actor_detail} <- Json.parse_field(json, "facets", &parse_actor_detail/1) do
      {:ok, {actor_id, actor_detail}}
    else
      {:error, reason} -> {:error, "Invalid actor detail: #{reason}"}
    end
  end

  @spec parse_actor_detail(term()) :: {:ok, actor_detail()} | {:error, String.t()}
  def parse_actor_detail(json) do
    case Json.parse_list(json, &parse_actor_detail_item/1) do
      {:ok, items} -> {:ok, Map.new(items)}
      {:error, reason} -> {:error, "Invalid actor detail JSON: #{reason}"}
    end
  end

  def parse_actor_detail_item(json) do
    with {:ok, fid} <- Json.parse_field(json, "fid"),
         {:ok, facet} <- Json.parse_field(json, "facet", &Facet.from_json/1) do
      {:ok, {fid, facet}}
    else
      {:error, reason} -> {:error, "Invalid actor detail item: #{reason}"}
    end
  end
end
