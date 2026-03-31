#!/usr/bin/env bash
#
# scripts/import_schema_clean.sh
# ---------------------------------------------
# Import a cleaned schema.sql file into PostgreSQL.
# Safe for re-run (幂等导入)
# ---------------------------------------------

set -euo pipefail

# ====== Configuration ======
DB_URL=${1:-"postgres://shenlan:password@127.0.0.1:5432/account?sslmode=disable"}
IN_FILE=${2:-"/tmp/schema_clean.sql"}

# ====== Validation ======
if [ ! -f "$IN_FILE" ]; then
  echo "❌ File not found: $IN_FILE"
  echo "💡 请先运行 export_schema_clean.sh 导出 schema"
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "❌ 未检测到 psql，请先安装 PostgreSQL 客户端"
  exit 1
fi

# ====== Import schema ======
echo ">>> Importing schema into database"
echo "---------------------------------------------"
echo "Database:  $DB_URL"
echo "Schema:    $IN_FILE"
echo "---------------------------------------------"

psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$IN_FILE"

echo ""
echo "✅ Schema import completed successfully"
echo "---------------------------------------------"

