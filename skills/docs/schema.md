# Docs Structure Source

The documentation structure is defined **only** by `docs/schema.md` in the repository root. This skill does not redefine or override that schema.

Rules:

- Treat `docs/schema.md` as immutable.
- Do not add, remove, rename, or move files under `docs/`.
- Do not create documentation files that are not listed in `docs/schema.md`.

这是唯一合法的文档结构来源。不得新增、删除、重命名任何目录或文件。

docs/
├─ README.md
├─ getting-started/
│  ├─ introduction.md
│  ├─ quickstart.md
│  ├─ installation.md
│  └─ concepts.md
├─ architecture/
│  ├─ overview.md
│  ├─ components.md
│  ├─ design-decisions.md
│  └─ roadmap.md
├─ usage/
│  ├─ cli.md
│  ├─ config.md
│  ├─ deployment.md
│  └─ examples.md
├─ api/
│  ├─ overview.md
│  ├─ auth.md
│  ├─ endpoints.md
│  └─ errors.md
├─ integrations/
│  ├─ databases.md
│  ├─ cloud.md
│  └─ ai-providers.md
├─ advanced/
│  ├─ performance.md
│  ├─ security.md
│  ├─ scalability.md
│  └─ customization.md
├─ development/
│  ├─ contributing.md
│  ├─ dev-setup.md
│  ├─ testing.md
│  └─ code-structure.md
├─ operations/
│  ├─ logging.md
│  ├─ monitoring.md
│  ├─ backup.md
│  └─ troubleshooting.md
├─ governance/
│  ├─ license.md
│  ├─ security-policy.md
│  └─ release-process.md
└─ appendix/
   ├─ faq.md
   ├─ glossary.md
   └─ references.md
