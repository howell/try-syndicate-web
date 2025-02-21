defmodule TrySyndicate.Syndicate.ActorEnv do
  alias TrySyndicate.Syndicate.{Dataspace, Facet, Json}

  @type t() :: %{Dataspace.actor_id() => actor_detail()}

  @type actor_detail() :: %{Facet.fid() => Facet.t()}

  @spec from_json(term()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) do
    if is_map(json) do
      Map.to_list(json)
      |> Json.parse_list(&parse_actor_env_item/1)
      |> (fn
            {:ok, items} -> {:ok, Map.new(items)}
            error -> error
          end).()
    else
      {:error, "Invalid actor environment JSON: not a map"}
    end
  end

  def parse_actor_env_item({actor_id, json}) do
    case parse_actor_detail(json) do
      {:ok, actor_detail} -> {:ok, {actor_id, actor_detail}}
      {:error, reason} -> {:error, "Invalid actor environment item JSON: #{reason}"}
    end
  end

  @spec parse_actor_detail(term()) :: {:ok, actor_detail()} | {:error, String.t()}
  def parse_actor_detail(json) do
    if is_map(json) do
      Map.to_list(json)
      |> Json.parse_list(&parse_actor_detail_item/1)
      |> (fn
            {:ok, items} -> {:ok, Map.new(items)}
            error -> error
          end).()
    else
      {:error, "Invalid actor detail JSON: not a map"}
    end
  end

  def parse_actor_detail_item({actor_id, json}) do
    case Facet.from_json(json) do
      {:ok, facet} -> {:ok, {actor_id, facet}}
      {:error, reason} -> {:error, "Invalid actor detail item JSON: #{reason}"}
    end
  end
end
