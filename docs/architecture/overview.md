# 架构总览

## 总体架构

```
┌───────────────────────────────┐        ┌───────────────────────────────┐
│          应用服务器            │        │            数据库服务器         │
│                               │        │                               │
│  App → 127.0.0.1:15432        │        │  stunnel (server) :443/5433   │
│        (stunnel client)       │        │        ↓                      │
└──────────────┬────────────────┘        │  PostgreSQL :5432 (internal)   │
               │ TLS                        │  Extensions preinstalled     │
               └──────────────────────────→└───────────────────────────────┘
```

## 组件关系

- PostgreSQL：仅内部监听，保证数据库端口不直接暴露。
- stunnel：提供 TLS 加密入口，作为对外服务端口。
- Caddy 或 Nginx+Certbot（可选）：负责 ACME 证书与 Web 健康检查、pgAdmin 入口。
- Helm/Compose：部署编排与配置管理。

## 数据流

1. 应用连接本地 stunnel 客户端 `127.0.0.1:15432`。
2. stunnel 客户端通过 TLS 连接到服务端（默认 `:443`）。
3. stunnel 服务端解密后转发到 PostgreSQL `127.0.0.1:5432`。
4. PostgreSQL 只处理 SQL，无 TLS 开销。
