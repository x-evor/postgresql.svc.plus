# Architecture

This repository packages a PostgreSQL-based runtime with operational hardening, deployment guidance, and extension-specific documentation.

Use this page as the canonical bilingual overview of system boundaries, major components, and repo ownership.

## Current code-aligned notes

- Documentation target: `postgresql.svc.plus`
- Repo kind: `db-service`
- Manifest and build evidence: repository structure and scripts only
- Primary implementation and ops directories: `deploy/`, `scripts/`, `tests/`, `example/`, `workflows/`
- Package scripts snapshot: No package.json scripts were detected.

## Existing docs to reconcile

- `ARCHITECTURE.md`
- `PROJECT_STRUCTURE.md`
- `api/overview.md`
- `architecture/components.md`
- `architecture/design-decisions.md`
- `architecture/overview.md`
- `architecture/roadmap.md`
- `development/code-structure.md`

## What this page should cover next

- Describe the current implementation rather than an aspirational future-only design.
- Keep terminology aligned with the repository root README, manifests, and actual directories.
- Link deeper runbooks, specs, or subsystem notes from the legacy docs listed above.
- Keep diagrams and ownership notes synchronized with actual directories, services, and integration dependencies.
