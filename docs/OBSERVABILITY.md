# Observability Stack

Este documento descreve a arquitetura de observabilidade da Campaigns API, baseada na **LGTM Stack** (Loki, Grafana, Tempo, Prometheus).

## Visão Geral

A stack implementa os três pilares da observabilidade:
- **Logs** → Loki (via Promtail)
- **Traces** → Tempo (via OpenTelemetry)
- **Métricas** → Prometheus (via PromEx)

Todos os sinais são correlacionados através do `trace_id`, permitindo navegação seamless no Grafana.

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CAMPAIGNS-API (Port 4000)                            │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    OpenTelemetry Setup                               │   │
│  │  • OpentelemetryLoggerMetadata.setup() → injeta trace_id nos logs   │   │
│  │  • OpentelemetryPhoenix.setup() → instrumenta requests HTTP         │   │
│  │  • OpentelemetryEcto.setup() → instrumenta queries SQL              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  Request Flow:                                                              │
│  ┌──────────┐   ┌──────────────┐   ┌───────────────┐   ┌──────────────┐   │
│  │ RequestId│ → │ OpenTelemetry│ → │ RequestLogger │ → │   PromEx     │   │
│  │  Plug    │   │  (span)      │   │ (log c/ trace)│   │  (/metrics)  │   │
│  └──────────┘   └──────────────┘   └───────────────┘   └──────────────┘   │
│                                                                             │
│  Outputs:                                                                   │
│  • Traces (OTLP gRPC) ──────────────────────────────────────────┐          │
│  • Logs (stdout JSON) ──────────────────────────────────┐       │          │
│  • Métricas (/metrics) ────────────────────────┐        │       │          │
└────────────────────────────────────────────────│────────│───────│──────────┘
                                                 │        │       │
                                                 ▼        ▼       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COLLECTION LAYER                                   │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │   Prometheus    │  │    Promtail     │  │     OTEL Collector          │ │
│  │   (port 9090)   │  │   (port 9080)   │  │      (port 4317)            │ │
│  │                 │  │                 │  │                             │ │
│  │ Scrape /metrics │  │ Coleta logs do  │  │ Recebe OTLP traces          │ │
│  │ a cada 15s      │  │ Docker, extrai  │  │ Processa em batch           │ │
│  │                 │  │ trace_id        │  │ Adiciona resource labels    │ │
│  └────────┬────────┘  └────────┬────────┘  └─────────────┬───────────────┘ │
│           │                    │                         │                  │
└───────────│────────────────────│─────────────────────────│──────────────────┘
            │                    │                         │
            ▼                    ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            STORAGE LAYER                                     │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐             │
│  │   Prometheus    │  │      Loki       │  │      Tempo      │             │
│  │   (Métricas)    │  │     (Logs)      │  │    (Traces)     │             │
│  │   port 9090     │  │   port 3100     │  │   port 3200     │             │
│  │                 │  │                 │  │                 │             │
│  │ • App metrics   │  │ • Structured    │  │ • Distributed   │             │
│  │ • BEAM metrics  │  │   metadata      │  │   traces        │             │
│  │ • DB metrics    │  │ • trace_id      │  │ • Span metrics  │             │
│  │ • Exemplars     │  │   correlation   │  │ • Service graph │             │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘             │
│           │                    │                    │                       │
└───────────│────────────────────│────────────────────│───────────────────────┘
            │                    │                    │
            └────────────────────┼────────────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │        GRAFANA          │
                    │       (port 3000)       │
                    │                         │
                    │  • Dashboards           │
                    │  • Explore              │
                    │  • Alerting             │
                    │  • Cross-signal nav     │
                    └─────────────────────────┘
```

## Componentes

| Componente | Porta | Função | Configuração |
|------------|-------|--------|--------------|
| **OTEL Collector** | 4317 | Recebe traces OTLP, processa e exporta | `observability/otel-collector-config.yml` |
| **Promtail** | 9080 | Coleta logs Docker, extrai metadata | `observability/promtail.yml` |
| **Prometheus** | 9090 | Armazena métricas, scrape endpoints | `observability/prometheus.yml` |
| **Tempo** | 3200 | Armazena traces distribuídos | `observability/tempo.yml` |
| **Loki** | 3100 | Armazena logs com structured metadata | `observability/loki.yml` |
| **Grafana** | 3000 | Visualização e correlação | `observability/grafana/` |

## Fluxo de um Request

```
1. Request HTTP chega
        │
        ▼
2. Plug.RequestId gera request_id=abc123
        │
        ▼
3. OpenTelemetry cria span
   • trace_id = 5e8f3a2b...
   • span_id  = 3f1c9d4e...
        │
        ▼
4. RequestLogger emite log:
   {"message": "GET /campaigns - 200 in 45ms",
    "trace_id": "5e8f3a2b...",
    "span_id": "3f1c9d4e...",
    "request_id": "abc123"}
        │
        ├──────────────────────────────────────────┐
        │                                          │
        ▼                                          ▼
5a. Trace enviado via OTLP          5b. Log capturado pelo Docker
        │                                          │
        ▼                                          ▼
6a. OTEL Collector                   6b. Promtail extrai trace_id
    processa e envia                     como structured metadata
        │                                          │
        ▼                                          ▼
7a. Tempo armazena trace             7b. Loki armazena log
        │                                          │
        └──────────────┬───────────────────────────┘
                       │
                       ▼
8. Grafana correlaciona via trace_id
   • Métrica → Trace (exemplars)
   • Trace → Logs (derived fields)
   • Log → Trace (clickable link)
```

## Correlação entre Sinais

A correlação funciona porque **todos os sinais compartilham o `trace_id`**:

### Log → Trace
Promtail extrai `trace_id` do log JSON e armazena como structured metadata. No Grafana/Loki, o trace_id vira um link clicável para o Tempo.

### Trace → Log
Configurado em `datasources.yml`:
```yaml
tracesToLogs:
  datasourceUid: loki
  filterByTraceID: true
  customQuery: true
  query: '{job="campaigns_api"} |= "trace_id=$${__trace.traceId}"'
```

### Métrica → Trace
Prometheus armazena exemplars com `trace_id`. Ao clicar em um ponto no gráfico, navega para o trace correspondente no Tempo.

## Configuração da Aplicação

### Dependencies (mix.exs)
```elixir
{:opentelemetry, "~> 1.4"},
{:opentelemetry_exporter, "~> 1.7"},
{:opentelemetry_phoenix, "~> 1.2"},
{:opentelemetry_ecto, "~> 1.2"},
{:opentelemetry_logger_metadata, "~> 0.1"},
{:prom_ex, "~> 1.10"}
```

### Startup (application.ex)
```elixir
# Primeiro: attach trace context aos logs
:ok = OpentelemetryLoggerMetadata.setup()

# Instrumentação
OpentelemetryPhoenix.setup()
OpentelemetryEcto.setup([:campaigns_api, :repo])
```

### Variáveis de Ambiente
```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
```

## Métricas Expostas

### PromEx (via /metrics)
- **Phoenix**: latência, status codes, throughput
- **Ecto**: query duration (total, queue, execute, decode, idle)
- **BEAM**: memory, processes, schedulers, run queue
- **LiveView**: connections, eventos

### Prometheus Scrape Targets
- `campaigns-api:4000/metrics` - App metrics
- `postgres-exporter:9187` - PostgreSQL metrics
- `rabbitmq:15692` - RabbitMQ metrics
- `otel-collector:8889` - Collector metrics

## Debugging

### Verificar se logs chegam no Loki
```bash
curl -G "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="campaigns_api"}' | jq
```

### Verificar se traces chegam no Tempo
```bash
curl "http://localhost:3200/api/search" | jq
```

### Health Check de todos os serviços
```bash
./observability/check-health.sh
```

### Logs dos componentes
```bash
docker compose logs -f otel-collector
docker compose logs -f promtail
docker compose logs -f loki
docker compose logs -f tempo
```

## Acessos

| Serviço | URL |
|---------|-----|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| Loki | http://localhost:3100 |
| Tempo | http://localhost:3200 |
| App Metrics | http://localhost:4000/metrics |

## Troubleshooting

| Problema | Verificar |
|----------|-----------|
| Logs não aparecem no Grafana | Promtail rodando? `docker compose logs promtail` |
| Traces não aparecem | OTEL Collector recebendo? `docker compose logs otel-collector` |
| Métricas zeradas | Prometheus scraping? http://localhost:9090/targets |
| Correlação não funciona | trace_id presente nos logs? Checar formato JSON |
| Grafana sem dados | Datasources configurados? Connections → Data Sources → Test |
