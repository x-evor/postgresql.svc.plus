# Vibe Coding Reference

This repository packages a PostgreSQL-based runtime with operational hardening, deployment guidance, and extension-specific documentation.

Use this page to align AI-assisted coding prompts, repo boundaries, safe edit rules, and documentation update expectations.

## Current code-aligned notes

- Documentation target: `postgresql.svc.plus`
- Repo kind: `db-service`
- Manifest and build evidence: repository structure and scripts only
- Primary implementation and ops directories: `deploy/`, `scripts/`, `tests/`, `example/`, `workflows/`
- Package scripts snapshot: No package.json scripts were detected.

## Existing docs to reconcile

- `api/auth.md`
- `api/endpoints.md`
- `api/errors.md`
- `api/overview.md`
- `integrations/mcp-ssh-manager-setup.md`
- `mcp-ssh-manager-setup.md`

## What this page should cover next

- Describe the current implementation rather than an aspirational future-only design.
- Keep terminology aligned with the repository root README, manifests, and actual directories.
- Link deeper runbooks, specs, or subsystem notes from the legacy docs listed above.
- Review prompt templates and repo rules whenever the project adds new subsystems, protected areas, or mandatory verification steps.
