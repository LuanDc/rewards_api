defmodule CampaignsApi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Attach OpenTelemetry context to Logger metadata FIRST (trace_id, span_id)
    :ok = OpentelemetryLoggerMetadata.setup()

    # Setup OpenTelemetry instrumentation
    OpentelemetryPhoenix.setup()
    OpentelemetryEcto.setup([:campaigns_api, :repo])

    children =
      [
        CampaignsApiWeb.Telemetry,
        CampaignsApi.Repo,
        {DNSCluster, query: Application.get_env(:campaigns_api, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: CampaignsApi.PubSub},
        # PromEx for Prometheus metrics
        CampaignsApi.PromEx
      ] ++
        jwks_strategy_child() ++
        [
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

  # Add JWKS strategy to supervision tree only when JWKS URL is configured
  defp jwks_strategy_child do
    jwks_url = Application.get_env(:campaigns_api, :keycloak_jwks_url)

    if jwks_url do
      [{CampaignsApi.Auth.JwksStrategy, []}]
    else
      []
    end
  end
end
