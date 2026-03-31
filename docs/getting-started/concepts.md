# 核心概念

## 1) 预装扩展的 PostgreSQL 运行时

项目基于自建镜像（`deploy/base-images/postgres-runtime-wth-extensions.Dockerfile`），预装常用扩展，避免每次部署手动安装。

## 2) stunnel TLS 隧道

- PostgreSQL 仅在容器内监听 `127.0.0.1:5432`。
- 对外的 TLS 连接由 stunnel 提供（默认端口 `5443`）。
- 应用侧使用本地 stunnel 客户端，连接 `127.0.0.1:15432`，无需修改 `sslmode`。

## 3) 证书管理（可选）

- Caddy 或 Nginx+Certbot 用于 ACME 证书申请与续期。
- `scripts/init_vhost.sh` 会尝试复用已有证书或自动引导获取。

## 4) 部署形态

- Docker Compose：适合单机与开发。
- Helm/Kubernetes：适合生产环境与多节点集群。

## 5) 初始化脚本与配置

- `deploy/docker/init-scripts/` 或 Helm `initScripts` 用于初始化扩展。
- `deploy/docker/postgresql.conf` 或 Helm `postgresql.config` 用于性能调优。
