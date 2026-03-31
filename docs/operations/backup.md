# 备份与恢复

## Docker Compose

```bash
# 备份
pg_dump -h 127.0.0.1 -U postgres -d postgres > backup.sql

# 恢复
psql -h 127.0.0.1 -U postgres -d postgres < backup.sql
```

如使用 stunnel 客户端，请连接 `127.0.0.1:15432`。

## Kubernetes

- 使用 `pg_dump` + PVC
- 或使用云厂商快照（PVC Snapshot）

## 注意

备份策略应结合业务 SLA 设置频率与保留周期。
