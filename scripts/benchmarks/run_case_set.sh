#!/usr/bin/env bash
set -euo pipefail

# Automated benchmark case set:
# 1) Load deploy/docker/.env
# 2) Verify local endpoint listens on 127.0.0.1:15432
# 3) Run make benchmarks
# 4) Append output row to docs/benchmarks.md

ENV_FILE="${ENV_FILE:-deploy/docker/.env}"
PGHOST="${PGHOST:-127.0.0.1}"
PGPORT="${PGPORT:-15432}"
WAIT_SECONDS="${WAIT_SECONDS:-30}"
SLEEP_SECONDS="${SLEEP_SECONDS:-1}"

fail() {
  echo "❌ $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

[[ -f "$ENV_FILE" ]] || fail "Missing env file: $ENV_FILE"

POSTGRES_USER="$(grep -E '^POSTGRES_USER=' "$ENV_FILE" | tail -n1 | cut -d= -f2-)"
POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE" | tail -n1 | cut -d= -f2-)"
POSTGRES_DB="$(grep -E '^POSTGRES_DB=' "$ENV_FILE" | tail -n1 | cut -d= -f2-)"

[[ -n "$POSTGRES_PASSWORD" ]] || fail "POSTGRES_PASSWORD not found in $ENV_FILE"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

check_ready() {
  if need_cmd pg_isready; then
    PGPASSWORD="$POSTGRES_PASSWORD" \
    pg_isready -h "$PGHOST" -p "$PGPORT" -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1
    return $?
  fi
  if need_cmd nc; then
    nc -z "$PGHOST" "$PGPORT" >/dev/null 2>&1
    return $?
  fi
  if need_cmd lsof; then
    lsof -iTCP:"$PGPORT" -sTCP:LISTEN >/dev/null 2>&1
    return $?
  fi
  fail "Missing tools to verify port (pg_isready, nc, or lsof)"
}

deadline=$((WAIT_SECONDS / SLEEP_SECONDS))
attempt=0
until check_ready; do
  attempt=$((attempt + 1))
  if (( attempt >= deadline )); then
    fail "Cannot connect to ${PGHOST}:${PGPORT} after ${WAIT_SECONDS}s. Ensure the local tunnel or PostgreSQL is running."
  fi
  sleep "$SLEEP_SECONDS"
done

OUT_FILE="$(mktemp -t pgbench-output.XXXXXX)"
trap 'rm -f "$OUT_FILE"' EXIT

PGPASSWORD="$POSTGRES_PASSWORD" \
PGHOST="$PGHOST" PGPORT="$PGPORT" \
PGUSER="$POSTGRES_USER" PGDATABASE="$POSTGRES_DB" \
make benchmarks 2>&1 | tee "$OUT_FILE"

# Parse output and update docs/benchmarks.md
export OUT_FILE_PATH="$OUT_FILE"
python3 - <<'PY'
import re
from datetime import datetime
from pathlib import Path

# Hack: read OUT_FILE path from env passed in via shell
out_path = Path(__import__('os').environ.get('OUT_FILE_PATH', ''))
if not out_path.is_file():
    raise SystemExit(f"Missing output file: {out_path}")
text = out_path.read_text(encoding='utf-8', errors='replace')

def find_val(pattern, cast=None):
    m = re.search(pattern, text, re.M)
    if not m:
        return ''
    val = m.group(1).strip()
    return cast(val) if cast else val

mode = "TPC-B (mixed)"
scale = find_val(r'^scaling factor:\s*(\d+)$')
clients = find_val(r'^number of clients:\s*(\d+)$')
threads = find_val(r'^number of threads:\s*(\d+)$')
duration = find_val(r'^duration:\s*(\d+)\s*s$')
transactions = find_val(r'^number of transactions actually processed:\s*(\d+)$')
lat_avg = find_val(r'^latency average\s*=\s*([0-9.]+)\s*ms$')
init_conn = find_val(r'^initial connection time\s*=\s*([0-9.]+)\s*ms$')
tps = find_val(r'^tps\s*=\s*([0-9.]+)\s*\(without initial connection time\)$')

date = datetime.now().strftime('%Y-%m-%d')
row = f"| {date} | {mode} | {scale} | {clients} | {threads} | {duration} | {transactions} | {tps} | {lat_avg} | {init_conn} |"

bench_path = Path('docs/benchmarks.md')
content = bench_path.read_text(encoding='utf-8')
lines = content.splitlines()

header_idx = None
sep_idx = None
for i, line in enumerate(lines):
    if line.strip().startswith('| Date |'):
        header_idx = i
        break

if header_idx is None:
    raise SystemExit('Benchmark table header not found in docs/benchmarks.md')

for i in range(header_idx + 1, len(lines)):
    if re.match(r'^\|[- ]+\|', lines[i]):
        sep_idx = i
        break

if sep_idx is None:
    raise SystemExit('Benchmark table separator not found in docs/benchmarks.md')

# Insert new row after separator line
lines.insert(sep_idx + 1, row)
bench_path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
