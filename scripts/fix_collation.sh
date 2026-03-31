#!/usr/bin/env bash
# scripts/fix_collation.sh
# Fix PostgreSQL collation version mismatch for existing databases

set -e

CONTAINER_NAME="postgresql-svc-plus"
DB_USER="postgres"

echo "🔧 Fixing collation version mismatch..."

if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "❌ Container $CONTAINER_NAME is not running."
    exit 1
fi

# Fix 'postgres' DB
echo "👉 Fixing database: postgres"
docker exec -it "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "ALTER DATABASE postgres REFRESH COLLATION VERSION;" || true

# Fix 'template1' DB
echo "👉 Fixing database: template1"
docker exec -it "$CONTAINER_NAME" psql -U "$DB_USER" -d template1 -c "ALTER DATABASE template1 REFRESH COLLATION VERSION;" || true

echo "✅ Collation fix complete."
