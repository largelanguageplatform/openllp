defmodule Platform.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PlatformWeb.Telemetry,
      Platform.Repo,
      Platform.Bootstrap,
      {DNSCluster, query: Application.get_env(:platform, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Platform.PubSub},
      {DynamicSupervisor, name: Platform.Chaos.Agent.Supervisor},
      {DynamicSupervisor, name: Platform.Chaos.Orchestrator.Supervisor},
      Platform.Agent.Manager,
      # Start to serve requests, typically the last entry
      PlatformWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Platform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
