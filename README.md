# Campaigns API

API para gerenciamento de campanhas de recompensas e fidelidade. Permite criar, gerenciar e associar critérios de recompensas a campanhas de marketing/engajamento.

## Sumário

- [Visão Geral](#visão-geral)
- [Tecnologias](#tecnologias)
- [Instalação](#instalação)
- [API Endpoints](#api-endpoints)
- [Banco de Dados](#banco-de-dados)
- [Observabilidade](#observabilidade)
- [Comandos Úteis](#comandos-úteis)

---

## Visão Geral

Microserviço em Elixir/Phoenix para sistema de recompensas com:

- **Gerenciamento de Campanhas**: CRUD + iniciar/finalizar campanhas
- **Critérios de Recompensa**: Ações que usuários cumprem para ganhar pontos
- **Multi-tenancy**: Isolamento de dados por tenant via JWT/Keycloak

### Fluxo Básico

```
1. Admin cria critérios (ex: "Login Diário", "Primeira Compra")
2. Admin cria campanha e associa critérios com pontos
3. Admin inicia a campanha
4. Usuários cumprem critérios e ganham pontos
5. Admin finaliza a campanha
```

---

## Tecnologias

| Tecnologia | Propósito |
|------------|-----------|
| Elixir 1.14+ / Phoenix 1.7 | Framework web |
| PostgreSQL 16 / Ecto | Banco de dados |
| Keycloak / Joken | Autenticação JWT |
| OpenTelemetry | Distributed tracing |
| PromEx / Grafana | Métricas e dashboards |

---

## Instalação

### Variáveis de Ambiente

```bash
DATABASE_URL=ecto://postgres:postgres@localhost/campaigns_api_dev
KEYCLOAK_JWKS_URL=http://localhost:8080/realms/rewards/protocol/openid-connect/certs
SECRET_KEY_BASE=<gerar com: mix phx.gen.secret>
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

### Com Docker (Recomendado)

```bash
# Na raiz do projeto (rewards_api/)
docker-compose up -d

# Serviços disponíveis:
# - API:      http://localhost:4000
# - Keycloak: http://localhost:8080 (admin/admin)
# - Grafana:  http://localhost:3000 (admin/admin)
```

### Local (sem Docker)

```bash
cd campaigns_api
mix deps.get
mix ecto.setup          # Cria banco, migra e popula seeds
mix phx.server          # http://localhost:4000
```

---

## API Endpoints

Todos requerem `Authorization: Bearer <JWT>` (exceto `/metrics`).

### Campanhas

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/api/campaigns` | Lista campanhas do tenant |
| `POST` | `/api/campaigns` | Cria campanha |
| `GET` | `/api/campaigns/:id` | Detalhes |
| `PATCH` | `/api/campaigns/:id` | Atualiza |
| `DELETE` | `/api/campaigns/:id` | Remove |
| `POST` | `/api/campaigns/:id/start` | Inicia |
| `POST` | `/api/campaigns/:id/finish` | Finaliza |

### Critérios da Campanha

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| `GET` | `/api/campaigns/:id/criteria` | Lista critérios |
| `POST` | `/api/campaigns/:id/criteria` | Associa critério |
| `PATCH` | `/api/campaigns/:id/criteria/:cid` | Atualiza |
| `DELETE` | `/api/campaigns/:id/criteria/:cid` | Remove |

### Exemplo

```bash
# Criar campanha
curl -X POST http://localhost:4000/api/campaigns \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"campaign": {"name": "Black Friday 2024"}}'

# Associar critério com 100 pontos
curl -X POST http://localhost:4000/api/campaigns/$ID/criteria \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"campaign_criterion": {"criterion_id": "uuid", "reward_points_amount": 100}}'
```

---

## Banco de Dados

### Modelo

```
campaigns              campaign_criteria         criteria
─────────────          ─────────────────         ────────
id (PK)          ┌──── campaign_id (FK)    ┌─── id (PK)
name             │     criterion_id (FK) ──┘    name (UNIQUE)
tenant           │     reward_points_amount     status
status ──────────┘     periodicity              description
started_at             status
finished_at
```

### Status de Campanha

`not_started` → `active` → `completed` | `paused` | `cancelled`

### Critérios Pré-definidos (seeds)

Daily Login, First Purchase, Friend Referral, Profile Completion, Newsletter Subscription, Social Media Share, Review Submission, Birthday Reward, Loyalty Milestone, App Download, Feedback Survey, Repeat Purchase

---

## Observabilidade

```
App ──► OTel Collector ──► Tempo (traces)
 │
 ├──► Promtail ──► Loki (logs)
 │
 └──► Prometheus ──► Grafana (métricas)
```

- **Métricas**: `/metrics` (Prometheus format)
- **Dashboards**: http://localhost:3000 (Grafana)
- **Traces**: Correlação automática com logs via trace_id

---

## Comandos Úteis

```bash
# Desenvolvimento
mix phx.server              # Inicia servidor
iex -S mix phx.server       # Com console interativo
mix test                    # Testes
mix coveralls.html          # Cobertura (cover/excoveralls.html)
mix credo                   # Análise estática
mix format                  # Formatar código

# Banco de dados
mix ecto.migrate            # Aplicar migrações
mix ecto.rollback           # Reverter última
mix ecto.reset              # Resetar banco

# Docker
docker-compose up -d                    # Subir stack
docker-compose logs -f campaigns-api    # Ver logs
docker-compose down -v                  # Parar e limpar
```

---

## Links

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Elixir Lang](https://elixir-lang.org/)
- [Ecto](https://hexdocs.pm/ecto/Ecto.html)
