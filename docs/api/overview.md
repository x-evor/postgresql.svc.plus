# API 概览

本项目不提供独立的 HTTP API 服务，核心对外接口是标准 PostgreSQL 协议与可选的 Web 管理入口。

## 对外接口类型

- PostgreSQL 连接（TCP）
- stunnel TLS 入口（TCP）
- 可选的 Web/Health 入口（Caddy/Nginx/pgAdmin）
