# 测试策略

## 基础验证

```bash
make test-postgres
```

## stunnel 客户端自检

```bash
STUNNEL_CONF=example/stunnel-client.conf \
scripts/selftest.sh
```

## 本地测试用例

目录：`test-cases/`

包含针对 stunnel 客户端与连接的本地测试脚本。
