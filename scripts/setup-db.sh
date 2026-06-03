#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required. Install Docker Desktop, then re-run."
  exit 1
fi

cd "$ROOT"
docker compose up -d postgres redis
echo "Waiting for Postgres..."
sleep 5
cd api
if [[ ! -f .env ]] || grep -q 'prisma+postgres' .env 2>/dev/null; then
  cp .env.example .env
  echo "Wrote api/.env from .env.example (Docker Postgres)."
fi
npx prisma migrate deploy
npx prisma db seed
echo "Database ready."
