defmodule TrySyndicate.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TrySyndicateWeb.Telemetry,
      TrySyndicate.Repo,
      {DNSCluster, query: Application.get_env(:try_syndicate, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TrySyndicate.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: TrySyndicate.Finch},
      # Start a worker by calling: TrySyndicate.Worker.start_link(arg)
      # {TrySyndicate.Worker, arg},
      TrySyndicate.SessionManager,
      # Start to serve requests, typically the last entry
      TrySyndicateWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TrySyndicate.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TrySyndicateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
