# 架构

该仓库提供基于 PostgreSQL 的运行时分发，重点是部署加固、运维说明与扩展能力文档。

本页作为系统边界、核心组件与仓库职责的双语总览入口。

## 与当前代码对齐的说明

- 文档目标仓库: `postgresql.svc.plus`
- 仓库类型: `db-service`
- 构建与运行依据: repository structure and scripts only
- 主要实现与运维目录: `deploy/`, `scripts/`, `tests/`, `example/`, `workflows/`
- `package.json` 脚本快照: No package.json scripts were detected.

## 需要继续归并的现有文档

- `ARCHITECTURE.md`
- `PROJECT_STRUCTURE.md`
- `api/overview.md`
- `architecture/components.md`
- `architecture/design-decisions.md`
- `architecture/overview.md`
- `architecture/roadmap.md`
- `development/code-structure.md`

## 本页下一步应补充的内容

- 先描述当前已落地实现，再补充未来规划，避免只写愿景不写现状。
- 术语需要与仓库根 README、构建清单和实际目录保持一致。
- 将上方列出的历史 runbook、spec、子系统说明逐步链接并归并到本页。
- 随着目录结构、服务关系和集成依赖变化，持续同步图示与职责说明。
