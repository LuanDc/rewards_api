# Quick Start - Observabilidade

## 🚀 Iniciar em 3 passos

```bash
# 1. Subir stack completa
docker-compose up -d

# 2. Instalar dependências e iniciar app
cd campaigns_api
mix deps.get
mix phx.server

# 3. Abrir Grafana
open http://localhost:3000
```

## 📊 O que você tem agora?

### ✅ Métricas (PromEx + Prometheus)
- **URL**: http://localhost:4000/metrics
- **O que monitora**: BEAM VM, Phoenix, Ecto, PostgreSQL
- **Visualizar**: Grafana → Dashboards → "Elixir BEAM Overview"

### ✅ Traces (OpenTelemetry + Tempo)
- **O que faz**: Rastreamento distribuído de requisições
- **Visualizar**: Grafana → Explore → Tempo
- **Query exemplo**: `{service.name="campaigns_api"}`

### ✅ Logs (Loki)
- **O que faz**: Agregação de logs com correlação de traces
- **Visualizar**: Grafana → Explore → Loki
- **Query exemplo**: `{service_name="campaigns_api"} |= "error"`

### ✅ Dashboards Prontos
- Elixir BEAM Overview (CPU, memória, processos)
- PostgreSQL Overview (conexões, queries, cache)
- Phoenix (requisições, latência, throughput)
- Ecto (query performance, pool stats)

## 🔍 Verificar se está funcionando

```bash
# Script automático de health check
./observability/check-health.sh

# Ou manual:
curl http://localhost:4000/metrics  # Deve retornar métricas
curl http://localhost:9090/-/healthy  # Prometheus OK
curl http://localhost:3000/api/health  # Grafana OK
```

## 📈 Exemplo de uso

1. **Fazer requisições na API**:
   ```bash
   curl http://localhost:4000/api/campaigns
   ```

2. **Ver métricas no Grafana**:
   - Acesse http://localhost:3000
   - Dashboards → "Elixir BEAM Overview"
   - Veja requisições, latência, memória em tempo real

3. **Ver traces distribuídos**:
   - Grafana → Explore → Tempo
   - Query: `{service.name="campaigns_api"}`
   - Clique em um trace para ver detalhes

4. **Correlacionar logs com traces**:
   - Grafana → Explore → Loki
   - Encontre um log com `trace_id`
   - Clique no botão "Tempo" para ver o trace relacionado

## 🎯 Diferença: PromEx vs OpenTelemetry

### PromEx (Métricas)
```
❓ "Qual é a latência média?"
📊 Resposta: p95 = 250ms (agregado)
```

### OpenTelemetry (Traces)
```
❓ "Por que ESTA requisição específica demorou 2s?"
🔍 Resposta: Query X demorou 1.8s (detalhado)
```

### Usando juntos
1. PromEx detecta o problema (latência alta)
2. OpenTelemetry mostra a causa raiz (query lenta específica)
3. Loki mostra os logs relacionados ao trace

## 🛠️ Troubleshooting

**Métricas não aparecem?**
```bash
# Verificar se app está expondo
curl http://localhost:4000/metrics

# Ver logs do Prometheus
docker logs rewards_prometheus
```

**Traces não aparecem?**
```bash
# Verificar OTel Collector
curl http://localhost:13133

# Ver logs
docker logs rewards_otel_collector
```

**Dashboards vazios?**
- Aguarde 1-2 minutos após iniciar
- Faça algumas requisições na API
- Verifique se todos os serviços estão rodando: `./observability/check-health.sh`

## 📚 Documentação completa

- [OBSERVABILITY_SETUP.md](./OBSERVABILITY_SETUP.md) - Setup detalhado
- [observability/README.md](./observability/README.md) - Comandos úteis

## 🔥 Métricas de negócio customizadas

Para adicionar métricas específicas da sua aplicação, veja o exemplo em:
- [campaigns_api/lib/campaigns_api/prom_ex/business_metrics_plugin.ex](./campaigns_api/lib/campaigns_api/prom_ex/business_metrics_plugin.ex)

Ative o plugin adicionando em `lib/campaigns_api/prom_ex.ex`:

```elixir
def plugins do
  [
    # ... plugins existentes
    {CampaignsApi.PromEx.BusinessMetricsPlugin, []}
  ]
end
```

## 🎨 Próximos passos

1. ✅ Explorar dashboards pré-configurados
2. ✅ Criar alertas customizados
3. ✅ Adicionar métricas de negócio
4. ✅ Configurar retenção de dados
5. ✅ Integrar com Slack/PagerDuty para alertas

---

**Dúvidas?** Consulte a documentação completa em [OBSERVABILITY_SETUP.md](./OBSERVABILITY_SETUP.md)
