# Developer Guide

This repository packages a PostgreSQL-based runtime with operational hardening, deployment guidance, and extension-specific documentation.

Use this page to document local setup, project structure, test surfaces, and contribution conventions tied to the current codebase.

## Current code-aligned notes

- Documentation target: `postgresql.svc.plus`
- Repo kind: `db-service`
- Manifest and build evidence: repository structure and scripts only
- Primary implementation and ops directories: `deploy/`, `scripts/`, `tests/`, `example/`, `workflows/`
- Package scripts snapshot: No package.json scripts were detected.

## Existing docs to reconcile

- `PROJECT_STRUCTURE.md`
- `api/auth.md`
- `api/endpoints.md`
- `api/errors.md`
- `api/overview.md`
- `development/code-structure.md`
- `development/contributing.md`
- `development/dev-setup.md`

## What this page should cover next

- Describe the current implementation rather than an aspirational future-only design.
- Keep terminology aligned with the repository root README, manifests, and actual directories.
- Link deeper runbooks, specs, or subsystem notes from the legacy docs listed above.
- Keep setup and test commands tied to actual package scripts, Make targets, or language toolchains in this repository.
