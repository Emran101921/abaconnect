#!/usr/bin/env bash
# Start Postgres/Redis (Docker) and the Nest API for local Flutter development.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER="${DOCKER:-/Applications/Docker.app/Contents/Resources/bin/docker}"

if [[ -x "$DOCKER" ]]; then
  "$DOCKER" compose -f "$ROOT/docker-compose.yml" up -d postgres redis
else
  echo "Docker not found. Start Postgres (5432) and Redis (6379) manually."
fi

cd "$ROOT/api"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created api/.env from .env.example"
fi

echo "Waiting for API..."
if ! pgrep -f "nest start" >/dev/null 2>&1; then
  npm run start:dev &
  API_PID=$!
fi

for i in $(seq 1 30); do
  if curl -sf http://localhost:3000/api/v1/health >/dev/null 2>&1; then
    echo "API ready: http://localhost:3000/api/v1"
    echo "GraphQL:    http://localhost:3000/graphql"
    echo "iOS sim:    http://localhost:3000"
    echo "Android emu: http://10.0.2.2:3000"
    exit 0
  fi
  sleep 2
done

echo "API did not become ready in time. Check api logs."
exit 1
