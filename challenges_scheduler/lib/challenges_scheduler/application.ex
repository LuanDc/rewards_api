defmodule ChallengesScheduler.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ChallengesSchedulerWeb.Telemetry,
        ChallengesScheduler.Repo,
        {DNSCluster,
         query: Application.get_env(:challenges_scheduler, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: ChallengesScheduler.PubSub},
        {Finch, name: ChallengesScheduler.Finch},
        ChallengesSchedulerWeb.Endpoint,
        ChallengesSchedulerMessaging.CampaignProjectionConsumer
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ChallengesScheduler.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChallengesSchedulerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
