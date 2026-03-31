# 性能与扩展性

## PostgreSQL 调优

- Docker：编辑 `deploy/docker/postgresql.conf`
- Helm：修改 `values.yaml` 中的 `postgresql.config`

建议根据实例资源调整：`shared_buffers`、`effective_cache_size`、`work_mem`、`max_connections`。

## 连接优化

- 应用侧建议使用连接池（如 PgBouncer）
- stunnel 仅处理 TLS，不改变连接语义

## 向量检索性能

- 大规模向量检索建议结合 `ivfflat` 或 HNSW 索引（由业务侧创建）
- 控制维度与数据量，避免无界增长
