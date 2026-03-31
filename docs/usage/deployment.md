# 部署方式

## 1) VM / 单机（Docker Compose）

### 最小部署（仅 PostgreSQL）

```bash
cd deploy/docker
cp .env.example .env
# 设置 POSTGRES_PASSWORD
docker-compose up -d
```

### 启用 stunnel 服务端（推荐）

```bash
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

如需自签名证书，可先执行：

```bash
cd deploy/docker
bash generate-certs.sh
```

### 证书管理（可选）

- Caddy：`docker-compose -f docker-compose.yml -f docker-compose.caddy.yml up -d`
- Nginx + Certbot：`docker-compose -f docker-compose.yml -f docker-compose.nginx.yml up -d`

### 可选：pgAdmin 管理界面

```bash
cd deploy/docker
docker-compose --profile admin up -d
```

## 2) 云服务器一键部署（Vhost）

```bash
bash scripts/init_vhost.sh 16 db.example.com
```

默认会启用 stunnel（对外 5443，可按需改回 443）。

## 3) Kubernetes / Helm

```bash
helm install postgresql ./deploy/helm/postgresql \
  --set auth.password=your-secure-password \
  --set persistence.size=10Gi
```

启用 stunnel sidecar：

```bash
helm install postgresql ./deploy/helm/postgresql \
  --set auth.password=your-secure-password \
  --set stunnel.enabled=true \
  --set stunnel.certificatesSecret=stunnel-certs
```

## 端口与安全建议

- PostgreSQL 内部仅监听 `5432`。
- 对外 TLS 入口默认使用 `5443`（同机融合推荐）。
- 生产环境建议开放 80/5443（证书签发 + TLS 连接）。

## 与 `jp-xhttp` 同机部署建议

若同一节点已运行 `caddy/xray/xray-tcp`（占用 `80/443/1443`），建议将 stunnel 外部端口调整为 `5443`，避免 443 端口冲突:

```bash
cd deploy/docker
cp .env.example .env
# 保留容器内部 5433，只调整宿主机入口
STUNNEL_PORT=5443
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

详细步骤见: `docs/operations/node-consolidation-migration.md`。
