# 接口与端口

## 数据库端口

| 入口 | 协议 | 默认端口 | 说明 |
| --- | --- | --- | --- |
| PostgreSQL 内部监听 | TCP | 5432 | 容器内部使用，不对外暴露 |
| stunnel TLS 入口（外部） | TLS/TCP | 5443 | Docker Compose 外部连接入口（由 `STUNNEL_PORT` 指定） |
| stunnel TLS 入口（内部） | TLS/TCP | 5433 | stunnel 容器/sidecar 监听端口（Helm 默认 5433） |

## Web 入口（可选）

| 入口 | 协议 | 默认端口 | 说明 |
| --- | --- | --- | --- |
| Caddy/Nginx | HTTP/HTTPS | 80/443 | 证书管理与健康检查 |
| pgAdmin | HTTP | 5050 | 管理界面（Compose `--profile admin`） |

> 端口配置来源：`deploy/docker/.env.example`（部署时复制为 `.env`）与 Helm `values.yaml`。
