# 安全模型

## 网络隔离

- PostgreSQL 仅监听容器内部 `5432`。
- 外部访问必须通过 stunnel TLS 入口。

## TLS 策略

- 默认单向 TLS（客户端验证服务端证书）。
- 可选启用 `verifyChain` 与 `checkHost` 做严格校验。
- 可选启用 mTLS（客户端证书）。

## 证书与密钥

- Caddy/Nginx+Certbot 用于 ACME 证书获取与续期。
- stunnel 服务端证书通过 `.env` 或 Helm Secret 挂载。

## 最小权限

- 使用非 root 容器用户（Helm 默认 `runAsNonRoot`）。
- 限制安全组与防火墙端口暴露。
