# Documentation Coverage Matrix

This matrix tracks the bilingual canonical documentation set for `postgresql.svc.plus` and maps it back to the current codebase and older docs.

该矩阵用于跟踪 `postgresql.svc.plus` 的双语规范文档，并将其与当前代码状态和历史文档对应起来。

| Category | EN | ZH | Current status | Existing references | Next check |
| --- | --- | --- | --- | --- | --- |
| Architecture | Yes | Yes | Seeded from current codebase and existing docs. | `ARCHITECTURE.md`<br>`PROJECT_STRUCTURE.md`<br>`api/overview.md`<br>`architecture/components.md`<br>`architecture/design-decisions.md`<br>`architecture/overview.md`<br>`architecture/roadmap.md`<br>`development/code-structure.md` | Keep diagrams and ownership notes synchronized with actual directories, services, and integration dependencies. |
| Design | Yes | Yes | Seeded from current codebase and existing docs. | `SUMMARY.md`<br>`architecture/design-decisions.md`<br>`integrations/xcloudflow-state-db.md` | Promote one-off implementation notes into reusable design records when behavior, APIs, or deployment contracts change. |
| Deployment | Yes | Yes | Seeded from current codebase and existing docs. | `QUICKSTART.md`<br>`deployments/docker-compose.md`<br>`deployments/helm-chart.md`<br>`development/dev-setup.md`<br>`getting-started/installation.md`<br>`getting-started/quickstart.md`<br>`governance/release-process.md`<br>`integrations/mcp-ssh-manager-setup.md` | Verify deployment steps against current scripts, manifests, CI/CD flow, and environment contracts before each release. |
| User Guide | Yes | Yes | Seeded from current codebase and existing docs. | `QUICKSTART.md`<br>`api/overview.md`<br>`architecture/overview.md`<br>`getting-started/concepts.md`<br>`getting-started/installation.md`<br>`getting-started/introduction.md`<br>`getting-started/quickstart.md`<br>`guides/CICD_QUICKREF.md` | Prefer workflow-oriented examples and keep screenshots or terminal snippets aligned with the latest UI or CLI behavior. |
| Developer Guide | Yes | Yes | Seeded from current codebase and existing docs. | `PROJECT_STRUCTURE.md`<br>`api/auth.md`<br>`api/endpoints.md`<br>`api/errors.md`<br>`api/overview.md`<br>`development/code-structure.md`<br>`development/contributing.md`<br>`development/dev-setup.md` | Keep setup and test commands tied to actual package scripts, Make targets, or language toolchains in this repository. |
| Vibe Coding Reference | Yes | Yes | Seeded from current codebase and existing docs. | `api/auth.md`<br>`api/endpoints.md`<br>`api/errors.md`<br>`api/overview.md`<br>`integrations/mcp-ssh-manager-setup.md`<br>`mcp-ssh-manager-setup.md` | Review prompt templates and repo rules whenever the project adds new subsystems, protected areas, or mandatory verification steps. |
