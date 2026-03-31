# 认证与鉴权

## PostgreSQL 认证

- 使用 PostgreSQL 原生账号密码（`POSTGRES_USER` / `POSTGRES_PASSWORD`）。
- 可通过 `postgresql.conf` 和 `pg_hba.conf` 进一步配置访问策略（Helm 支持追加 `pgHba`）。

## TLS 安全

- stunnel 提供 TLS 加密传输，客户端默认使用单向 TLS（验证服务端证书）。
- 如需更严格校验，可在 stunnel 客户端配置 `verify=2` 与 `checkHost`，并指定 `CAfile`。
- 可选启用 mTLS（客户端证书），需自行生成证书并调整 stunnel 配置。
