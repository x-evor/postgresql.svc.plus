#!/usr/bin/env bash
set -euo pipefail

DB_URL="postgres://shenlan:password@127.0.0.1:5432/account?sslmode=disable"
OUT="/tmp/schema_clean.sql"

echo ">>> Exporting clean schema (PostgreSQL 16 compatible)"
pg_dump \
  --schema-only \
  --no-owner \
  --no-privileges \
  --exclude-schema=pglogical \
  "$DB_URL" \
| grep -v -i "EXTENSION pglogical" \
| grep -v -i "COMMENT ON EXTENSION pglogical" \
| grep -v -i "SCHEMA pglogical" \
> "$OUT"

echo "✅ Schema exported to $OUT"
grep -i pglogical "$OUT" || echo "✅ pglogical completely removed"

