# GitHub Actions CI/CD - 快速参考

## 📋 工作流列表

| 工作流 | 用途 | 触发方式 |
|--------|------|---------|
| **Build Image** | 构建 PostgreSQL 镜像 | 自动 (Push/PR) 或手动 |
| **Deploy to VM** | 部署到虚拟机 | 手动触发 |
| **Deploy to K8s** | 部署到 Kubernetes/K3s | 手动触发 |

## 🚀 快速开始

### 1. 配置 Secrets

在 GitHub 仓库 Settings → Secrets and variables → Actions 中添加:

**VM 部署**:
```
SSH_PRIVATE_KEY       # SSH 私钥
DOMAIN                # postgresql.svc.plus
CERTBOT_EMAIL         # admin@example.com
```

**Kubernetes 部署**:
```
KUBECONFIG            # base64 编码的 kubeconfig
POSTGRES_PASSWORD     # 数据库密码
```

### 2. 运行工作流

1. 访问 GitHub → Actions
2. 选择工作流
3. 点击 "Run workflow"
4. 填写参数并运行

## 🎯 部署模式

### VM 部署模式

| 模式 | 组件 | 端口 | 用途 |
|------|------|------|------|
| **basic** | PostgreSQL | - | 开发测试 |
| **nginx-certbot** | PG + Nginx + Certbot | 443, 5432 | 小型生产 |
| **caddy** | PG + Caddy | 443, 5432 | 小型生产 |
| **stunnel** | PG + Stunnel | 5433 | 安全连接 |
| **full** | PG + Nginx + Stunnel + pgAdmin | 443, 5433, 5050 | 完整堆栈 |

### Kubernetes 部署

- **StatefulSet**: PostgreSQL 主服务
- **Stunnel Sidecar**: 可选 TLS 隧道
- **Metrics**: 可选 Prometheus 监控
- **PVC**: 持久化存储

## 📝 使用示例

### 部署到 VM (Stunnel 模式)

```yaml
Environment: production
Deploy mode: stunnel
VM host: postgresql.svc.plus
PostgreSQL password: <使用 Secret>
```

### 部署到 Kubernetes

```yaml
Environment: production
Cluster type: k8s
Namespace: postgresql
Release name: postgresql
Enable stunnel: true
Enable metrics: true
```

## 🔍 验证部署

### VM

```bash
ssh deploy@your-vm-host
cd /opt/postgresql-svc-plus
docker-compose ps
docker-compose exec postgres pg_isready -U postgres
```

### Kubernetes

```bash
kubectl get pods -n postgresql
kubectl exec -n postgresql postgresql-0 -- pg_isready -U postgres
```

## 📚 完整文档

详细配置和故障排查请查看: [docs/guides/github-actions-cicd.md](github-actions-cicd.md)
