# Docker Compose 部署

推荐阅读：`docs/usage/deployment.md`

## 快速启动

```bash
cd deploy/docker
cp .env.example .env
# 设置 POSTGRES_PASSWORD
docker-compose up -d
```

## 启用 stunnel

```bash
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

更多细节请参考 `deploy/docker/README.md`。
