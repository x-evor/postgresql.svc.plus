# 错误约定

本项目不定义统一的 HTTP 错误码；常见错误来自 PostgreSQL 与 stunnel。

## 常见错误

- `password authentication failed`：用户名/密码错误，检查 `.env` 或 Helm `auth` 配置。
- `could not connect to server`：stunnel 未启动或端口未开放。
- `certificate verify failed`：客户端信任链不完整或域名不匹配。

## 排查建议

- 查看 stunnel 日志：`docker-compose logs -f stunnel`
- 查看 PostgreSQL 日志：`docker-compose logs -f postgres`
- Helm 环境可用：`kubectl logs -l app.kubernetes.io/name=postgresql`
- 使用 `openssl s_client` 测试 TLS 握手
