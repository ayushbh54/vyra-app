#!/usr/bin/env bash
# ==============================================================================
# VYRA DATABASE MIGRATION SCRIPT
# Runs all 12 SQL migrations in correct order against DATABASE_URL
# ==============================================================================
set -e

if [ -z "$DATABASE_URL" ]; then
  echo "Error: DATABASE_URL environment variable is not set."
  exit 1
fi

MIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/migrations"

echo "Applying migrations from: $MIG_DIR"
for file in "$MIG_DIR"/*.sql; do
  echo "==> Applying migration: $(basename "$file")"
  psql "$DATABASE_URL" -f "$file"
done

echo "All 12 migrations applied successfully!"
