# Observability Stack - Quick Start

## Stack LGTM (Grafana Stack)

- **L**oki - Logs
- **G**rafana - Dashboards
- **T**empo - Traces
- **M**imir/Prometheus - Metrics

## Setup Rápido

```bash
# 1. Subir toda a stack
docker-compose up -d

# 2. Instalar dependências Elixir
cd campaigns_api && mix deps.get

# 3. Iniciar aplicação
mix phx.server
```

## URLs de Acesso

- **Grafana**: http://localhost:3000 (dashboards)
- **Prometheus**: http://localhost:9090 (métricas raw)
- **API Metrics**: http://localhost:4000/metrics (PromEx)

## Verificar Health

```bash
# Prometheus
curl http://localhost:9090/-/healthy

# Loki
curl http://localhost:3100/ready

# Tempo
curl http://localhost:3200/ready

# OTel Collector
curl http://localhost:13133
```

## Arquivos de Configuração

```
observability/
├── otel-collector-config.yml  # OpenTelemetry Collector
├── prometheus.yml             # Prometheus scrape configs
├── tempo.yml                  # Tempo tracing backend
├── loki.yml                   # Loki log aggregation
└── grafana/
    ├── datasources.yml        # Grafana datasources
    ├── dashboards.yml         # Dashboard provisioning
    └── dashboards/
        ├── elixir-beam-overview.json
        └── postgres-overview.json
```

## Parar Stack

```bash
# Parar todos os serviços
docker-compose down

# Parar e remover volumes (limpa dados)
docker-compose down -v
```

## Documentação Completa

Veja [OBSERVABILITY_SETUP.md](../OBSERVABILITY_SETUP.md) na raiz do projeto.
