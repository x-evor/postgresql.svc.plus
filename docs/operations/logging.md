# 日志

## Docker Compose

- PostgreSQL：`docker-compose logs -f postgres`
- stunnel：`docker-compose logs -f stunnel`
- Caddy：`docker-compose logs -f caddy`
- Nginx/Certbot：`docker-compose logs -f nginx` / `certbot`

## stunnel 日志目录

- 默认挂载：`stunnel_logs` 卷
- 容器内路径：`/var/log/stunnel`
