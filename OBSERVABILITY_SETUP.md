# Observability Stack - Setup Guide

## Visão Geral

Esta aplicação implementa observabilidade completa usando a **LGTM Stack (Grafana Stack)** com integração via **OpenTelemetry** e **PromEx**.

### Stack Completa

- **Loki** - Agregação de logs
- **Grafana** - Dashboards e visualização
- **Tempo** - Distributed tracing
- **Prometheus** - Métricas time-series
- **OpenTelemetry Collector** - Gateway OTLP para todos os dados de telemetria
- **PostgreSQL Exporter** - Métricas do banco de dados

### Bibliotecas Elixir

- **PromEx** - Métricas Prometheus para BEAM/Phoenix/Ecto
- **OpenTelemetry** - Traces distribuídos e logs estruturados
- **OpenTelemetry Phoenix** - Instrumentação automática do Phoenix
- **OpenTelemetry Ecto** - Instrumentação automática do Ecto

---

## PromEx vs OpenTelemetry - Quando usar cada um?

### PromEx 📊

**O que faz:**
- Coleta e expõe métricas no formato Prometheus
- Dashboards Grafana prontos e otimizados para BEAM
- Plug-and-play para Phoenix/Ecto

**Casos de uso:**
- Métricas de sistema (CPU, memória, processos BEAM)
- Performance de requisições HTTP
- Latência de queries do banco
- Throughput da aplicação

**Exemplo de métricas:**
```elixir
# Métricas automáticas geradas pelo PromEx:
- vm_total_run_queue_lengths_total
- phoenix_endpoint_stop_duration_bucket
- ecto_query_duration_bucket
- vm_memory_total
```

### OpenTelemetry 🔍

**O que faz:**
- Distributed tracing (rastreamento entre microservices)
- Logs estruturados com correlação de trace_id
- Vendor-neutral (pode exportar para qualquer backend)

**Casos de uso:**
- Rastrear uma requisição através de múltiplos serviços
- Debug de latência em chamadas externas
- Correlacionar logs com traces
- Entender o fluxo completo de uma transação

**Exemplo de trace:**
```
HTTP Request → Controller → Ecto Query → External API → Response
    |             |              |              |
  50ms          10ms           100ms          200ms
```

### Por que usar AMBOS? 🎯

```
PromEx          → Métricas agregadas (WHAT)
OpenTelemetry   → Traces individuais (HOW/WHY)

Exemplo prático:
1. PromEx mostra: "p95 de latência = 500ms" (problema detectado)
2. OpenTelemetry mostra: "Esta requisição específica levou 2s porque
   a query X demorou 1.8s" (causa raiz identificada)
```

**Correlação entre métricas e traces:**
- Grafana permite clicar em uma métrica e ver os traces relacionados
- Loki permite filtrar logs por trace_id
- Tempo mostra métricas agregadas geradas pelos traces

---

## Instalação

### 1. Instalar dependências Elixir

```bash
cd campaigns_api
mix deps.get
```

### 2. Subir a stack de observabilidade

```bash
# Na raiz do projeto
docker-compose up -d
```

Isso irá subir:
- PostgreSQL (porta 5432)
- RabbitMQ (portas 5672, 15672)
- Keycloak (porta 8080)
- **Prometheus** (porta 9090)
- **Grafana** (porta 3000)
- **Tempo** (porta 3200)
- **Loki** (porta 3100)
- **OpenTelemetry Collector** (portas 4317, 4318)
- **PostgreSQL Exporter** (porta 9187)

### 3. Verificar se os serviços estão rodando

```bash
# Health checks
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3100/ready      # Loki
curl http://localhost:3200/ready      # Tempo
curl http://localhost:13133           # OTel Collector
```

### 4. Iniciar a aplicação Elixir

```bash
cd campaigns_api
mix phx.server
```

A aplicação estará disponível em:
- **API**: http://localhost:4000
- **Métricas**: http://localhost:4000/metrics (PromEx)

**Nota**: Se você ver a mensagem `OTLP grpc export failed with error: :econnrefused`, isso é normal se o docker-compose não estiver rodando. As métricas do PromEx continuarão funcionando normalmente.

---

## Acessar Dashboards

### Grafana
- **URL**: http://localhost:3000
- **Autenticação**: Desabilitada (modo dev)
- **Dashboards pré-configurados**:
  - Elixir BEAM Overview
  - PostgreSQL Overview
  - Phoenix (via PromEx)
  - Ecto (via PromEx)

### Prometheus
- **URL**: http://localhost:9090
- **Queries de exemplo**:
  ```promql
  # Requisições por segundo
  sum(rate(phoenix_endpoint_stop_duration_count[5m]))

  # Latência p95
  histogram_quantile(0.95, rate(phoenix_endpoint_stop_duration_bucket[5m]))

  # Memória BEAM
  vm_memory_total

  # Processos ativos
  vm_process_count
  ```

### Tempo (Traces)
- **URL**: http://localhost:3200
- Acesso via Grafana → Explore → Tempo

### Loki (Logs)
- **URL**: http://localhost:3100
- Acesso via Grafana → Explore → Loki

---

## Como usar

### 1. Visualizar métricas no Grafana

1. Acesse http://localhost:3000
2. Menu lateral → Dashboards
3. Abra "Elixir BEAM Overview" ou "PostgreSQL Overview"
4. Os dados começarão a aparecer automaticamente após alguns minutos

### 2. Explorar traces distribuídos

1. Faça algumas requisições na API:
   ```bash
   curl http://localhost:4000/api/campaigns
   ```

2. No Grafana:
   - Menu lateral → Explore
   - Datasource: Tempo
   - Query: `{service.name="campaigns_api"}`
   - Visualize o trace completo da requisição

### 3. Correlacionar logs com traces

1. No Grafana Explore (Loki):
   ```logql
   {service_name="campaigns_api"} |= "trace_id"
   ```

2. Clique em um log que contém `trace_id`
3. Clique no botão "Tempo" para ver o trace relacionado

### 4. Debugging de performance

**Cenário**: Endpoint lento

1. **PromEx** → Identifique o endpoint com latência alta
2. **Tempo** → Veja traces específicos desse endpoint
3. **Loki** → Correlacione logs com o trace_id
4. **PostgreSQL Dashboard** → Verifique queries lentas

---

## Exemplos de Queries

### Prometheus (Métricas)

```promql
# Top 5 endpoints mais lentos (p95)
topk(5, histogram_quantile(0.95,
  rate(phoenix_endpoint_stop_duration_bucket[5m])))

# Taxa de erro 5xx
sum(rate(phoenix_endpoint_stop_duration_count{status=~"5.."}[5m]))

# Conexões ativas do PostgreSQL
pg_stat_activity_count

# Cache hit ratio do PostgreSQL
rate(pg_stat_database_blks_hit[5m]) /
  (rate(pg_stat_database_blks_hit[5m]) +
   rate(pg_stat_database_blks_read[5m]))
```

### TraceQL (Tempo - Traces)

```traceql
# Traces com duração > 1s
{ duration > 1s }

# Traces com erro
{ status = error }

# Traces de um endpoint específico
{ name = "POST /api/campaigns" }

# Traces com query Ecto lenta
{ span.name =~ "ecto.query.*" && duration > 500ms }
```

### LogQL (Loki - Logs)

```logql
# Logs de erro
{service_name="campaigns_api"} |= "error"

# Logs por trace_id
{service_name="campaigns_api"} | json | trace_id="abc123"

# Logs com latência
{service_name="campaigns_api"} | json | duration > 1000

# Rate de logs de erro por minuto
sum(rate({service_name="campaigns_api"} |= "error" [1m]))
```

---

## Configuração de Alertas (Opcional)

Crie um arquivo `observability/alertmanager.yml` para configurar alertas:

```yaml
route:
  group_by: ['alertname']
  receiver: 'slack'

receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

Exemplos de alertas úteis:

```yaml
# observability/prometheus-alerts.yml
groups:
  - name: campaigns_api
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(phoenix_endpoint_stop_duration_count{status=~"5.."}[5m]))
          / sum(rate(phoenix_endpoint_stop_duration_count[5m])) > 0.05
        for: 5m
        annotations:
          summary: "Alta taxa de erro (>5%)"

      - alert: HighLatency
        expr: |
          histogram_quantile(0.95,
            rate(phoenix_endpoint_stop_duration_bucket[5m])) > 1000
        for: 5m
        annotations:
          summary: "Latência p95 > 1s"

      - alert: DatabaseConnectionsHigh
        expr: pg_stat_activity_count > 80
        for: 5m
        annotations:
          summary: "Muitas conexões ativas no PostgreSQL"
```

---

## Troubleshooting

### Métricas não aparecem no Grafana

1. Verifique se a aplicação está expondo métricas:
   ```bash
   curl http://localhost:4000/metrics
   ```

2. Verifique se o Prometheus está coletando:
   ```bash
   curl http://localhost:9090/api/v1/targets
   ```

3. Verifique logs do OTel Collector:
   ```bash
   docker logs rewards_otel_collector
   ```

### Traces não aparecem no Tempo

1. Verifique se o OTel Collector está recebendo traces:
   ```bash
   curl http://localhost:13133
   ```

2. Verifique logs da aplicação Elixir:
   ```bash
   # Deve aparecer logs com trace_id
   [info] GET /api/campaigns trace_id=abc123 span_id=xyz789
   ```

### Logs não aparecem no Loki

1. Verifique se os logs estão sendo gerados com metadados:
   ```bash
   # Os logs devem incluir trace_id e span_id
   tail -f campaigns_api/_build/dev/rel/campaigns_api/var/log/erlang.log
   ```

2. Verifique se o Loki está healthy:
   ```bash
   curl http://localhost:3100/ready
   ```

---

## Performance e Recursos

### Consumo esperado (ambiente local)

- **Grafana**: ~100-200MB RAM
- **Prometheus**: ~200-500MB RAM (depende da retenção)
- **Tempo**: ~100-200MB RAM
- **Loki**: ~100-200MB RAM
- **OTel Collector**: ~50-100MB RAM

### Otimizações para produção

1. **Prometheus**: Configure retenção de dados
   ```yaml
   --storage.tsdb.retention.time=15d
   --storage.tsdb.retention.size=50GB
   ```

2. **Tempo**: Use object storage (S3, GCS)
3. **Loki**: Configure compactação e limites
4. **OTel Collector**: Ajuste batch size

---

## Métricas Customizadas

Para adicionar métricas customizadas, crie um plugin PromEx:

```elixir
# lib/campaigns_api/prom_ex/custom_plugin.ex
defmodule CampaignsApi.PromEx.CustomPlugin do
  use PromEx.Plugin

  @impl true
  def event_metrics(_opts) do
    [
      # Contador de campanhas criadas
      counter(
        [:campaigns_api, :campaigns, :created, :total],
        event_name: [:campaigns_api, :campaigns, :created],
        description: "Total de campanhas criadas",
        tags: [:tenant_id]
      ),

      # Histograma de duração de processamento
      distribution(
        [:campaigns_api, :campaign, :processing, :duration],
        event_name: [:campaigns_api, :campaign, :processing, :stop],
        description: "Tempo de processamento de campanha",
        measurement: :duration,
        unit: {:native, :millisecond},
        tags: [:status]
      )
    ]
  end
end
```

Depois adicione ao `lib/campaigns_api/prom_ex.ex`:

```elixir
def plugins do
  [
    # ... plugins existentes
    {CampaignsApi.PromEx.CustomPlugin, []}
  ]
end
```

E emita eventos no código:

```elixir
# Quando criar uma campanha
:telemetry.execute(
  [:campaigns_api, :campaigns, :created],
  %{count: 1},
  %{tenant_id: tenant_id}
)

# Quando processar uma campanha
start_time = System.monotonic_time()
# ... processamento
duration = System.monotonic_time() - start_time

:telemetry.execute(
  [:campaigns_api, :campaign, :processing, :stop],
  %{duration: duration},
  %{status: :success}
)
```

---

## Próximos Passos

1. ✅ Configurar alertas no Prometheus/Alertmanager
2. ✅ Criar dashboards customizados para métricas de negócio
3. ✅ Configurar retenção de dados apropriada
4. ✅ Integrar com sistema de notificações (Slack, PagerDuty)
5. ✅ Adicionar SLIs/SLOs específicos da aplicação
6. ✅ Configurar sampling de traces em produção (reduzir volume)

---

## Referências

- [PromEx Documentation](https://hexdocs.pm/prom_ex)
- [OpenTelemetry Elixir](https://opentelemetry.io/docs/instrumentation/erlang/)
- [Grafana LGTM Stack](https://grafana.com/docs/grafana-cloud/data-configuration/integrations/integration-reference/integration-lgtm/)
- [Tempo Documentation](https://grafana.com/docs/tempo/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)

---

## Suporte

Para problemas ou dúvidas sobre observabilidade:
1. Verifique os logs dos containers: `docker-compose logs <service>`
2. Consulte a documentação oficial das ferramentas
3. Abra uma issue no repositório
