# Documentation Maintainer Skill

## Purpose (Scope)
This skill defines how the AI maintains documentation under `docs/` **without** changing its structure. It exists to keep `docs/` accurate and consistent with the current repository while following `docs/schema.md` as the only source of truth for allowed files and layout.

## Out of Scope
- Creating, deleting, renaming, or moving files in `docs/`
- Writing product marketing content or future plans
- Modifying code or non-documentation files
- Inferring features not present in the repository

## Inputs
- User request describing what docs need updating or clarifying
- Repository files that provide evidence for documentation changes
- `docs/schema.md` (structure constraint)

## Outputs
- Updated Markdown content **only** in user-specified documentation files
- A short report of what was changed and which sources in the repo were used
- If blocked: a clear statement of missing information and what evidence is needed

## Workflow
1. **Confirm constraints**
   - Read `docs/schema.md` and treat it as immutable structure.
   - Identify which doc files the user explicitly asked to change.

2. **Collect evidence**
   - Locate relevant code/config files using repository search.
   - Do not use external sources.

3. **Draft minimal changes**
   - Update only the user-specified doc files.
   - Keep changes minimal and strictly factual.

4. **Verify consistency**
   - Ensure every new statement can be traced to the repo.
   - Check that the doc structure matches `docs/schema.md`.

5. **Deliver**
   - Provide a brief change summary and cite repo file paths used as evidence.
   - If information is insufficient, stop and request the missing sources.

## Hard Rules (Must Not Do)
- Do not modify `docs/` structure (no add/delete/rename/move).
- Do not create files not listed in `docs/schema.md`.
- Do not edit docs files the user did not explicitly specify.
- Do not invent or extrapolate features, APIs, or behavior.
- Do not use or reference external systems/tools not present in the repo.
- Do not change code or non-doc files.
