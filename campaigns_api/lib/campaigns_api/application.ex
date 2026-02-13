defmodule CampaignsApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CampaignsApiWeb.Telemetry,
      CampaignsApi.Repo,
      {DNSCluster, query: Application.get_env(:campaigns_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CampaignsApi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CampaignsApi.Finch},
      # Start a worker by calling: CampaignsApi.Worker.start_link(arg)
      # {CampaignsApi.Worker, arg},
      # Start to serve requests, typically the last entry
      CampaignsApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CampaignsApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CampaignsApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
