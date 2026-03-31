# 开发环境搭建

## 依赖

- Docker / Docker Compose
- Make

## 本地构建与启动

```bash
make build-postgres-image
cd deploy/docker
cp .env.example .env
# 设置 POSTGRES_PASSWORD
docker-compose up -d
```

## 本地验证

```bash
make test-postgres
```
