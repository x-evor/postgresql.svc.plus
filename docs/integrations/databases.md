# 数据库与扩展

## PostgreSQL 生态

项目完全兼容标准 PostgreSQL 客户端与驱动（psql、psycopg、pgx、JDBC 等）。

## 预装扩展

- pgvector：向量检索
- pg_jieba：中文分词
- pgmq：轻量级消息队列
- pg_trgm：模糊匹配
- hstore：键值存储
- uuid-ossp：UUID 生成

扩展初始化由 `deploy/docker/init-scripts/01-init-extensions.sql` 或 Helm `initScripts` 完成。
