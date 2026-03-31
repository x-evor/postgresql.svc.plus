# FAQ

## Q1: 为什么不用 PostgreSQL 自带 SSL？

A: 项目选择 stunnel 处理 TLS，使 PostgreSQL 专注于 SQL 处理，同时减少应用侧的 SSL 配置复杂度。

## Q2: stunnel 使用 443 端口是否必须？

A: 不是必须，但推荐。可在 `.env` 或 Helm 中修改 `STUNNEL_PORT`。

## Q3: Caddy/Nginx 是必须的吗？

A: 不是。它们主要用于证书管理与 Web 健康检查，与数据库 TLS 隧道相互独立。

## Q4: 默认提供哪些扩展？

A: pgvector、pg_jieba、pgmq、pg_trgm、hstore、uuid-ossp。
