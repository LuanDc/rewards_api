#!/usr/bin/env bash

set -euo pipefail

COMPOSE_FILE="docker-compose.dev.yml"

echo "[setup] Starting required containers..."
docker compose -f "$COMPOSE_FILE" up -d postgres_db rabbitmq campaigns_api challenges_scheduler

echo "[setup] Running ecto.setup for campaigns_api..."
docker compose -f "$COMPOSE_FILE" exec -T campaigns_api sh -lc "cd /workspace/campaigns_api && MIX_ENV=dev mix ecto.setup"

echo "[setup] Running ecto.setup for challenges_scheduler..."
docker compose -f "$COMPOSE_FILE" exec -T challenges_scheduler sh -lc "cd /workspace/challenges_scheduler && MIX_ENV=dev mix ecto.setup"

echo "[setup] Databases are ready."