# GitHub Actions CI/CD 配置指南

本项目包含三个 GitHub Actions 工作流,支持自动化构建、测试和部署。

## 📋 工作流概览

| 工作流 | 文件 | 触发条件 | 用途 |
|--------|------|---------|------|
| Build Image | `build-image.yml` | Push/PR | 构建并推送 PostgreSQL 镜像 |
| Deploy to VM | `deploy-vm.yml` | 手动触发 | 部署到虚拟机 |
| Deploy to K8s | `deploy-k8s.yml` | 手动触发 | 部署到 Kubernetes/K3s |

## 🔧 前置配置

### 1. GitHub Secrets 配置

在 GitHub 仓库设置中添加以下 Secrets:

#### VM 部署所需:

```
SSH_PRIVATE_KEY       # SSH 私钥 (用于连接 VM)
DOMAIN                # 域名 (如: postgresql.svc.plus)
CERTBOT_EMAIL         # Let's Encrypt 邮箱
```

#### Kubernetes 部署所需:

```
KUBECONFIG            # Kubernetes 配置文件 (base64 编码)
POSTGRES_PASSWORD     # PostgreSQL 密码
STUNNEL_CERT          # Stunnel 服务端证书 (可选)
STUNNEL_KEY           # Stunnel 服务端私钥 (可选)
PVC_SIZE              # 持久化存储大小 (默认: 10Gi)
STORAGE_CLASS         # 存储类 (可选)
MEMORY_REQUEST        # 内存请求 (默认: 1Gi)
MEMORY_LIMIT          # 内存限制 (默认: 2Gi)
CPU_REQUEST           # CPU 请求 (默认: 500m)
CPU_LIMIT             # CPU 限制 (默认: 2000m)
```

### 2. 准备 KUBECONFIG

```bash
# 获取 kubeconfig 并 base64 编码
cat ~/.kube/config | base64 | tr -d '\n'

# 或者使用 kubectl
kubectl config view --raw | base64 | tr -d '\n'
```

将输出添加到 GitHub Secrets 的 `KUBECONFIG`。

### 3. 准备 SSH 密钥 (VM 部署)

```bash
# 生成 SSH 密钥对
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_deploy

# 复制公钥到目标 VM
ssh-copy-id -i ~/.ssh/github_deploy.pub deploy@your-vm-host

# 复制私钥内容到 GitHub Secrets
cat ~/.ssh/github_deploy
```

将私钥内容添加到 GitHub Secrets 的 `SSH_PRIVATE_KEY`。

## 🚀 使用方法

### 工作流 1: 构建并发布镜像

**自动触发**:
- Push 到 `main` 或 `develop` 分支
- PR 到 `main` 分支
- 修改 Dockerfile

**手动触发**:
1. 访问 Actions 页面
2. 选择 "Build And Push GHCR Image PostgreSQL"
3. 点击 "Run workflow"
4. 可选: 指定 PostgreSQL 版本

**输出**:
- 镜像推送到 GitHub Container Registry
- 镜像地址: `ghcr.io/x-evor/images/postgresql:latest`

### 工作流 2: 部署到 VM

**触发方式**: 手动触发

**步骤**:
1. 访问 Actions → "Deploy to VM"
2. 点击 "Run workflow"
3. 填写参数:
   - **Environment**: development/staging/production
   - **Deploy mode**: 
     - `basic` - 基础 PostgreSQL
     - `nginx-certbot` - Nginx + Let's Encrypt
     - `caddy` - Caddy 自动 HTTPS
     - `stunnel` - Stunnel TLS 隧道
     - `full` - 完整堆栈 (Nginx + Stunnel + pgAdmin)
   - **VM host**: 目标 VM 的 IP 或域名
   - **PostgreSQL password**: 数据库密码

**部署模式说明**:

#### Basic 模式
```bash
docker-compose up -d
```
- 只部署 PostgreSQL
- 端口: 5432 (内部)

#### Nginx + Certbot 模式
```bash
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml up -d
```
- PostgreSQL + Nginx + Let's Encrypt
- 端口: 443 (HTTPS), 5432 (内部)
- 自动申请 SSL 证书

#### Caddy 模式
```bash
docker-compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```
- PostgreSQL + Caddy
- 端口: 443 (HTTPS), 5432 (内部)
- 零配置自动 HTTPS

#### Stunnel 模式
```bash
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```
- PostgreSQL + Stunnel TLS 隧道
- 端口: 5433 (TLS), 5432 (内部)
- 高性能加密连接

#### Full 模式
```bash
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.nginx.yml \
  -f docker-compose.tunnel.yml \
  --profile admin \
  up -d
```
- 完整堆栈: PostgreSQL + Nginx + Stunnel + pgAdmin
- 端口: 443 (HTTPS), 5433 (TLS), 5050 (pgAdmin)

### 工作流 3: 部署到 Kubernetes

**触发方式**: 手动触发

**步骤**:
1. 访问 Actions → "Deploy to Kubernetes"
2. 点击 "Run workflow"
3. 填写参数:
   - **Environment**: development/staging/production
   - **Cluster type**: k8s 或 k3s
   - **Namespace**: Kubernetes 命名空间 (默认: postgresql)
   - **Release name**: Helm release 名称 (默认: postgresql)
   - **Enable stunnel**: 是否启用 Stunnel sidecar
   - **Enable metrics**: 是否启用 Prometheus metrics

**部署内容**:
- StatefulSet (PostgreSQL)
- Service (ClusterIP)
- PersistentVolumeClaim
- ConfigMap (配置和初始化脚本)
- Secret (密码)
- 可选: Stunnel sidecar
- 可选: Metrics exporter

**连接方式**:

```bash
# 端口转发
kubectl port-forward -n postgresql svc/postgresql 5432:5432

# 或通过 Stunnel (如果启用)
kubectl port-forward -n postgresql svc/postgresql 5433:5433

# 集群内部连接
postgresql.postgresql.svc.cluster.local:5432
```

## 📊 部署验证

### VM 部署验证

```bash
# SSH 到 VM
ssh deploy@your-vm-host

# 检查容器状态
cd /opt/postgresql-svc-plus
docker-compose ps

# 测试数据库连接
docker-compose exec postgres pg_isready -U postgres

# 检查扩展
docker-compose exec postgres psql -U postgres -c "\dx"
```

### Kubernetes 部署验证

```bash
# 检查 Pod 状态
kubectl get pods -n postgresql

# 检查服务
kubectl get svc -n postgresql

# 测试连接
kubectl exec -n postgresql postgresql-0 -- pg_isready -U postgres

# 检查扩展
kubectl exec -n postgresql postgresql-0 -- psql -U postgres -c "\dx"
```

## 🔐 安全最佳实践

1. **使用 GitHub Environments**
   - 为 development/staging/production 创建不同的 Environment
   - 配置 Environment-specific secrets
   - 启用 Environment protection rules

2. **密码管理**
   - 生产环境必须使用 GitHub Secrets
   - 不要在工作流文件中硬编码密码
   - 定期轮换密码

3. **SSH 密钥**
   - 使用专用的 SSH 密钥对
   - 限制密钥权限 (只读或特定命令)
   - 定期轮换密钥

4. **Kubeconfig**
   - 使用 ServiceAccount 而不是个人凭证
   - 限制 RBAC 权限
   - 定期审计访问日志

## 🛠️ 故障排查

### 镜像构建失败

```bash
# 检查 Dockerfile 语法
docker build -f deploy/base-images/postgres-runtime-wth-extensions.Dockerfile .

# 查看 Actions 日志
# GitHub → Actions → 选择失败的工作流 → 查看详细日志
```

### VM 部署失败

**常见问题**:

1. **SSH 连接失败**
   - 检查 SSH_PRIVATE_KEY 是否正确
   - 确认 VM 防火墙允许 SSH (22)
   - 验证 deploy 用户存在且有权限

2. **Docker 命令失败**
   - 确认 deploy 用户在 docker 组
   - 检查 Docker 是否运行: `systemctl status docker`

3. **证书申请失败**
   - 确认域名 DNS 解析正确
   - 检查防火墙开放 80 和 443 端口
   - 查看 certbot 日志

### Kubernetes 部署失败

**常见问题**:

1. **KUBECONFIG 无效**
   - 重新生成并 base64 编码
   - 确认 kubeconfig 有正确的权限

2. **PVC 创建失败**
   - 检查 StorageClass 是否存在
   - 确认有足够的存储空间

3. **Pod 启动失败**
   - 检查镜像是否可访问
   - 查看 Pod 日志: `kubectl logs -n postgresql postgresql-0`
   - 检查资源限制是否合理

## 📝 自定义工作流

### 添加自定义部署步骤

编辑 `.github/workflows/deploy-vm.yml`:

```yaml
- name: Custom deployment step
  run: |
    ssh -i ~/.ssh/deploy_key ${{ env.DEPLOY_USER }}@${{ github.event.inputs.vm_host }} << 'EOF'
      # 你的自定义命令
      cd ${{ env.DEPLOY_PATH }}
      # 例如: 运行数据库迁移
      docker-compose exec -T postgres psql -U postgres -f /path/to/migration.sql
    EOF
```

### 添加通知

在工作流末尾添加:

```yaml
- name: Notify on success
  if: success()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment to ${{ github.event.inputs.environment }} succeeded!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}

- name: Notify on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'Deployment to ${{ github.event.inputs.environment }} failed!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🔄 持续集成流程

推荐的 CI/CD 流程:

```
1. 开发 → Push to feature branch
   ↓
2. 自动触发: Build Image (测试构建)
   ↓
3. 创建 PR to main
   ↓
4. 自动触发: Build Image (测试 + 扩展验证)
   ↓
5. PR 合并 to main
   ↓
6. 自动触发: Build Image (构建并推送 latest)
   ↓
7. 手动触发: Deploy to VM/K8s (development)
   ↓
8. 测试验证
   ↓
9. 手动触发: Deploy to VM/K8s (staging)
   ↓
10. 生产验证
    ↓
11. 手动触发: Deploy to VM/K8s (production)
```

## 📚 参考资源

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [Helm 文档](https://helm.sh/docs/)
- [Kubernetes 文档](https://kubernetes.io/docs/)
