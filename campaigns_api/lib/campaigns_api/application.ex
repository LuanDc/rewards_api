defmodule CampaignsApi.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        CampaignsApiWeb.Telemetry,
        CampaignsApi.Repo,
        {DNSCluster, query: Application.get_env(:campaigns_api, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: CampaignsApi.PubSub},
        {Finch, name: CampaignsApi.Finch},
        CampaignsApiWeb.Endpoint
      ] ++ messaging_children()

    opts = [strategy: :one_for_one, name: CampaignsApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @spec messaging_children() :: [Supervisor.child_spec()]
  defp messaging_children do
    if Application.fetch_env!(:campaigns_api, CampaignsApiMessaging)[:enabled] do
      [CampaignsApiMessaging.ChallengeConsumer]
    else
      []
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    CampaignsApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
