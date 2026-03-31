# Deployment

This repository packages a PostgreSQL-based runtime with operational hardening, deployment guidance, and extension-specific documentation.

Use this page to standardize deployment prerequisites, supported topologies, operational checks, and rollback notes.

## Current code-aligned notes

- Documentation target: `postgresql.svc.plus`
- Repo kind: `db-service`
- Manifest and build evidence: repository structure and scripts only
- Primary implementation and ops directories: `deploy/`, `scripts/`, `tests/`, `example/`, `workflows/`
- Package scripts snapshot: No package.json scripts were detected.

## Existing docs to reconcile

- `QUICKSTART.md`
- `deployments/docker-compose.md`
- `deployments/helm-chart.md`
- `development/dev-setup.md`
- `getting-started/installation.md`
- `getting-started/quickstart.md`
- `governance/release-process.md`
- `integrations/mcp-ssh-manager-setup.md`

## What this page should cover next

- Describe the current implementation rather than an aspirational future-only design.
- Keep terminology aligned with the repository root README, manifests, and actual directories.
- Link deeper runbooks, specs, or subsystem notes from the legacy docs listed above.
- Verify deployment steps against current scripts, manifests, CI/CD flow, and environment contracts before each release.
