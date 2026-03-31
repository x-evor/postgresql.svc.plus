# 单节点融合迁移手册（PostgreSQL + jp-xhttp）

本文档用于把 `postgresql.svc.plus` 从独立节点迁移到 `jp-xhttp.svc.plus`（或任意已运行 `caddy/xray/xray-tcp/agent-svc-plus` 的节点）。

## 迁移目标

- 将 PostgreSQL 数据与 stunnel 服务迁移到同一节点。
- 避免与 `jp-xhttp` 现有端口冲突:
  - 现有业务: `80/443/1443`
  - 新增数据库 TLS 入口: `5443`（主机）
  - stunnel 容器监听: `5433`
  - PostgreSQL 容器内部: `5432`

## 融合节点端口总览

- `443 -> xray xhttp`（由 Caddy 处理 TLS/入口后转发）
- `1443 -> xray tcp`
- `5443 -> stunnel TLS -> PostgreSQL 5432`

说明: 当前 stunnel 容器内部默认 `accept=5433`，实际链路为 `5443(host) -> 5433(stunnel) -> 5432(postgres)`。

## 适用前提

- 当前源库是 Docker Compose 部署（`postgresql-svc-plus` 容器）。
- 可接受短暂停写窗口（建议 3~10 分钟）。
- 已准备目标节点磁盘目录（建议 `/data`）与防火墙规则。

## 架构与端口

```text
Client/App
  -> TLS:5443 (target host)
  -> stunnel container :5433
  -> postgres container :5432
```

在 `deploy/docker/docker-compose.tunnel.yml` 中，端口映射为:

```yaml
ports:
  - "${STUNNEL_PORT:-5443}:5433"
```

融合部署时只需在目标机 `.env` 里设置:

```bash
STUNNEL_PORT=5443
```

## 迁移步骤（推荐: 停写切换）

### 1. 源节点预检查

在源节点执行:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker exec postgresql-svc-plus psql -U postgres -tAc "select version();"
docker exec postgresql-svc-plus psql -U postgres -tAc "select datname, pg_size_pretty(pg_database_size(datname)) from pg_database where datistemplate=false;"
du -sh /data /data/pgdata
```

### 2. 目标节点准备

在目标节点执行:

```bash
mkdir -p /data
cd /root
git clone https://github.com/cloud-neutral-toolkit/postgresql.svc.plus.git
cd postgresql.svc.plus/deploy/docker
cp .env.example .env
```

编辑 `.env`，至少确认:

```bash
POSTGRES_PASSWORD=<strong-password>
PG_DATA_PATH=/data
STUNNEL_PORT=5443
```

放行端口（以 UFW 为例）:

```bash
ufw allow 5443/tcp
ufw reload
```

### 3. 源节点备份

在源节点执行逻辑备份:

```bash
mkdir -p /root/migration-backup
docker exec -t postgresql-svc-plus pg_dumpall -U postgres > /root/migration-backup/pg_dumpall_$(date +%F_%H%M%S).sql
sha256sum /root/migration-backup/*.sql
```

如需更稳妥，可额外做数据目录快照或磁盘级快照。

### 4. 进入停写窗口并导出最终数据

1) 将应用切只读或暂停写入。  
2) 再做一次最终备份:

```bash
docker exec -t postgresql-svc-plus pg_dumpall -U postgres > /root/migration-backup/pg_dumpall_final.sql
sha256sum /root/migration-backup/pg_dumpall_final.sql
```

### 5. 传输并恢复到目标节点

从源节点拷贝备份到目标节点:

```bash
scp /root/migration-backup/pg_dumpall_final.sql root@jp-xhttp.svc.plus:/root/
```

在目标节点启动 PostgreSQL（先不启 stunnel）:

```bash
cd /root/postgresql.svc.plus/deploy/docker
docker-compose up -d postgres
docker-compose exec -T postgres psql -U postgres -c "select 1;"
```

导入:

```bash
cat /root/pg_dumpall_final.sql | docker-compose exec -T postgres psql -U postgres
```

### 6. 启动 stunnel 并切流量

```bash
cd /root/postgresql.svc.plus/deploy/docker
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml ps
```

验证端口:

```bash
ss -ltnp | egrep ":5443 "
openssl s_client -connect 127.0.0.1:5443 -servername postgresql.svc.plus </dev/null
```

将客户端连接从 `postgresql.svc.plus:443` 切换到 `postgresql.svc.plus:5443`（或新节点域名:5443）。

### 7. 回归验证

在目标节点:

```bash
docker-compose exec postgres psql -U postgres -tAc "select datname, pg_size_pretty(pg_database_size(datname)) from pg_database where datistemplate=false;"
docker-compose exec postgres psql -U postgres -d account -tAc "select now();"
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml logs --tail=200 stunnel
```

建议至少验证:

- 关键库大小与源节点同量级。
- 关键业务读写 SQL 正常。
- stunnel 无握手错误、无持续重连风暴。

## 回滚方案

若切流后异常:

1. 客户端连接串立即回切到源节点（原端口）。  
2. 源节点恢复写入。  
3. 保留目标节点实例用于问题复盘，避免直接清理现场。

## 常见问题

### 1) 为什么不用 443?

融合场景下 `jp-xhttp` 已使用 `443`（Caddy/Xray），数据库再占用 `443` 会冲突。改为 `5443` 是低风险、最小改动方案。

### 2) 客户端是否必须改造?

不需要改协议，仅修改目标端口即可（`443 -> 5443`）。

### 3) 是否可以在线迁移零停机?

可以做“全量 + 增量”方案，但复杂度高。当前手册采用停写切换，风险更低、可控性更好。
