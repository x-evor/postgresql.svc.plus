# 监控

## Helm + Prometheus

Helm Chart 内置可选的 `postgres-exporter`：

```bash
helm upgrade --install postgresql ./deploy/helm/postgresql \
  --set metrics.enabled=true
```

默认会暴露 `9187` 端口并添加 Prometheus 注解。

## Compose 场景

建议使用外部监控或自建 exporter 容器。
