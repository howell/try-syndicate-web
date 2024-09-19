defmodule TrySyndicate.Repo do
  use Ecto.Repo,
    otp_app: :try_syndicate,
    adapter: Ecto.Adapters.Postgres
end
