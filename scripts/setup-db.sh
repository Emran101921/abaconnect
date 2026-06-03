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
cp -n .env.example .env 2>/dev/null || true
npx prisma migrate deploy
npx prisma db seed
echo "Database ready."
