# pglogical 双向逻辑复制部署指南

本文档介绍如何在两台 PostgreSQL 16 数据库之间部署 pglogical 扩展，实现支持 TLS 的异步双向逻辑复制，并包含冲突处理、监控及与 Bucardo 的对比。

## 目录

1. [pglogical 简介](#pglogical-简介)
2. [环境准备](#环境准备)
3. [安装 pglogical 扩展](#安装-pglogical-扩展)
4. [配置 PostgreSQL 参数](#配置-postgresql-参数)
5. [创建复制用户](#创建复制用户)
6. [创建节点与复制集](#创建节点与复制集)
7. [建立双向订阅](#建立双向订阅)
8. [验证复制状态](#验证复制状态)
9. [冲突解决策略](#冲突解决策略)
10. [TLS 配置示例](#tls-配置示例)
11. [常用维护命令](#常用维护命令)
12. [监控指标](#监控指标)
13. [性能与延迟优化建议](#性能与延迟优化建议)
14. [优缺点总结](#优缺点总结)
15. [推荐部署参数模板](#推荐部署参数模板)
16. [与 Bucardo 的对比](#与-bucardo-的对比)
17. [附录：SQL 脚本模板](#附录sql-脚本模板)

---

## pglogical 简介

| 特性 | 说明 |
| :--- | :--- |
| 类型 | 基于 WAL 的逻辑复制扩展（由 2ndQuadrant 开发，后并入 EDB/PGDG） |
| 复制粒度 | 表级 / 库级，支持选择性复制 |
| 拓扑 | 单向、一主多从、多主（双向）均可 |
| 延迟 | 秒级（异步逻辑流式复制） |
| 冲突 | 可配置（默认“先到先得”，支持自定义冲突解决） |
| DDL 支持 | 不自动复制 DDL（需两端结构一致） |
| 安全 | 继承 PostgreSQL 的 TLS / SCRAM / 证书机制 |
| 推荐版本 | PostgreSQL 13~17（pglogical 2.x/3.x） |

与 Bucardo 相比，pglogical 更现代、稳定、性能更高，且原生支持异步双向复制（multi-master）和 TLS 加密。

## 环境准备

假设部署架构如下：

| 节点 | 主机名 | 数据库 | 角色 |
| :--- | :--- | :--- | :--- |
| A | `cn-homepage.svc.plus` | `account` | `node_cn` |
| B | `global-homepage.svc.plus` | `account` | `node_global` |

两台节点均运行 PostgreSQL 16，并且网络互通。

## 安装 pglogical 扩展

在两台节点上安装 pglogical 软件包：

- **Ubuntu / Debian**

  ```bash
  sudo apt install postgresql-16-pglogical
  ```

- **Red Hat / CentOS**

  ```bash
  sudo yum install pglogical_16
  ```

安装完成后，请使用具有 **SUPERUSER** 权限的账号（例如 `postgres`）在 `account` 数据库中创建并验证扩展：

```bash
sudo -u postgres psql -d account -c "CREATE EXTENSION IF NOT EXISTS pglogical;"
sudo -u postgres psql -d account -c "\dx pglogical"
```

若缺少超级用户权限，可请数据库管理员预先创建扩展，再继续后续的 pglogical 配置。


## 创建 repl_user（基础复制用户）

在主库（Publisher）执行以下操作： sudo -u postgres psql

执行 SQL：
```
-- 创建用于逻辑/物理复制的底层用户
CREATE ROLE repl_user WITH LOGIN REPLICATION PASSWORD 'StrongPassword123!';
-- 确认创建成功
\du repl_user
```

输出应包含：

```
Role name | Attributes
-----------+-------------------------------
repl_user  | Replication, Login
```

## 创建 pglogical（逻辑复制应用用户）

仍在 PostgreSQL 中执行：
```
-- 创建逻辑复制用的应用账户
CREATE ROLE pglogical WITH LOGIN REPLICATION PASSWORD 'StrongPass';
-- 授权访问业务数据库（假设名为 account）
GRANT ALL PRIVILEGES ON DATABASE account TO pglogical;
ALTER ROLE pglogical WITH SUPERUSER;
```

⚠️ 注意：pglogical 账号需要复制与读写权限，目前测试需要SUPERUSER。生产环境建议使用强密码、并限制来源 IP。


## 配置 PostgreSQL 参数

在两台节点的 `/etc/postgresql/16/main/postgresql.conf` 中设置逻辑复制所需参数：

```
# 修改 PostgreSQL 监听地址
listen_addresses = '*'

# 逻辑复制基础
wal_level = logical
max_wal_senders = 10
max_replication_slots = 10
max_worker_processes = 10
max_logical_replication_workers = 8

# 建议优化
shared_preload_libraries = 'pglogical'
track_commit_timestamp = on
```

## 配置访问控制（pg_hba.conf）

编辑主库（Publisher）上的 /etc/postgresql/16/main/pg_hba.conf 限定允许的远程节点:
```
# 本地管理
local   all             postgres                                peer
host    all             all             127.0.0.1/32            md5

# 允许复制与逻辑复制（加密连接）
hostssl replication     repl_user       <peer_ip>/32            scram-sha-256
hostssl all             pglogical       <peer_ip>/32            scram-sha-256
```

其中 <peer_ip> 为另一台数据库节点的 IP 地址或域名。

## 启用 TLS（postgresql.conf）

scripts/generate-postgres-tls.sh
```
#!/usr/bin/env bash
set -e

# ============================================================
# PostgreSQL 专用 TLS 证书生成脚本（含 *.svc.plus + 双 IP）
# 作者：SVC.PLUS PostgreSQL Server TLS Generator
# ============================================================

TLS_DIR="/etc/postgres-tls"
CA_DIR="$TLS_DIR/ca"
SERVER_DIR="$TLS_DIR/server"

echo ">>> [1/6] 创建目录结构 ..."
sudo mkdir -p "$CA_DIR" "$SERVER_DIR"
cd "$TLS_DIR"

# ============================================================
# 1. 创建私有 CA 根证书
# ============================================================
echo ">>> [2/6] 生成 PostgreSQL 专用私有 CA ..."
sudo openssl genrsa -aes256 -out "$CA_DIR/ca.key.pem" 4096
sudo chmod 600 "$CA_DIR/ca.key.pem"

sudo openssl req -x509 -new -nodes -key "$CA_DIR/ca.key.pem" -sha256 -days 3650 \
  -subj "/C=CN/O=SVC.PLUS PostgreSQL Authority/OU=DB Security/CN=SVC.PLUS PostgreSQL Root CA" \
  -out "$CA_DIR/ca.cert.pem"

# ============================================================
# 2. 生成服务器证书
# ============================================================
echo ">>> [3/6] 生成服务器私钥与 CSR ..."
sudo openssl genrsa -out "$SERVER_DIR/server.key.pem" 2048
sudo chmod 600 "$SERVER_DIR/server.key.pem"

sudo openssl req -new -key "$SERVER_DIR/server.key.pem" \
  -subj "/C=CN/O=SVC.PLUS PostgreSQL Server/OU=DB/CN=global-homepage.svc.plus" \
  -out "$SERVER_DIR/server.csr.pem"

# SAN 扩展配置
cat <<EOF | sudo tee "$SERVER_DIR/server.ext" >/dev/null
basicConstraints=CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.svc.plus
DNS.2 = svc.plus
DNS.3 = global-homepage.svc.plus
DNS.4 = cn-homepage.svc.plus
IP.1  = 167.179.72.223
IP.2  = 47.120.61.35
EOF

# 签发服务器证书（2年有效）
echo ">>> [4/6] 使用 SVC.PLUS PostgreSQL Root CA 签发服务器证书 ..."
sudo openssl x509 -req -in "$SERVER_DIR/server.csr.pem" \
  -CA "$CA_DIR/ca.cert.pem" -CAkey "$CA_DIR/ca.key.pem" \
  -CAcreateserial -out "$SERVER_DIR/server.cert.pem" \
  -days 730 -sha256 -extfile "$SERVER_DIR/server.ext"

# fullchain
sudo cat "$SERVER_DIR/server.cert.pem" "$CA_DIR/ca.cert.pem" | sudo tee "$SERVER_DIR/server.fullchain.pem" >/dev/null

# ============================================================
# 3. 安装到 PostgreSQL 标准路径
# ============================================================
echo ">>> [5/6] 安装证书到 PostgreSQL SSL 目录 ..."
sudo install -o postgres -g postgres -m 600 "$SERVER_DIR/server.key.pem" /etc/ssl/private/svc.plus-postgres.key
sudo install -o postgres -g postgres -m 644 "$SERVER_DIR/server.fullchain.pem" /etc/ssl/certs/svc.plus-postgres.crt
sudo install -o postgres -g postgres -m 644 "$CA_DIR/ca.cert.pem" /etc/ssl/certs/svc.plus-postgres-ca.crt

# ============================================================
# 4. 输出后续操作提示
# ============================================================
echo "==============================================================="
echo "✅ [SVC.PLUS PostgreSQL TLS] 已生成并安装完成"
echo ""
echo "请在 /etc/postgresql/16/main/postgresql.conf 中添加或确认以下配置："
echo ""
echo "  ssl = on"
echo "  ssl_cert_file = '/etc/ssl/certs/svc.plus-postgres.crt'"
echo "  ssl_key_file  = '/etc/ssl/private/svc.plus-postgres.key'"
echo "  ssl_ca_file   = '/etc/ssl/certs/svc.plus-postgres-ca.crt'"
echo ""
echo "⚙️  然后执行： sudo systemctl restart postgresql"
echo ""
echo "📦 客户端（订阅端）请复制 CA 根证书："
echo "  /etc/postgres-tls/ca/ca.cert.pem"
echo "至客户端路径："
echo "  /var/lib/postgresql/.postgresql/root.crt"
echo "（权限：600，属主 postgres）"
echo ""
echo "🔍 验证命令示例："
echo "  openssl s_client -connect 167.179.72.223:5432 -starttls postgres -servername global-homepage.svc.plus"
echo ""
echo "👑 证书主题：SVC.PLUS PostgreSQL Server"
echo "包含 SAN: *.svc.plus, global-homepage, cn-homepage, IP(167.179.72.223, 47.120.61.35)"
echo "==============================================================="
```

创建好的证书分发到在两台节点上

两台节点上执行：

PostgreSQL 客户端必须存在一份 受信任 CA 根证书文件， 路径固定为 /var/lib/postgresql/.postgresql/root.crt （属于 postgres 用户，权限必须是 600）。

```
# 1️⃣ 创建目录 
sudo -u postgres mkdir -p /var/lib/postgresql/.postgresql

# 2️⃣ 从 global-homepage 拉取服务器的 CA 根证书
cp /etc/ssl/certs/svc.plus-postgres-ca.crt /var/lib/postgresql/.postgresql/root.crt

# 3️⃣ 设置权限
sudo chown postgres:postgres /var/lib/postgresql/.postgresql/root.crt
sudo chmod 600 /var/lib/postgresql/.postgresql/root.crt
```

在两台节点上执行：编辑 /etc/postgresql/16/main/postgresql.conf 检查下面配置是否存在

```
ssl = on
ssl_cert_file = '/etc/ssl/certs/svc.plus.crt'
ssl_key_file  = '/etc/ssl/private/svc.plus.key'
```

重启 PostgreSQL 生效 

sudo systemctl restart postgresql@16-main
或（简写方式）：
sudo systemctl restart postgresql

## 验证角色与访问

1️⃣ 查看角色列表 sudo -u postgres psql -c "\du"
应看到：

repl_user  | Replication, Login
pglogical  | Replication, Login

2️⃣ 订阅端测试连接

在另一台节点测试 TLS 登录： psql "host=<publisher_ip> user=pglogical password=StrongPass dbname=account sslmode=require"


成功进入 account=> 提示符表示逻辑复制用户配置完毕 ✅。


## 创建节点与复制集

### 双向架构概览

```
┌───────────────────────────┐
│   🌍 global-homepage      │
│   node_name = node_global │
│   publishes → node_cn     │
│   subscribes ← node_cn    │
└───────────────────────────┘
               ▲  │
               │  ▼
┌───────────────────────────┐
│   🇨🇳 cn-homepage          │
│   node_name = node_cn     │
│   publishes → node_global │
│   subscribes ← node_global│
└───────────────────────────┘
```

两个节点都：

- 拥有 pglogical 扩展；
- 注册自己的 node；
- 定义相同的 replication_set；
- 创建互为订阅（create_subscription）。


### 步骤 1：CN 节点初始化

登录 CN 主机（cn-homepage.svc.plus）： 

执行: sudo -u postgres psql -d account 
执行：

```
-- 启用扩展
CREATE EXTENSION IF NOT EXISTS pglogical;

-- 注册本地节点
SELECT pglogical.create_node(
    node_name := 'node_cn',
    dsn := 'host=47.120.61.35 port=5432 dbname=account user=pglogical password=StrongPass sslmode=prefer'
);

-- 创建复制集
SELECT pglogical.create_replication_set('rep_all');
SELECT pglogical.replication_set_add_all_tables('rep_all', ARRAY['public']);
```

### 步骤 2：Global 节点初始化

登录 Global 主机（global-homepage.svc.plus）：

执行:sudo -u postgres psql -d account
执行：
```
-- 启用扩展
CREATE EXTENSION IF NOT EXISTS pglogical;

-- 注册本地节点
SELECT pglogical.create_node(
    node_name := 'node_global',
    dsn := 'host=167.179.72.223 port=5432 dbname=account user=pglogical password=StrongPass sslmode=prefer'
);

-- 创建复制集
SELECT pglogical.create_replication_set('rep_all');
SELECT pglogical.replication_set_add_all_tables('rep_all', ARRAY['public']);
```


### 步骤 3：建立双向订阅

- 在 CN 节点 上创建订阅（订阅 Global）

```
SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_global',
    provider_dsn := 'host=167.179.72.223 port=5432 dbname=account user=pglogical password=StrongPass sslmode=prefer',
    replication_sets := ARRAY['rep_all'],
    synchronize_structure := false,
    synchronize_data := true,
    forward_origins := '{}'
);
```

- 在 Global 节点 上创建订阅（订阅 CN）

```
SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_cn',
    provider_dsn := 'host=47.120.61.35 port=5432 dbname=account user=pglogical password=StrongPass sslmode=prefer',
    replication_sets := ARRAY['rep_all'],
    synchronize_structure := false,
    synchronize_data := true,
    forward_origins := '{}'
);
```

### 参数解释

参数	含义

- synchronize_structure=false	表示两端表结构已经一致，不再自动创建表。
- synchronize_data=true	首次订阅时自动同步现有数据。
- forward_origins='{}'	防止环形复制（即从对方同步的数据再传回去）。
- sslmode=verify-full	使用 TLS 校验证书和域名。

### 检查状态

两端都执行：

```
SELECT * FROM pglogical.node;
SELECT * FROM pglogical.subscription;
SELECT * FROM pglogical.show_subscription_status();
```

正常情况下你会看到：

各自注册的 node（node_cn / node_global）
一条订阅（sub_from_cn / sub_from_global）

状态为 “replicating”

🚦 常见问题排查
错误	原因	解决
current database is not configured as pglogical node	没有先执行 create_node()	先执行 pglogical.create_node()
could not connect to server	对方 pg_hba.conf 未放行	检查 hostssl all pglogical <peer_ip>/32 scram-sha-256
no pg_hba.conf entry for host ... SSL	SSL 模式与证书不匹配	用 sslmode=prefer 临时测试
双向数据回环	forward_origins 未设为 {}	确保订阅语句中加 forward_origins := '{}'


## 验证复制状态

常用验证命令：

```sql
SELECT * FROM pglogical.show_subscription_status();
SELECT * FROM pglogical.show_node_info();
```

查看流复制进度：

```sql
SELECT application_name, state, sent_lsn, write_lsn, flush_lsn, replay_lsn
FROM pg_stat_replication;
```

日志中出现如下信息表明表同步完成：

```
pglogical: initial copy of table "public.users" finished
```

## 冲突解决策略

pglogical 默认策略为 “first commit wins”。在开启 `track_commit_timestamp = on` 后，可以使用以下策略：

| 策略 | 含义 |
| :--- | :--- |
| `error` | 发生冲突时报错并终止复制 |
| `apply_remote` | 使用远端数据覆盖本地 |
| `keep_local` | 保留本地数据，忽略远端变更 |
| `latest_commit` | 保留提交时间更晚的行 |
| `custom` | 调用自定义函数处理冲突 |

示例：

```sql
SELECT pglogical.alter_subscription_options(
  subscription_name := 'sub_from_b',
  options := '{conflict_resolution=latest_commit}'
);
```

## TLS 配置示例


使用 `libpq` 连接参数即可启用 TLS：

```sql
SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_b',
    provider_dsn := 'host=pgB.svc.plus port=5432 dbname=account user=pglogical password=StrongPass sslmode=verify-full sslrootcert=/etc/ssl/rootCA.crt sslcert=/etc/ssl/client.crt sslkey=/etc/ssl/client.key',
    replication_sets := ARRAY['rep_all']
);
```

`sslmode` 支持 `require`、`verify-ca`、`verify-full`，推荐使用 `verify-full` 并确保证书 CN/SAN 与主机名匹配。

## 常用维护命令

| 操作 | SQL 命令 |
| :--- | :--- |
| 暂停订阅 | `SELECT pglogical.alter_subscription_disable('sub_from_global');` |
| 恢复订阅 | `SELECT pglogical.alter_subscription_enable('sub_from_global', true);` |
| 删除订阅 | `SELECT pglogical.drop_subscription('sub_from_global');` |
| 删除节点 | `SELECT pglogical.drop_node('node_cn');` |

## 监控指标

| 表 / 视图 | 说明 |
| :--- | :--- |
| `pglogical.show_subscription_status()` | 订阅状态（延迟、复制槽、错误） |
| `pg_stat_replication` | WAL 流复制进度 |
| `pglogical.replication_set` | 当前同步的表集合 |
| `pglogical.local_sync_status` | 同步阶段（initial / catching-up / ready） |

## 性能与延迟优化建议

| 参数 | 推荐值 | 说明 |
| :--- | :--- | :--- |
| `max_replication_slots` | ≥ 10 | 允许更多并发订阅 |
| `max_wal_senders` | ≥ 10 | 支持更多并发流复制连接 |
| `maintenance_work_mem` | ≥ 128MB | 提高初始数据复制效率 |
| `synchronous_commit` | `off` | 降低写入延迟（异步复制场景） |
| `wal_compression` | `on` | 降低网络传输量 |
| `subscription_apply_delay` | 0–60 秒 | 可配置延迟重放，满足业务需求 |

## 优缺点总结

| 优点 | 缺点 |
| :--- | :--- |
| 原生逻辑复制，性能远优于 Bucardo | 不复制 DDL，需保证结构一致 |
| 支持 TLS / SCRAM / 双向复制 | 需要安装扩展（非纯 SQL） |
| 冲突处理策略灵活（`latest_commit` / `custom`） | 不适合同一行的高并发双写场景 |
| 延迟低（秒级） | 不支持系统表复制 |

## 推荐部署参数模板

| 项 | 配置 |
| :--- | :--- |
| 节点 A/B | PostgreSQL 16 + pglogical 3.6 |
| 通道 | TLS (`sslmode=verify-full`) |
| 复制方向 | 双向 |
| 延迟 | 2–10 秒 |
| 冲突策略 | `latest_commit` |
| 初始同步 | `synchronize_data = true` |
| 同步集 | 业务表（`users`、`identities`、`sessions`） |
| DDL 管理 | GitOps + 同步迁移脚本 |
| 监控 | Grafana + `pg_stat_replication` + `pglogical` 状态视图 |

## 与 Bucardo 的对比

| 维度 | pglogical | Bucardo |
| :--- | :--- | :--- |
| 复制机制 | WAL 逻辑流 | 触发器 + 队列 |
| 延迟 | 秒级 | 秒级至分钟级 |
| 性能 | 高 | 中 |
| 冲突控制 | 内置多策略 | Perl 自定义 |
| 安全 | 原生支持 TLS | 依赖 libpq TLS |
| 部署复杂度 | 中（需扩展） | 低（Perl 脚本） |
| 推荐场景 | 跨 Region 双向 / 实时异步复制 | 异地多活、低写负载场景 |

## 附录：SQL 脚本模板

可将上述配置整理为以下 SQL 脚本：

### `setup-node-a.sql`

```sql
-- 节点 A 初始化
CREATE EXTENSION IF NOT EXISTS pglogical;
SELECT pglogical.create_node(
    node_name := 'node_a',
    dsn := 'host=pgA.svc.plus port=5432 dbname=account user=pglogical password=StrongPass sslmode=verify-full'
);
SELECT pglogical.create_replication_set('rep_all');
SELECT pglogical.replication_set_add_all_tables('rep_all', ARRAY['public']);
SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_b',
    provider_dsn := 'host=pgB.svc.plus port=5432 dbname=account user=pglogical password=StrongPass sslmode=verify-full',
    replication_sets := ARRAY['rep_all'],
    synchronize_structure := false,
    synchronize_data := true,
    forward_origins := '{}'
);
```

### `setup-node-b.sql`

```sql
-- 节点 B 初始化
CREATE EXTENSION IF NOT EXISTS pglogical;
SELECT pglogical.create_node(
    node_name := 'node_b',
    dsn := 'host=pgB.svc.plus port=5432 dbname=account user=pglogical password=StrongPass sslmode=verify-full'
);
SELECT pglogical.create_replication_set('rep_all');
SELECT pglogical.replication_set_add_all_tables('rep_all', ARRAY['public']);
SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_a',
    provider_dsn := 'host=pgA.svc.plus port=5432 dbname=account user=pglogical password=StrongPass sslmode=verify-full',
    replication_sets := ARRAY['rep_all'],
    synchronize_structure := false,
    synchronize_data := true,
    forward_origins := '{}'
);
```

### `verify-replication.sql`

```sql
-- 验证订阅状态
SELECT * FROM pglogical.show_subscription_status();
SELECT * FROM pglogical.show_node_info();

-- 检查复制进度
SELECT application_name, state, sent_lsn, write_lsn, flush_lsn, replay_lsn
FROM pg_stat_replication;
```

以上脚本可根据实际业务需要调整数据库名称、节点信息及复制集内容。
