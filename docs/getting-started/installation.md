# 安装方式

本项目提供三种常见安装方式：本地（Docker）、单机云服务器（Vhost/TLS 隧道）、Kubernetes/Helm。

## 1) 本地开发（Docker Compose）

适合：本机验证、PoC、开发调试。

```bash
make build-postgres-image
cd deploy/docker
cp .env.example .env
# 编辑 .env（来自 .env.example）设置 POSTGRES_PASSWORD
docker-compose up -d
```

## 2) 单机云服务器（Vhost + TLS 隧道）

适合：个人/小型生产，要求域名与公网 IP。

```bash
curl -fsSL https://raw.githubusercontent.com/cloud-neutral-toolkit/postgresql.svc.plus/main/scripts/init_vhost.sh \
  | bash -s -- 16 db.example.com
```

该模式默认通过 stunnel 提供 `443` 端口的 TLS 数据库入口。

## 3) Kubernetes/Helm

适合：企业级生产与多环境部署。

```bash
helm install postgresql ./deploy/helm/postgresql \
  --set auth.password=your-secure-password \
  --set persistence.size=10Gi
```

如需启用 stunnel sidecar：

```bash
helm install postgresql ./deploy/helm/postgresql \
  --set auth.password=your-secure-password \
  --set stunnel.enabled=true \
  --set stunnel.certificatesSecret=stunnel-certs
```

## 安装后验证

```bash
psql -h localhost -U postgres -d postgres -c "\dx"
```

若列出 `vector/pg_jieba/pgmq/pg_trgm/hstore` 等扩展，即说明镜像已生效。
