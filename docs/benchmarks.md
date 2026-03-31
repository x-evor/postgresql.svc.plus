# 模型性能基准

以下结果来自在 `http://127.0.0.1:11434/v1/chat/completions` 接口上，使用提示语「你好，简要介绍一下自己」进行的基准测试。

## 场景：交互延迟（短答）（max_tokens=64）

| Model | HTTP | TTFT | Total | InTok | OutTok | Req/s | Avg(s) | P90(s) | P95(s) | OutTok/s | GenTok/s |
|-------|------|------|-------|-------|--------|-------|--------|--------|--------|----------|-----------|
| llama2:7b       | 200 | 1.233 | 1.233 | 37 | 64  | 0.8153 | 2.3914 | 2.4653 | 2.4657 | 51.91 | 1333333.33 |
| llama2:13b      | 200 | 2.236 | 2.237 | 37 | 64  | 0.4480 | 4.3526 | 4.4877 | 4.4901 | 28.62 | 1729729.73 |
| llama3:latest   | 200 | 1.403 | 1.403 | 18 | 64  | 0.7210 | 2.7047 | 2.7741 | 2.8062 | 45.63 | 1333333.33 |

说明：InTok = 输入 tokens，OutTok = 输出 tokens；OutTok/s = OutTok/Total；GenTok/s = OutTok/(Total-TTFT)。

## 场景：生成吞吐（长答）（max_tokens=200）

| Model | HTTP | TTFT | Total | InTok | OutTok | Req/s | Avg(s) | P90(s) | P95(s) | OutTok/s | GenTok/s |
|-------|------|------|-------|-------|--------|-------|--------|--------|--------|----------|-----------|
| llama2:7b       | 200 | 1.881 | 1.881 | 37 | 97  | 0.4301 | 4.5587 | 6.1121 | 6.2199 | 51.58 | 2108695.65 |
| llama2:13b      | 200 | 2.873 | 2.873 | 37 | 83  | 0.2927 | 6.6773 | 7.6938 | 8.2401 | 28.89 | 1693877.55 |
| llama3:latest   | 200 | 4.001 | 4.001 | 18 | 184 | 0.2639 | 7.3946 | 8.4650 | 8.5507 | 45.99 | 4600000.00 |

说明：InTok = 输入 tokens，OutTok = 输出 tokens；OutTok/s = OutTok/Total；GenTok/s = OutTok/(Total-TTFT)。


## 嵌入模型基准

以下结果来自在 `http://127.0.0.1:9000/v1/embeddings` 接口上执行：

`bash bench_embedding.sh --input_config models-emb.txt --require-dim 1024`

测试参数：BATCH=4，N=20，C=2，timeout=120s。仅统计向量维度为 1024 的结果。

| Model | HTTP | TTFT | Total | Dim | Samples | InTok | Tok/s | Samples/s | P90(s) | P95(s) |
|-------|------|------|-------|-----|---------|-------|-------|-----------|--------|--------|
| bge-m3:latest | 200 | 0.022 | 0.022 | 1024 | 4 | 0 | 0.00 | 181.50 | 0.0530 | 0.0542 |

说明：Dim = 向量维度；Samples = 每请求输入条数；InTok = usage.prompt_tokens；Tok/s = InTok/Total；Samples/s = Samples/Total。

---

# 数据库基准性能测试

以下为 PostgreSQL 的基准测试指引，重点补充**混合读写场景**。建议在稳定环境下执行（固定 CPU/内存、关闭其他负载），并记录硬件与版本信息以便对比。

## 环境与前提

- 已启动 stunnel-client（本地监听 `127.0.0.1:15432`）
- 已设置数据库账号与密码
- 使用本机 `pgbench`（PostgreSQL 官方基准工具）

## 场景：混合读写（默认 TPC-B 类负载）

该场景包含读写混合事务，适合作为 OLTP 基准的基线。

测试结果（最新一次）：

| Date | Mode | Scale | Clients | Threads | Duration(s) | Txn | TPS(no conn) | Avg Latency(ms) | Init Conn(ms) |
|------|------|-------|---------|---------|-------------|-----|--------------|-----------------|---------------|
| 2026-01-25 | TPC-B (mixed) | 50 | 16 | 4 | 120 | 2213 | 18.740381 | 843.851 | 3809.723 |

1) 初始化数据集（建议先从小规模开始）：

```bash
PGHOST=127.0.0.1 PGPORT=15432 \
pgbench -i -s 50 -U "${PGUSER:-postgres}" "${PGDATABASE:-postgres}"
```

2) 运行混合负载测试（示例：并发 16、持续 120 秒）：

```bash
PGHOST=127.0.0.1 PGPORT=15432 \
pgbench -c 16 -j 4 -T 120 -P 10 -r \
  -U "${PGUSER:-postgres}" "${PGDATABASE:-postgres}"
```

## 场景：混合读写（80/20 读写比例，可选）

若需要更贴近“读多写少”的业务，可用自定义脚本模拟 80% 读 / 20% 写的混合事务：

1) 在本机创建脚本：

```bash
cat > /tmp/pgbench_mixed_80_20.sql <<'SQL'
\set random_account random(1, 100000)
\set random_teller  random(1, 10)
\set random_branch  random(1, 1)
\set delta random(-5000, 5000)

-- 80% 读
SELECT abalance FROM pgbench_accounts WHERE aid = :random_account;

-- 20% 写（单条更新）
UPDATE pgbench_accounts
SET abalance = abalance + :delta
WHERE aid = :random_account;
SQL
```

2) 运行混合负载测试：

```bash
PGHOST=127.0.0.1 PGPORT=15432 \
pgbench -c 16 -j 4 -T 120 -P 10 -r \
  -f /tmp/pgbench_mixed_80_20.sql \
  -U "${PGUSER:-postgres}" "${PGDATABASE:-postgres}"
```

## 记录模板（建议填写）

| 维度 | 值 |
|------|-----|
| 环境 | CPU/内存/磁盘/OS |
| PostgreSQL 版本 |  |
| 数据规模（-s） |  |
| 并发（-c） |  |
| 线程（-j） |  |
| 时长（-T） |  |
| TPS（含连接） |  |
| TPS（不含连接） |  |
| 平均延迟 |  |
| P95 延迟 |  |

> 建议保存 `pgbench` 原始输出，便于后续对比不同配置（如 `postgresql.conf` 调优、存储类型或 TLS 方案）。
