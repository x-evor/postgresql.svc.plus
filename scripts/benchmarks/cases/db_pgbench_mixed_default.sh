#!/usr/bin/env bash
set -euo pipefail

# Mixed read/write benchmark (pgbench default TPC-B-like workload)

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

echo "[pgbench] run: c=$CONCURRENCY j=$THREADS T=$DURATION P=$PROGRESS user=$PGUSER db=$PGDATABASE"
run_pgbench -c "$CONCURRENCY" -j "$THREADS" -T "$DURATION" -P "$PROGRESS" -r \
  "$PGDATABASE"
