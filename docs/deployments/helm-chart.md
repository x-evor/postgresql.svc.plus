# Helm Chart 部署

推荐阅读：`docs/usage/deployment.md`

## 安装

```bash
helm install postgresql ./deploy/helm/postgresql \
  --set auth.password=your-secure-password \
  --set persistence.size=10Gi
```

## 启用 stunnel sidecar

```bash
helm install postgresql ./deploy/helm/postgresql \
  --set auth.password=your-secure-password \
  --set stunnel.enabled=true \
  --set stunnel.certificatesSecret=stunnel-certs
```

默认配置详见 `deploy/helm/postgresql/values.yaml`。
