#!/bin/bash

# Script para verificar o status da stack de observabilidade

echo "🔍 Verificando stack de observabilidade..."
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}

    printf "%-20s " "$name:"

    if response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null); then
        if [ "$response" -eq "$expected_status" ] || [ "$response" -eq 200 ]; then
            echo -e "${GREEN}✓ OK${NC} (HTTP $response)"
        else
            echo -e "${YELLOW}⚠ WARNING${NC} (HTTP $response)"
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (não respondeu)"
    fi
}

echo "📊 Serviços de Backend:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Loki" "http://localhost:3100/ready"
check_service "Tempo" "http://localhost:3200/ready"
check_service "Grafana" "http://localhost:3000/api/health"
check_service "OTel Collector" "http://localhost:13133"
check_service "Postgres Exporter" "http://localhost:9187/metrics"

echo ""
echo "🔌 Aplicação:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_service "API" "http://localhost:4000"
check_service "PromEx Metrics" "http://localhost:4000/metrics"

echo ""
echo "📦 Containers Docker:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
containers=(
    "rewards_grafana"
    "rewards_prometheus"
    "rewards_tempo"
    "rewards_loki"
    "rewards_otel_collector"
    "rewards_postgres_exporter"
)

for container in "${containers[@]}"; do
    printf "%-30s " "$container:"
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$status" = "running" ]; then
            echo -e "${GREEN}✓ Running${NC}"
        else
            echo -e "${YELLOW}⚠ $status${NC}"
        fi
    else
        echo -e "${RED}✗ Not found${NC}"
    fi
done

echo ""
echo "📋 Próximos passos:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Grafana: http://localhost:3000"
echo "• Prometheus: http://localhost:9090"
echo "• Métricas da API: http://localhost:4000/metrics"
echo ""
echo "Para ver logs de um serviço:"
echo "  docker logs -f <container_name>"
echo ""
