#!/usr/bin/env bash
# Build and run the production Docker stack (Postgres, Redis, API with migrations).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required for deploy."
  exit 1
fi

if [ ! -f api/.env ]; then
  echo "Creating api/.env from api/.env.example — set JWT_SECRET and keys before real production."
  cp api/.env.example api/.env
fi

# Match password used by docker-compose.yml dev Postgres volume when present.
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-abaconnect_dev}"
export APP_URL="${APP_URL:-http://localhost:3000}"

echo "Building and starting production stack..."
docker compose -f docker-compose.prod.yml up -d --build

echo "Waiting for API health..."
for i in $(seq 1 40); do
  if curl -sf "${APP_URL}/api/v1/health" >/dev/null 2>&1; then
    echo "API is up: ${APP_URL}/api/v1/health"
    curl -sf "${APP_URL}/api/v1/health" | head -c 200
    echo ""
    exit 0
  fi
  sleep 2
done

echo "API did not become healthy in time. Logs:"
docker compose -f docker-compose.prod.yml logs api --tail 80
exit 1
