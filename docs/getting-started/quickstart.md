# 快速开始

目标：10 分钟内在一台 Linux 服务器上拉起 PostgreSQL + 扩展 + TLS 隧道。

## 前置条件

- 一台 VM（Debian 12/13、Ubuntu 22.04/24.04、Rocky 8/9/10）
- 公网 IP + 域名（用于 ACME 证书）
- 开放端口：`80`（证书签发）和 `5443`（stunnel TLS 入口，默认）

## 一键启动（推荐）

在服务器执行：

```bash
curl -fsSL https://raw.githubusercontent.com/cloud-neutral-toolkit/postgresql.svc.plus/main/scripts/init_vhost.sh | bash
```

指定 PostgreSQL 版本与域名：

```bash
curl -fsSL https://raw.githubusercontent.com/cloud-neutral-toolkit/postgresql.svc.plus/main/scripts/init_vhost.sh \
  | bash -s -- 17 db.example.com
```

脚本会：
- 安装依赖（Docker/Compose 等）
- 构建镜像并生成 `.env`
- 获取/复用 ACME 证书（或使用本地证书）
- 启动 PostgreSQL 与 stunnel 服务端

## 客户端连接（应用侧）

在应用服务器上创建 stunnel 客户端配置（可参考 `example/stunnel-client.conf`）：

```ini
[postgres-client]
client  = yes
accept  = 127.0.0.1:15432
connect = db.example.com:5443
verify  = 2
```

启动 stunnel 客户端后，应用只需连接本地端口：

```bash
psql "host=127.0.0.1 port=15432 user=postgres dbname=postgres"
```

> 数据库密码保存在服务器的 `deploy/docker/.env` 中（由脚本生成；模板为 `deploy/docker/.env.example`）。

## 下一步

- 部署方式详情：`docs/usage/deployment.md`
- 配置说明：`docs/usage/config.md`
- 故障排查：`docs/operations/troubleshooting.md`
