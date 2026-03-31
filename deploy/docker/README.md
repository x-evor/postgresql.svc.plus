# Docker Deployment Guide

This directory contains Docker Compose configurations for deploying PostgreSQL with extensions.

## Quick Start

1. **Copy environment template**:
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` file** and set secure passwords:
   ```bash
   POSTGRES_PASSWORD=your_secure_password
   ```

3. **Start PostgreSQL**:
   ```bash
   docker-compose up -d
   ```

4. **Verify deployment**:
   ```bash
   docker-compose ps
   docker-compose logs postgres
   ```

## Deployment Modes

### 1. Basic PostgreSQL Only

Default mode - just PostgreSQL with extensions:

```bash
docker-compose up -d
```

### 2. With pgAdmin (Web UI)

Include pgAdmin for database management:

```bash
docker-compose --profile admin up -d
```

Access pgAdmin at `http://localhost:5050`

### 3. With Nginx + Certbot (Automatic SSL)

Use Nginx with Certbot for automatic Let's Encrypt SSL certificates:

```bash
# Initialize SSL certificates (first time only)
chmod +x init-letsencrypt.sh
DOMAIN=db.yourdomain.com EMAIL=your@email.com ./init-letsencrypt.sh

# Start services
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml up -d
```

See [Nginx + Certbot deployment](#nginx--certbot-deployment) below.

### 4. With Caddy Reverse Proxy

Use Caddy for automatic HTTPS and reverse proxy:

```bash
docker-compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```

See [Caddy deployment](#caddy-deployment) below.

### 5. With TLS over TCP Tunnel (stunnel)

For secure TCP connections to remote databases:

```bash
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
```

See [TLS Tunnel deployment](#tls-tunnel-deployment) below.

## Testing Extensions

Connect to PostgreSQL and test extensions:

```bash
# Using docker exec
docker-compose exec postgres psql -U postgres

# Or using psql client
psql -h localhost -U postgres -d postgres
```

Then in psql:

```sql
-- Create extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_jieba;
CREATE EXTENSION IF NOT EXISTS pgmq;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS hstore;

-- List installed extensions
\dx

-- Test pgvector
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;

-- Test pg_jieba (Chinese tokenization)
SELECT * FROM to_tsvector('jiebacfg', '我爱北京天安门');

-- Test pgmq (message queue)
SELECT pgmq.create('my_queue');
SELECT pgmq.send('my_queue', '{"hello": "world"}');
SELECT * FROM pgmq.read('my_queue', 30, 1);
```

## Nginx + Certbot Deployment

Nginx with Certbot provides automatic Let's Encrypt SSL certificates with more control than Caddy.

### Prerequisites

- A domain name pointing to your server's IP address
- Ports 80 and 443 open in your firewall
- Valid email address for Let's Encrypt notifications

### Initial Setup

1. **Edit Nginx configuration**:
   
   Edit `nginx-postgres.conf` and replace `db.example.com` with your actual domain:
   
   ```nginx
   server_name your-domain.com;
   ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
   ```

2. **Initialize SSL certificates**:
   
   ```bash
   chmod +x init-letsencrypt.sh
   DOMAIN=your-domain.com EMAIL=your@email.com ./init-letsencrypt.sh
   ```
   
   This script will:
   - Create a temporary self-signed certificate
   - Start Nginx
   - Request a real Let's Encrypt certificate
   - Reload Nginx with the new certificate

3. **Start all services**:
   
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.nginx.yml up -d
   ```

### Testing Mode

For testing, use Let's Encrypt staging environment to avoid rate limits:

```bash
STAGING=1 DOMAIN=your-domain.com EMAIL=your@email.com ./init-letsencrypt.sh
```

### Certificate Management

**View certificate information**:
```bash
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml run --rm certbot certificates
```

**Manual certificate renewal**:
```bash
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml run --rm certbot renew
```

**Automatic renewal**: The certbot container checks for renewal every 12 hours automatically.

### Nginx Features

- ✅ Automatic SSL certificate issuance and renewal
- ✅ HTTP to HTTPS redirect
- ✅ HSTS support (optional)
- ✅ Health check endpoint at `/health`
- ✅ Metrics endpoint at `/metrics` (if using postgres_exporter)
- ✅ pgAdmin proxy at `/pgadmin/` (if using --profile admin)
- ✅ Gzip compression
- ✅ TLS 1.2/1.3 support

### Accessing Services

- **Health check**: `https://your-domain.com/health`
- **pgAdmin**: `https://your-domain.com/pgadmin/`
- **PostgreSQL**: Connect directly to port 5432

### Troubleshooting

**Certificate request fails**:
```bash
# Check DNS resolution
nslookup your-domain.com

# Check if ports are open
nc -zv your-domain.com 80
nc -zv your-domain.com 443

# View certbot logs
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml logs certbot
```

**Nginx won't start**:
```bash
# Test Nginx configuration
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml exec nginx nginx -t

# View Nginx logs
docker-compose -f docker-compose.yml -f docker-compose.nginx.yml logs nginx
```

## Caddy Deployment

Caddy provides automatic HTTPS with Let's Encrypt and reverse proxy capabilities.

### Configuration

Edit `Caddyfile` to customize your domain and routing:

```caddyfile
db.yourdomain.com {
    reverse_proxy postgres:5432
    tls your-email@example.com
}
```

### Start with Caddy

```bash
docker-compose -f docker-compose.yml -f docker-compose.caddy.yml up -d
```

### Benefits

- Automatic HTTPS certificates
- HTTP/2 support
- Automatic certificate renewal
- Simple configuration

## TLS Tunnel Deployment (stunnel Server)

**This is the SERVER-SIDE deployment.** Clients connect to this server using stunnel client configuration.

### Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    CLIENT SIDE (User's Machine)               │
│  App (127.0.0.1:15432) → stunnel (client) → TLS encrypted    │
└────────────────────────────────┬─────────────────────────────┘
                                 │
                          Internet (TLS)
                                 │
┌────────────────────────────────┼─────────────────────────────┐
│                    SERVER SIDE (This Deployment)              │
│  postgresql.svc.plus:443 → stunnel (server) → postgres:5432  │
└──────────────────────────────────────────────────────────────┘
```

### Use Cases

- **Secure remote PostgreSQL access** over the internet
- **TLS encryption** for all database traffic
- **Certificate-based authentication** (optional mTLS)
- **No VPN required** - direct TLS connection
- **Works through firewalls** - uses standard HTTPS port (443)

### Server-Side Setup (This Repository)

1. **Configure environment**:
   ```bash
   cp .env.example .env
   nano .env
   ```
   
   Set your domain and credentials:
   ```bash
   DOMAIN=postgresql.svc.plus
   STUNNEL_PORT=443
   POSTGRES_PASSWORD=your_secure_password
   ```

2. **Start the server**:
   ```bash
   docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d
   ```

3. **Verify stunnel is running**:
   ```bash
   docker-compose ps
   docker-compose logs stunnel
   
   # Test TLS endpoint
   openssl s_client -connect postgresql.svc.plus:443
   ```

### Certificate Management

The deployment automatically handles SSL/TLS certificates:

- **Let's Encrypt/ACME**: Automatic certificate acquisition and renewal
- **Self-signed**: For testing/development (localhost)
- **Custom certificates**: Mount your own certificates via environment variables

See [STUNNEL_GUIDE.md](./STUNNEL_GUIDE.md) for detailed certificate configuration.

### Client-Side Setup (User's Machine)

**For users connecting TO this server**, see the comprehensive client setup guide:

📖 **[CLIENT_SETUP.md](./CLIENT_SETUP.md)** - Complete client installation and configuration guide

Quick client example:

```bash
# On user's machine - create stunnel-client.conf
[postgres-client]
client = yes
accept = 127.0.0.1:15432
connect = postgresql.svc.plus:443
verify = 2
CAfile = /etc/ssl/certs/ca-certificates.crt
checkHost = postgresql.svc.plus

# Start stunnel client
docker run -d \
  -p 127.0.0.1:15432:15432 \
  -v $(pwd)/stunnel-client.conf:/etc/stunnel/stunnel.conf:ro \
  dweomer/stunnel:latest

# Connect application
psql "postgresql://postgres:PASSWORD@127.0.0.1:15432/postgres"
```

### Security Features

- ✅ **TLS 1.2/1.3** encryption
- ✅ **Certificate verification** (server and optional client)
- ✅ **Perfect Forward Secrecy** (PFS)
- ✅ **HSTS support**
- ✅ **Optional mTLS** (mutual TLS authentication)
- ✅ **Automatic certificate renewal**

### Monitoring

```bash
# Check stunnel health
docker-compose exec stunnel nc -zv 127.0.0.1 5433

# View stunnel logs
docker-compose logs -f stunnel

# Monitor connections
docker-compose exec stunnel netstat -an | grep 5433
```

### Troubleshooting

**Certificate issues**:
```bash
# Verify certificate
openssl s_client -connect postgresql.svc.plus:443 -showcerts

# Check certificate expiry
echo | openssl s_client -connect postgresql.svc.plus:443 2>/dev/null | openssl x509 -noout -dates
```

**Connection issues**:
```bash
# Test from server
docker-compose exec stunnel nc -zv postgres 5432

# Check firewall
sudo ufw status
sudo firewall-cmd --list-all

# Verify DNS
nslookup postgresql.svc.plus
```


## Data Persistence

PostgreSQL data is stored in a Docker volume:

```bash
# List volumes
docker volume ls | grep postgres

# Backup data
docker-compose exec postgres pg_dump -U postgres postgres > backup.sql

# Restore data
cat backup.sql | docker-compose exec -T postgres psql -U postgres postgres
```

## Maintenance

### View Logs

```bash
docker-compose logs -f postgres
```

### Restart Services

```bash
docker-compose restart postgres
```

### Stop Services

```bash
docker-compose down
```

### Remove All Data (⚠️ Destructive)

```bash
docker-compose down -v
```

## Performance Tuning

Edit `postgresql.conf` to tune performance:

```conf
# Memory settings
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB

# Connection settings
max_connections = 100

# Write-ahead log
wal_buffers = 16MB
checkpoint_completion_target = 0.9
```

Restart to apply changes:

```bash
docker-compose restart postgres
```

## Security Best Practices

1. **Change default passwords** in `.env`
2. **Use strong passwords** (20+ characters)
3. **Limit network exposure** - bind to localhost only if possible
4. **Enable SSL/TLS** for production deployments
5. **Regular backups** - automate with cron
6. **Update regularly** - rebuild image with latest security patches

## Troubleshooting

### Container won't start

```bash
# Check logs
docker-compose logs postgres

# Check if port is already in use
lsof -i :5432
```

### Permission issues

```bash
# Fix volume permissions
docker-compose down
docker volume rm postgresql-svc-plus_postgres_data
docker-compose up -d
```

### Connection refused

```bash
# Check if service is healthy
docker-compose ps

# Test connection from container
docker-compose exec postgres pg_isready -U postgres
```

## Next Steps

- Configure backups (see `scripts/backup.sh`)
- Set up monitoring (Prometheus + Grafana)
- Configure replication for high availability
- Implement connection pooling (PgBouncer)
