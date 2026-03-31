# PostgreSQL All-in-One DB Ops Runbook

适用场景：

- 目标机为 all-in-one 部署
- 组件组合为 `stunnel-client`、`stunnel-server`、`postgres-extensions:17`
- 需要把源机 `jp-xhttp.svc.plus` 的 `account`、`knowledge_db` 迁移到 `jp-xhttp-contabo.svc.plus`
- 要求源机不变更、服务不停
- 目标机需要去掉 `JuiceFS`

## 一句话结论

这次迁移的验收口径是：

- 目标机 PostgreSQL 已切到 `postgres-extensions:17`
- `stunnel-client`、`stunnel-server`、PostgreSQL 在同一台机上协作正常
- `account` 与 `knowledge_db` 的表级对象数和逐表 `count(*)` 已与源机对齐
- 目标机没有 `JuiceFS`

最后更新时间：2026-03-31
适用主机：

- 源机：`root@jp-xhttp.svc.plus`
- 目标机：`root@jp-xhttp-contabo.svc.plus`

## 验收结果模板

可直接发群：

> `jp-xhttp-contabo.svc.plus` 已完成 all-in-one 迁移验收。当前目标机 PostgreSQL 为 `postgres-extensions:17`，`stunnel-client` / `stunnel-server` / PostgreSQL 均在同机正常协作。`account` 与 `knowledge_db` 已完成表级校验，表数、视图数、序列数以及逐表 `count(*)` 与源机 `jp-xhttp.svc.plus` 一致。目标机已去掉 `JuiceFS`，源机保持不变、服务未停止。

## 0. 前置约束

- 源机只读核对，不做任何写入、不停服务
- 迁移前先备份
- 目标机若仍是 `PG_MAJOR=16`，不要直接启动 `postgres-extensions:17`
- 目标机若已存在旧数据目录，必须先做备份再重建

## 1. 部署前检查

在两台机分别执行：

```bash
ssh root@jp-xhttp.svc.plus 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
ssh root@jp-xhttp-contabo.svc.plus 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"'
```

检查 PostgreSQL 版本与扩展：

```bash
ssh root@jp-xhttp.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d postgres -Atc "select version(); select extname from pg_extension order by 1;"'
ssh root@jp-xhttp-contabo.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d postgres -Atc "select version(); select extname from pg_extension order by 1;"'
```

期望：

- 源机 PostgreSQL 17.x
- 目标机 PostgreSQL 17.x
- 扩展集至少包含 `hstore`, `pgmq`, `vector`
- 目标机不应再出现 `JuiceFS`

## 2. 目标机部署

### 2.1 准备镜像

在目标机上进入仓库：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'cd /opt/cloud-neutral/postgresql.svc.plus && git status --short'
```

若需要重建 `postgres-extensions:17`：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'cd /opt/cloud-neutral/postgresql.svc.plus && docker build -f deploy/base-images/postgres-runtime-wth-extensions.Dockerfile -t postgres-extensions:17 --build-arg PG_MAJOR=17 deploy/base-images'
```

### 2.2 切换环境变量

确认目标机 `.env` 为 PG17：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'grep -E "^(PG_MAJOR|PG_DATA_PATH|STUNNEL_|POSTGRES_|DOMAIN=)" /opt/cloud-neutral/postgresql.svc.plus/deploy/docker/.env'
```

如需修正：

```bash
ssh root@jp-xhttp-contabo.svc.plus "sed -i 's/^PG_MAJOR=.*/PG_MAJOR=17/' /opt/cloud-neutral/postgresql.svc.plus/deploy/docker/.env"
```

### 2.3 启动 all-in-one 组件

```bash
ssh root@jp-xhttp-contabo.svc.plus 'cd /opt/cloud-neutral/postgresql.svc.plus/deploy/docker && docker compose up -d'
```

验证：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'docker ps --format "{{.Names}}|{{.Image}}|{{.Status}}"'
ssh root@jp-xhttp-contabo.svc.plus 'docker exec postgresql-svc-plus pg_isready -U postgres -h 127.0.0.1'
ssh root@jp-xhttp-contabo.svc.plus 'docker logs --tail=80 cn-toolkit-stunnel-client'
```

## 3. 备份步骤

### 3.1 源机逻辑备份

> 只读备份，不停止源服务。

```bash
ssh root@jp-xhttp.svc.plus 'mkdir -p /root/migration-backup && docker exec -t postgresql-svc-plus pg_dumpall -U postgres > /root/migration-backup/pg_dumpall_$(date +%F_%H%M%S).sql'
ssh root@jp-xhttp.svc.plus 'sha256sum /root/migration-backup/*.sql'
```

### 3.2 推荐补充验证

```bash
ssh root@jp-xhttp.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d postgres -Atc "select datname from pg_database where datistemplate = false order by 1;"'
```

期望至少看到：

- `account`
- `knowledge_db`
- `postgres`
- `JuiceFS` 仅允许存在于源机

## 4. 迁移步骤

### 4.1 迁移脚本

推荐脚本：

```bash
/Users/shenlan/workspaces/cloud-neutral-toolkit/postgresql.svc.plus/scripts/db_full_migration.sh \
  root@jp-xhttp.svc.plus \
  root@jp-xhttp-contabo.svc.plus \
  --skip-init \
  --skip-compare \
  --target-domain postgresql-17-contabo.svc.plus \
  --acme-mode host-caddy
```

说明：

- `--skip-init` 适合目标机已完成 all-in-one 初始化后只做数据迁移
- `--target-domain` 不要写成带空格的值
- `--acme-mode host-caddy` 适用于复用主机侧 Caddy 证书流程

### 4.2 若目标机仍是 PG16

先切换到 PG17，再重建数据目录：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'docker stop cn-toolkit-stunnel-client || true'
ssh root@jp-xhttp-contabo.svc.plus 'mv /data /data.pg16.backup.$(date +%F_%H%M%S)'
ssh root@jp-xhttp-contabo.svc.plus 'cd /opt/cloud-neutral/postgresql.svc.plus/deploy/docker && docker compose up -d postgres'
```

### 4.3 导入后删除 JuiceFS

如果迁移脚本把 `JuiceFS` 一起带过去，目标机执行：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'docker exec postgresql-svc-plus dropdb -U postgres --if-exists JuiceFS'
```

### 4.4 恢复 stunnel-client

```bash
ssh root@jp-xhttp-contabo.svc.plus 'docker start cn-toolkit-stunnel-client || true'
```

## 5. 表级一致性核对

### 5.1 对象总量

```bash
ssh root@jp-xhttp.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d account -Atc "select count(*) from information_schema.tables where table_schema not in (''pg_catalog'',''information_schema'');"'
ssh root@jp-xhttp-contabo.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d account -Atc "select count(*) from information_schema.tables where table_schema not in (''pg_catalog'',''information_schema'');"'
```

对 `knowledge_db` 也执行一次：

```bash
ssh root@jp-xhttp.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d knowledge_db -Atc "select count(*) from information_schema.tables where table_schema not in (''pg_catalog'',''information_schema'');"'
ssh root@jp-xhttp-contabo.svc.plus 'docker exec postgresql-svc-plus psql -U postgres -d knowledge_db -Atc "select count(*) from information_schema.tables where table_schema not in (''pg_catalog'',''information_schema'');"'
```

### 5.2 逐表行数

`account`：

```bash
cat <<'SQL' | ssh root@jp-xhttp.svc.plus 'docker exec -i postgresql-svc-plus psql -U postgres -d account -At'
\pset tuples_only on
\pset format unaligned
select format('select %L as table_name, count(*) from %I.%I;', n.nspname||'.'||c.relname, n.nspname, c.relname)
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog', 'information_schema')
order by 1;
\gexec
SQL

cat <<'SQL' | ssh root@jp-xhttp-contabo.svc.plus 'docker exec -i postgresql-svc-plus psql -U postgres -d account -At'
\pset tuples_only on
\pset format unaligned
select format('select %L as table_name, count(*) from %I.%I;', n.nspname||'.'||c.relname, n.nspname, c.relname)
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog', 'information_schema')
order by 1;
\gexec
SQL
```

`knowledge_db`：

```bash
cat <<'SQL' | ssh root@jp-xhttp.svc.plus 'docker exec -i postgresql-svc-plus psql -U postgres -d knowledge_db -At'
\pset tuples_only on
\pset format unaligned
select format('select %L as table_name, count(*) from %I.%I;', n.nspname||'.'||c.relname, n.nspname, c.relname)
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog', 'information_schema')
order by 1;
\gexec
SQL

cat <<'SQL' | ssh root@jp-xhttp-contabo.svc.plus 'docker exec -i postgresql-svc-plus psql -U postgres -d knowledge_db -At'
\pset tuples_only on
\pset format unaligned
select format('select %L as table_name, count(*) from %I.%I;', n.nspname||'.'||c.relname, n.nspname, c.relname)
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind = 'r'
  and n.nspname not in ('pg_catalog', 'information_schema')
order by 1;
\gexec
SQL
```

### 5.3 验收口径

通过条件：

- `account` 表数、视图数、序列数一致
- `knowledge_db` 表数、视图数、序列数一致
- 逐表 `count(*)` 完全一致
- 目标机 `JuiceFS` 已删除
- 目标机 `postgresql-svc-plus`、`cn-toolkit-stunnel-client`、`stunnel-server` / 端到端链路在同机协作正常

## 6. 回滚步骤

如果目标机迁移后异常：

1. 立刻停止继续导入或继续写入
2. 回切客户端到源机
3. 保留目标机数据目录备份
4. 记录失败点后再处理

示例：

```bash
ssh root@jp-xhttp-contabo.svc.plus 'docker stop cn-toolkit-stunnel-client || true'
ssh root@jp-xhttp-contabo.svc.plus 'docker compose -f /opt/cloud-neutral/postgresql.svc.plus/deploy/docker/docker-compose.yml down || true'
```

## 7. 这次实际验收结论

- 目标机 PostgreSQL: `17.9`
- 源机 PostgreSQL: `17.8`
- 扩展集一致：`hstore`, `pgmq`, `vector`
- `account` 行数与对象数一致
- `knowledge_db` 行数与对象数一致
- `JuiceFS` 已从目标机移除
- 目标机 all-in-one 组件正常
