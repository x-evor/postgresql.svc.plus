# 关键设计取舍

## 1) 选择 stunnel 而不是 PostgreSQL 原生 SSL

- PostgreSQL 专注于 SQL 处理，TLS 加解密交给 stunnel。
- 应用侧可保持标准连接字符串，无需 `sslmode` 调优。
- stunnel 可独立扩展与替换。

## 2) 默认对外端口为 443

- 兼容常见网络环境与防火墙策略。
- 与 ACME 证书申请流程协同（80/443）。

## 3) 扩展打包到镜像

- 降低部署复杂度，避免运行时安装与版本漂移。
- 扩展版本在 `Makefile` 与镜像构建阶段统一管理。

## 4) Docker Compose + Helm 双轨

- Compose 用于单机与开发环境，降低上手门槛。
- Helm 用于生产与多环境，集中管理配置与监控。

## 5) 证书管理独立化

- Caddy/Nginx 只负责证书与 HTTP 服务。
- 数据库连接安全由 stunnel 独立完成，职责分离。
