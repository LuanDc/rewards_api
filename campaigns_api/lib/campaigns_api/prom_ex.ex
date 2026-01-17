defmodule CampaignsApi.PromEx do
  @moduledoc """
  PromEx module for comprehensive observability metrics.

  This module configures and exposes Prometheus metrics for:
  - BEAM VM metrics (memory, processes, schedulers)
  - Phoenix endpoint metrics (requests, response times)
  - Ecto query metrics (query duration, pool stats)
  - PostgreSQL database metrics
  - Custom application metrics
  """
  use PromEx, otp_app: :campaigns_api

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # PromEx built-in plugins
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: CampaignsApiWeb.Router, endpoint: CampaignsApiWeb.Endpoint},
      Plugins.Ecto,
      Plugins.PhoenixLiveView

      # Custom plugins can be added here
      # {CampaignsApi.PromEx.CustomPlugin, []}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      # PromEx built-in Grafana dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {:prom_ex, "phoenix_live_view.json"}
    ]
  end
end
