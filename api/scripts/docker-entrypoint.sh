#!/bin/sh
set -e
if [ -z "$DATABASE_URL" ]; then
  echo "DATABASE_URL must be set for migrations"
  exit 1
fi
export DATABASE_URL
echo "Running database migrations..."
npx prisma migrate deploy
echo "Starting API..."
exec node dist/src/main.js
