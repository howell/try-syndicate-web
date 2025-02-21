defmodule TrySyndicate.Syndicate.ActorEnv do
  alias TrySyndicate.Syndicate.{Dataspace, Facet}

  @type actor_env() :: %{Dataspace.actor_id() => actor_detail()}

  @type actor_detail() :: %{Facet.fid() => Facet.t()}
end
