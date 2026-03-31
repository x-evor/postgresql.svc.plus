# Benchmarks (Cases)

Run cases from `scripts/benchmarks/cases`.

Examples:

```bash
# Install pgbench (macOS/Linux)
scripts/benchmarks/install_pgbench.sh

# Run automated case set (env + stunnel + benchmarks + docs output)
scripts/benchmarks/run_case_set.sh

# Init data once, then run default mixed workload
INIT=1 scripts/benchmarks/cases/db_pgbench_mixed_default.sh

# Run 80/20 mixed workload with custom parameters
SCALE=100 CONCURRENCY=32 THREADS=8 DURATION=180 \
  scripts/benchmarks/cases/db_pgbench_mixed_80_20.sh
```

Common env vars:
- `PGHOST` (default: `127.0.0.1`)
- `PGPORT` (default: `5432`)
- `PGUSER`, `PGDATABASE`
- `SCALE`, `CONCURRENCY`, `THREADS`, `DURATION`, `PROGRESS`, `INIT`
