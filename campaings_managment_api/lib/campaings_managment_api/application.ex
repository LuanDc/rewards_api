defmodule CampaingsManagmentApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CampaingsManagmentApiWeb.Telemetry,
      CampaingsManagmentApi.Repo,
      {DNSCluster, query: Application.get_env(:campaings_managment_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CampaingsManagmentApi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CampaingsManagmentApi.Finch},
      # Start a worker by calling: CampaingsManagmentApi.Worker.start_link(arg)
      # {CampaingsManagmentApi.Worker, arg},
      # Start to serve requests, typically the last entry
      CampaingsManagmentApiWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CampaingsManagmentApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CampaingsManagmentApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
