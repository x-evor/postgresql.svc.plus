# Design

This repository packages a PostgreSQL-based runtime with operational hardening, deployment guidance, and extension-specific documentation.

Use this page to consolidate design decisions, ADR-style tradeoffs, and roadmap-sensitive implementation notes.

## Current code-aligned notes

- Documentation target: `postgresql.svc.plus`
- Repo kind: `db-service`
- Manifest and build evidence: repository structure and scripts only
- Primary implementation and ops directories: `deploy/`, `scripts/`, `tests/`, `example/`, `workflows/`
- Package scripts snapshot: No package.json scripts were detected.

## Existing docs to reconcile

- `SUMMARY.md`
- `architecture/design-decisions.md`
- `integrations/xcloudflow-state-db.md`

## What this page should cover next

- Describe the current implementation rather than an aspirational future-only design.
- Keep terminology aligned with the repository root README, manifests, and actual directories.
- Link deeper runbooks, specs, or subsystem notes from the legacy docs listed above.
- Promote one-off implementation notes into reusable design records when behavior, APIs, or deployment contracts change.
