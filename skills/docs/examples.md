# Examples

## Example 1: Update a specific doc file

Input:
- User: "Update `docs/usage/config.md` to match current config keys."

Expected behavior:
- Read `docs/schema.md`.
- Edit only `docs/usage/config.md`.
- Use evidence from `config/` and `internal/rag/config/`.

## Example 2: Insufficient information

Input:
- User: "Document the new streaming API."

Expected behavior:
- Search the repo for evidence of a streaming API.
- If not found, respond: missing implementation evidence; request the source file or clarify.

## Example 3: Schema constraint

Input:
- User: "Add a new doc at docs/how-to/streaming.md."

Expected behavior:
- Refuse, citing `docs/schema.md` as the only allowed structure.
- Ask the user to update schema first if needed.
