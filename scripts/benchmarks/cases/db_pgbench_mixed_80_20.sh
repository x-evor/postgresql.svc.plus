#!/usr/bin/env bash
set -euo pipefail

# Mixed read/write benchmark (80% read, 20% write)

PGUSER="${PGUSER:-${POSTGRES_USER:-postgres}}"
PGDATABASE="${PGDATABASE:-${POSTGRES_DB:-postgres}}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-15432}"

SCALE="${SCALE:-50}"
CONCURRENCY="${CONCURRENCY:-16}"
THREADS="${THREADS:-4}"
DURATION="${DURATION:-120}"
PROGRESS="${PROGRESS:-10}"
INIT="${INIT:-0}"

CUSTOM_SQL="${CUSTOM_SQL:-/tmp/pgbench_mixed_80_20.sql}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

run_pgbench() {
  pgbench -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$@"
}

need_cmd pgbench

if [[ "$INIT" == "1" ]]; then
  echo "[pgbench] init: scale=$SCALE user=$PGUSER db=$PGDATABASE"
  run_pgbench -i -s "$SCALE" "$PGDATABASE"
fi

echo "[pgbench] preparing script: $CUSTOM_SQL"
cat <<'SQL' > "$CUSTOM_SQL"
\set random_account random(1, 100000)
\set random_teller  random(1, 10)
\set random_branch  random(1, 1)
\set delta random(-5000, 5000)

-- 80% read
SELECT abalance FROM pgbench_accounts WHERE aid = :random_account;

-- 20% write
UPDATE pgbench_accounts
SET abalance = abalance + :delta
WHERE aid = :random_account;
SQL

echo "[pgbench] run: c=$CONCURRENCY j=$THREADS T=$DURATION P=$PROGRESS user=$PGUSER db=$PGDATABASE"
run_pgbench -c "$CONCURRENCY" -j "$THREADS" -T "$DURATION" -P "$PROGRESS" -r \
  -f "$CUSTOM_SQL" \
  "$PGDATABASE"
