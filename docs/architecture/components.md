# 组件说明

## 运行时组件

- PostgreSQL 镜像：`deploy/base-images/postgres-runtime-wth-extensions.Dockerfile`
- 扩展初始化脚本：`deploy/docker/init-scripts/01-init-extensions.sql`
- 性能配置：`deploy/docker/postgresql.conf`

## 安全与入口组件

- stunnel 服务端：`deploy/docker/docker-compose.tunnel.yml`
- stunnel 客户端模板：`example/stunnel-client.conf`
- 证书引导脚本：`scripts/init_vhost.sh` + `deploy/docker/docker-compose.bootstrap.yml`
- 证书管理（可选）：`deploy/docker/docker-compose.caddy.yml` 或 `deploy/docker/docker-compose.nginx.yml`

## 部署与编排

- Docker Compose：`deploy/docker/` 目录
- Helm Chart：`deploy/helm/postgresql/`

## 运维与测试

- 自检脚本：`scripts/selftest.sh`
- 本地测试用例：`test-cases/`
