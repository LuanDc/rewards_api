#!/usr/bin/env sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml -f infra/cdc/docker-compose.cdc.yml up -d debezium

echo "CDC stack started (requires Docker daemon running)."
