#!/usr/bin/env bash
# Start Postgres/Redis (Docker), migrate, seed, and run API + Flutter web.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if command -v docker >/dev/null 2>&1; then
  "$ROOT/scripts/setup-db.sh"
else
  echo "Docker not found — ensure Postgres is running and DATABASE_URL is set in api/.env"
  echo "Then: cd api && npx prisma migrate deploy && npx prisma db seed"
fi

echo ""
echo "Starting API on http://localhost:3000 ..."
cd "$ROOT/api"
npm run start:dev &
API_PID=$!

trap 'kill $API_PID 2>/dev/null || true' EXIT

sleep 4
echo ""
echo "Starting Flutter web (Chrome)..."
export PATH="${PATH}:$HOME/development/flutter/bin"
cd "$ROOT/apps/mobile"
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1 \
  --dart-define=GRAPHQL_URL=http://localhost:3000/graphql
