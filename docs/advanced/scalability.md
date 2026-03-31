# 高可用与扩展

当前 Helm Chart 默认部署单实例 PostgreSQL（StatefulSet 1 副本），不内置主从复制或自动故障转移。

## 可选方案

- 使用云数据库或外部复制方案（如原生流复制、Patroni）
- 在数据库层完成 HA 后，将本项目用于扩展与部署编排

## stunnel 扩展

stunnel 是无状态服务，可通过多实例横向扩展并在前面加负载均衡。
