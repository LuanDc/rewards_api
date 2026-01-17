defmodule CampaignsApi.PromEx.BusinessMetricsPlugin do
  @moduledoc """
  Plugin PromEx para métricas de negócio da aplicação de campanhas.

  Este plugin define métricas customizadas específicas do domínio:
  - Contadores de campanhas criadas/ativadas/finalizadas
  - Distribuição de duração de processamento
  - Métricas de critérios de campanha

  ## Uso

  Adicione este plugin ao módulo PromEx principal:

      def plugins do
        [
          # ... outros plugins
          {CampaignsApi.PromEx.BusinessMetricsPlugin, []}
        ]
      end

  ## Emitindo eventos

  Para emitir eventos de telemetria que serão capturados por estas métricas:

      # Quando criar uma campanha
      :telemetry.execute(
        [:campaigns_api, :campaigns, :created],
        %{count: 1},
        %{tenant_id: tenant_id, campaign_type: "standard"}
      )

      # Quando processar uma campanha
      start_time = System.monotonic_time()
      # ... processamento
      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:campaigns_api, :campaign, :processing, :stop],
        %{duration: duration},
        %{status: :success, tenant_id: tenant_id}
      )
  """
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      campaign_events(),
      criteria_events(),
      error_events()
    ]
  end

  defp campaign_events do
    Event.build(
      :campaigns_api_campaign_event_metrics,
      [
        # Contadores de eventos de campanha
        counter(
          [:campaigns_api, :campaigns, :created, :total],
          event_name: [:campaigns_api, :campaigns, :created],
          description: "Total de campanhas criadas",
          measurement: :count,
          tags: [:tenant_id, :campaign_type]
        ),
        counter(
          [:campaigns_api, :campaigns, :activated, :total],
          event_name: [:campaigns_api, :campaigns, :activated],
          description: "Total de campanhas ativadas",
          measurement: :count,
          tags: [:tenant_id]
        ),
        counter(
          [:campaigns_api, :campaigns, :finished, :total],
          event_name: [:campaigns_api, :campaigns, :finished],
          description: "Total de campanhas finalizadas",
          measurement: :count,
          tags: [:tenant_id, :finish_reason]
        ),

        # Distribuições de duração
        distribution(
          [:campaigns_api, :campaign, :processing, :duration, :milliseconds],
          event_name: [:campaigns_api, :campaign, :processing, :stop],
          description: "Tempo de processamento de campanha",
          measurement: :duration,
          unit: {:native, :millisecond},
          tags: [:status, :tenant_id],
          reporter_options: [
            buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10_000]
          ]
        )
      ]
    )
  end

  defp criteria_events do
    Event.build(
      :campaigns_api_criteria_event_metrics,
      [
        counter(
          [:campaigns_api, :criteria, :created, :total],
          event_name: [:campaigns_api, :criteria, :created],
          description: "Total de critérios criados",
          measurement: :count,
          tags: [:tenant_id, :campaign_id]
        ),
        counter(
          [:campaigns_api, :criteria, :validation, :total],
          event_name: [:campaigns_api, :criteria, :validation],
          description: "Total de validações de critério",
          measurement: :count,
          tags: [:tenant_id, :result]
        )
      ]
    )
  end

  defp error_events do
    Event.build(
      :campaigns_api_error_event_metrics,
      [
        counter(
          [:campaigns_api, :errors, :total],
          event_name: [:campaigns_api, :error, :occurred],
          description: "Total de erros ocorridos",
          measurement: :count,
          tags: [:error_type, :context]
        )
      ]
    )
  end

  @impl true
  def polling_metrics(_opts) do
    [
      # Polling metrics podem ser usadas para expor métricas
      # que não são baseadas em eventos, mas sim consultadas periodicamente
      # Exemplo: número de campanhas ativas no banco

      # polling_metric(
      #   [:campaigns_api, :campaigns, :active, :count],
      #   fn ->
      #     # Query ao banco para contar campanhas ativas
      #     # count = CampaignsApi.Campaigns.count_active()
      #     # %{count: count}
      #   end,
      #   tags: [:tenant_id]
      # )
    ]
  end
end
