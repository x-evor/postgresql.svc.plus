# 定制与扩展

## 初始化 SQL

- Docker：`deploy/docker/init-scripts/` 下的 SQL 会在初始化时执行。
- Helm：使用 `values.yaml` 的 `initScripts.scripts`。

## PostgreSQL 配置

- Docker：`deploy/docker/postgresql.conf`
- Helm：`values.yaml` → `postgresql.config`

## 扩展版本

- 版本由 `Makefile` 中的变量控制（构建镜像时生效）。
- 如需新增扩展，建议在镜像构建阶段安装并在初始化脚本中 `CREATE EXTENSION`。
