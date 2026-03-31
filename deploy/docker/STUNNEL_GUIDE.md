# PostgreSQL TLS over TCP 隧道部署指南

## 架构说明

本部署方案确保 PostgreSQL 始终在容器内部的 `127.0.0.1:5432` 上运行,不直接暴露到外部网络。所有外部连接必须通过 **stunnel4 服务端**提供的 TLS 加密隧道访问。

```
外部客户端 (psql/应用)
    ↓ TLS 加密连接
stunnel 服务端 (0.0.0.0:5433)
    ↓ 解密后转发
PostgreSQL (容器内部 postgres:5432)
```

## 安全优势

1. **强制加密**: 所有数据库连接都经过 TLS 1.2/1.3 加密
2. **隔离保护**: PostgreSQL 不直接暴露,降低攻击面
3. **证书验证**: 支持双向 TLS 认证(可选)
4. **审计日志**: stunnel 记录所有连接日志

## 快速开始

### 1. 生成 TLS 证书

```bash
cd deploy/docker
chmod +x generate-certs.sh
./generate-certs.sh
```

这将生成:
- `certs/server-cert.pem` - 服务端证书
- `certs/server-key.pem` - 服务端私钥
- `certs/ca-cert.pem` - CA 证书(可选,用于客户端验证)

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`:
```bash
POSTGRES_PASSWORD=your_secure_password
STUNNEL_PORT=5433  # TLS 隧道端口
```

### 3. 启动服务

```bash
# 启动 PostgreSQL + stunnel 服务端
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

### 4. 验证部署

```bash
# 检查服务状态
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml ps

# 查看 stunnel 日志
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml logs stunnel

# 测试 PostgreSQL 健康状态
docker-compose exec postgres pg_isready -U postgres -h 127.0.0.1
```

## 客户端连接

### 方式 1: 使用 psql (需要 stunnel 客户端)

在客户端机器上配置 stunnel 客户端:

```ini
# stunnel-client.conf
[postgres-client]
client = yes
accept = 127.0.0.1:5432
connect = your-server.com:5433
verify = 2
CAfile = /path/to/ca-cert.pem
```

启动 stunnel 客户端:
```bash
stunnel stunnel-client.conf
```

然后连接到本地端口:
```bash
psql -h localhost -p 5432 -U postgres -d postgres
```

### 方式 2: 使用 PostgreSQL 原生 SSL (推荐)

PostgreSQL 客户端可以直接连接到 stunnel 端口:

```bash
psql "host=your-server.com port=5433 user=postgres dbname=postgres sslmode=require"
```

### 方式 3: 应用程序连接

**Python (psycopg2)**:
```python
import psycopg2

conn = psycopg2.connect(
    host="your-server.com",
    port=5433,
    user="postgres",
    password="your_password",
    database="postgres",
    sslmode="require"
)
```

**Node.js (pg)**:
```javascript
const { Client } = require('pg');

const client = new Client({
  host: 'your-server.com',
  port: 5433,
  user: 'postgres',
  password: 'your_password',
  database: 'postgres',
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('/path/to/ca-cert.pem').toString()
  }
});
```

**Go (lib/pq)**:
```go
import (
    "database/sql"
    _ "github.com/lib/pq"
)

connStr := "host=your-server.com port=5433 user=postgres password=your_password dbname=postgres sslmode=require"
db, err := sql.Open("postgres", connStr)
```

## 高级配置

### 启用客户端证书验证

编辑 `stunnel-server.conf`:

```ini
[postgres-tls-server]
client = no
accept = 0.0.0.0:5433
connect = postgres:5432

cert = /etc/stunnel/certs/server-cert.pem
key = /etc/stunnel/certs/server-key.pem

# 启用客户端证书验证
verify = 2
CAfile = /etc/stunnel/certs/ca-cert.pem

sslVersion = TLSv1.2
```

重启服务:
```bash
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml restart stunnel
```

### 自定义端口

编辑 `.env`:
```bash
STUNNEL_PORT=8443  # 使用自定义端口
```

或在启动时指定:
```bash
STUNNEL_PORT=8443 docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

### 性能调优

编辑 `stunnel-server.conf`:

```ini
# 增加会话缓存
sessionCacheSize = 10000
sessionCacheTimeout = 600

# 调整超时
TIMEOUTidle = 86400  # 24 hours

# 启用 TCP 优化
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
socket = l:SO_KEEPALIVE=1
socket = r:SO_KEEPALIVE=1
```

## 监控和日志

### 查看 stunnel 日志

```bash
# 实时日志
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml logs -f stunnel

# 查看日志文件
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml exec stunnel cat /var/log/stunnel/stunnel.log
```

### 查看活动连接

```bash
# PostgreSQL 连接
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# 容器网络连接
docker-compose exec stunnel netstat -tnp
```

### 健康检查

```bash
# 检查 stunnel 端口
nc -zv your-server.com 5433

# 使用 openssl 测试 TLS
openssl s_client -connect your-server.com:5433 -showcerts
```

## 故障排查

### stunnel 无法启动

```bash
# 检查证书文件
ls -la deploy/docker/certs/

# 查看详细日志
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml logs stunnel

# 测试配置文件
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml exec stunnel stunnel -test
```

### 连接被拒绝

```bash
# 检查端口是否开放
nc -zv your-server.com 5433

# 检查防火墙
sudo ufw status
sudo firewall-cmd --list-ports

# 检查 Docker 端口映射
docker port stunnel-server
```

### TLS 握手失败

```bash
# 测试 TLS 连接
openssl s_client -connect your-server.com:5433 -tls1_2

# 检查证书有效期
openssl x509 -in certs/server-cert.pem -noout -dates

# 验证证书链
openssl verify -CAfile certs/ca-cert.pem certs/server-cert.pem
```

### PostgreSQL 连接超时

```bash
# 检查 PostgreSQL 是否运行
docker-compose exec postgres pg_isready -U postgres

# 测试容器间网络
docker-compose exec stunnel nc -zv postgres 5432

# 查看 PostgreSQL 日志
docker-compose logs postgres
```

## 生产部署建议

1. **使用正式 CA 证书**: 从 Let's Encrypt 或商业 CA 获取证书
2. **启用客户端验证**: 使用双向 TLS 增强安全性
3. **配置防火墙**: 只开放 stunnel 端口 (5433),关闭 PostgreSQL 端口 (5432)
4. **定期更新证书**: 设置证书过期提醒
5. **监控连接**: 使用 Prometheus + Grafana 监控
6. **日志轮转**: 配置 stunnel 日志轮转
7. **备份证书**: 安全存储私钥和证书

## 与其他部署模式结合

### stunnel + Nginx

```bash
# 同时使用 Nginx 反向代理和 stunnel
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.nginx.yml \
  -f docker-compose.tunnel.yml \
  up -d
```

### stunnel + Caddy

```bash
# 同时使用 Caddy 和 stunnel
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.caddy.yml \
  -f docker-compose.tunnel.yml \
  up -d
```

### stunnel + pgAdmin

```bash
# 包含 pgAdmin 管理界面
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.tunnel.yml \
  --profile admin \
  up -d
```

## 安全检查清单

- [ ] 使用强密码 (20+ 字符)
- [ ] 生成的证书已安全存储
- [ ] 私钥文件权限设置为 600
- [ ] 启用 TLS 1.2 或更高版本
- [ ] 禁用弱加密套件
- [ ] 配置防火墙规则
- [ ] 定期更新 Docker 镜像
- [ ] 启用连接日志
- [ ] 配置自动备份
- [ ] 测试灾难恢复流程

## 参考资源

- [stunnel 官方文档](https://www.stunnel.org/docs.html)
- [PostgreSQL SSL 文档](https://www.postgresql.org/docs/current/ssl-tcp.html)
- [TLS 最佳实践](https://wiki.mozilla.org/Security/Server_Side_TLS)
- [Docker 网络](https://docs.docker.com/network/)
