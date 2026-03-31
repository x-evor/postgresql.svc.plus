# Changelog

## Milestone 1: MVP (Completed)

- Use default Redis port (#98) and establish PostgreSQL & Redis baseline.
- Stream RAG sync progress for GitHub repository synchronization (#100).
- Add client-side Markdown parsing to the CLI (#104).
- Refactor RAG ingestion into the CLI with a server upsert endpoint (#103).
- Perform RAG API functional tests and support per-file ingestion workflow in the CLI (#115).
- Allow RAG upsert to migrate embedding dimensions (#119) and document pgvector database initialization (#120).
- Ingest files automatically (#123).

## Milestone 2: Hybrid Search (In Progress)
- Rename RAG 第二阶段优化规划为 `docs/Milestone-2.md` 并新增子任务列表。
- AskAI 接口与 CLI 规划使用 LangChainGo 框架以支持多模型与链式调用。
- Document local and Chutes model configurations for AskAI.
- CLI and server dynamically support 1024-dimensional embeddings.
- Update docs and configs to vector(1024) (#130).
- Add embedding configuration fields (#131).
- Add RAG API integration tests for vectors (#132).
- Add allama support (#136).
- Deploy homepage via rsync from CI and fix SSH directory creation (#18, #19).
- Deploy XControl panel via GitHub Actions (#20).
- Fix yarn lock context concatenation (#21).

## Milestone 3: Production Monitoring & Optimization

- Switch server and CLI to Cobra (#133).
- Add repo sync proxy configuration (#135).
- Allow custom AskAI timeout (#141).
- Add log level support to CLI and server and log AskAI errors (#125, #140).
- Continue performance optimization, error handling, multi-model support, permission control, hot reload, and improve RAG upsert docs (#129).
- Enhance chunking and embedding with TOC and heading vectors, paragraph-based multi-size chunks, summaries, and deduplication.

