# 配置说明

## Docker Compose（`.env`）

位置：`deploy/docker/.env.example`（模板），部署时复制为 `deploy/docker/.env`。

| 变量 | 说明 | 默认值/示例 |
| --- | --- | --- |
| POSTGRES_USER | 超级用户 | postgres |
| POSTGRES_PASSWORD | 超级用户密码 | changeme_secure_password |
| POSTGRES_DB | 默认数据库 | postgres |
| PG_DATA_PATH | 数据卷路径 | /data |
| STUNNEL_PORT | 对外 TLS 端口 | 5443 |
| PGADMIN_EMAIL | pgAdmin 登录邮箱 | admin@example.com |
| PGADMIN_PASSWORD | pgAdmin 密码 | admin_password |
| PGADMIN_PORT | pgAdmin 端口 | 5050 |

> `POSTGRES_PASSWORD` 为必填项（在 `docker-compose.yml` 中强制校验）。

## stunnel 服务端配置

- 文件：`deploy/docker/stunnel-server.conf`
- 证书文件由 `STUNNEL_CRT_FILE` / `STUNNEL_KEY_FILE` 挂载（`.env` 或脚本写入；默认路径为 `./certs/server-cert.pem` 与 `./certs/server-key.pem`）。
  - `deploy/docker/docker-compose.tunnel.yml` 支持用环境变量覆盖默认路径。

## Helm values

位置：`deploy/helm/postgresql/values.yaml`

重点字段：

- `auth.username/password/database`
- `postgresql.config`（替代 `postgresql.conf`）
- `initScripts`（初始化扩展）
- `persistence.size/storageClass`
- `metrics.enabled`（Prometheus exporter）
- `stunnel.enabled`
- `stunnel.certificatesSecret`
- `stunnel.port`（默认 5433）

## 连接地址

- Docker Compose 同一网络/容器内：`postgres://user:pass@postgres:5432/db`
- stunnel 客户端：`postgres://user:pass@127.0.0.1:15432/db`
