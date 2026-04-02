# XCloudFlow State Database Initialization

This document describes how to prepare a dedicated PostgreSQL database for XCloudFlow state, inventory, CMDB export, and operational metadata.

## Database Layout

Create a dedicated database:

```sql
CREATE DATABASE xcloudflow;
```

Within that database, XCloudFlow manages these schemas:

- `state`
- `inventory`
- `cmdb`
- `ops`
- `xcf` (existing XCloudFlow control-plane schema)

## Current Runtime Requirements

XCloudFlow MVP only requires standard PostgreSQL features plus the extensions already present in `postgresql.svc.plus`:

- `uuid-ossp` or equivalent UUID generation support
- JSONB

It does not require `ltree`, `pg_cron`, or `postgres_fdw` to start. Those remain recommended follow-up enhancements.

## Bootstrap Flow

From the `x-cloud-flow.svc.plus` repository:

```bash
go run ./cmd/xcloudflow db init --dsn "$DATABASE_URL"
```

This applies:

1. `sql/schema.sql`
2. all files in `sql/migrations/*.sql` in lexical order

## Recommended Follow-up Extensions

Priority 1:

- `pgcrypto`
- `ltree`
- `pg_cron`

Priority 2:

- `postgres_fdw`
- `pg_partman`

These are not required for the first working state backend, but they are recommended for stronger path indexing, scheduled drift scans, encryption, and federation.
