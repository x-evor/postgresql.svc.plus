# PostgreSQL TLS Client Setup Guide

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLIENT SIDE (Your Machine)                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  Your App (localhost:15432)                                              │
│         ↓                                                                 │
│  stunnel client (127.0.0.1:15432)                                        │
│         ↓                                                                 │
│  TLS Encrypted Connection                                                │
│         ↓                                                                 │
└─────────┼─────────────────────────────────────────────────────────────────┘
          │
          │ Internet (TLS encrypted)
          │
┌─────────┼─────────────────────────────────────────────────────────────────┐
│         ↓                                                                 │
│  postgresql.svc.plus:443 (TLS endpoint)                                  │
│         ↓                                                                 │
│  stunnel server                                                           │
│         ↓                                                                 │
│  PostgreSQL (internal:5432)                                               │
│                                                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                         SERVER SIDE (Remote)                             │
└─────────────────────────────────────────────────────────────────────────┘
```

## Quick Start (Docker)

### Option 1: Using Docker Compose (Recommended)

1. **Create `docker-compose.client.yml`**:
```yaml
services:
  stunnel-client:
    image: dweomer/stunnel:latest
    container_name: stunnel-client
    restart: always
    
    environment:
      - REMOTE_HOST=postgresql.svc.plus
      - REMOTE_PORT=443
    
    volumes:
      - ./stunnel-client.conf:/etc/stunnel/stunnel.conf:ro
    
    ports:
      - "127.0.0.1:15432:15432"
    
    healthcheck:
      test: [ "CMD-SHELL", "nc -z 127.0.0.1 15432 || exit 1" ]
      interval: 10s
      timeout: 5s
      retries: 3
```

2. **Create `stunnel-client.conf`**:
```ini
foreground = yes
debug = 5

[postgres-client]
client = yes
accept = 0.0.0.0:15432
connect = postgresql.svc.plus:443

; Verify server certificate
verify = 2
CAfile = /etc/ssl/certs/ca-certificates.crt
checkHost = postgresql.svc.plus

; Performance tuning
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
socket = l:SO_KEEPALIVE=1
socket = r:SO_KEEPALIVE=1

TIMEOUTclose = 0
TIMEOUTidle = 43200
```

3. **Start the client**:
```bash
docker compose -f docker-compose.client.yml up -d
```

4. **Connect your application**:
```bash
# Connection string
postgres://postgres:YOUR_PASSWORD@127.0.0.1:15432/postgres

# Using psql
psql "postgresql://postgres:YOUR_PASSWORD@127.0.0.1:15432/postgres"

# Using environment variables
export PGHOST=127.0.0.1
export PGPORT=15432
export PGUSER=postgres
export PGPASSWORD=YOUR_PASSWORD
export PGDATABASE=postgres
psql
```

### Option 2: Using Docker Run

```bash
# Create stunnel-client.conf first (see above)

docker run -d \
  --name stunnel-client \
  --restart always \
  -p 127.0.0.1:15432:15432 \
  -v $(pwd)/stunnel-client.conf:/etc/stunnel/stunnel.conf:ro \
  -e REMOTE_HOST=postgresql.svc.plus \
  -e REMOTE_PORT=443 \
  dweomer/stunnel:latest
```

## Native Installation

### Ubuntu/Debian

```bash
# Install stunnel
sudo apt update
sudo apt install stunnel4

# Create config
sudo nano /etc/stunnel/postgres-client.conf

# Paste the config (see stunnel-client.conf above)

# Enable stunnel
sudo systemctl enable stunnel4
sudo systemctl start stunnel4

# Check status
sudo systemctl status stunnel4
```

### macOS (Homebrew)

```bash
# Install stunnel
brew install stunnel

# Create config
mkdir -p ~/.stunnel
nano ~/.stunnel/postgres-client.conf

# Paste the config (see stunnel-client.conf above)

# Start stunnel
stunnel ~/.stunnel/postgres-client.conf

# Or use launchd for auto-start
# Create ~/Library/LaunchAgents/com.stunnel.postgres.plist
```

### Rocky Linux / RHEL / CentOS

```bash
# Install stunnel
sudo dnf install stunnel

# Create config
sudo nano /etc/stunnel/postgres-client.conf

# Enable and start
sudo systemctl enable stunnel
sudo systemctl start stunnel

# Check status
sudo systemctl status stunnel
```

## Verification

### Test the tunnel

```bash
# Check if stunnel is listening
nc -zv 127.0.0.1 15432

# Or using telnet
telnet 127.0.0.1 15432

# Test PostgreSQL connection
psql "postgresql://postgres:YOUR_PASSWORD@127.0.0.1:15432/postgres" -c "SELECT version();"
```

### Check stunnel logs

```bash
# Docker
docker logs stunnel-client

# Native (Ubuntu/Debian)
sudo journalctl -u stunnel4 -f

# Native (macOS)
tail -f /var/log/stunnel.log
```

## Troubleshooting

### Connection refused

```bash
# Check if stunnel is running
docker ps | grep stunnel-client
# or
sudo systemctl status stunnel4

# Check if port is listening
sudo netstat -tlnp | grep 15432
# or
sudo lsof -i :15432
```

### Certificate verification failed

```bash
# Update CA certificates
# Ubuntu/Debian
sudo apt update && sudo apt install ca-certificates
sudo update-ca-certificates

# macOS
brew install ca-certificates

# Rocky/RHEL
sudo dnf install ca-certificates
sudo update-ca-trust
```

### DNS resolution issues

```bash
# Test DNS resolution
nslookup postgresql.svc.plus
dig postgresql.svc.plus

# Test direct connection (should work)
openssl s_client -connect postgresql.svc.plus:443
```

## Security Best Practices

1. **Always verify server certificates** (`verify = 2`)
2. **Use checkHost** to prevent MITM attacks
3. **Keep stunnel updated** for security patches
4. **Bind to localhost only** (`127.0.0.1:15432`) to prevent external access
5. **Use strong passwords** for PostgreSQL authentication
6. **Consider mTLS** for additional security (requires server-side configuration)

## Advanced Configuration

### Using custom CA certificates

If the server uses a private CA:

```ini
[postgres-client]
client = yes
accept = 0.0.0.0:15432
connect = postgresql.svc.plus:443
verify = 2
CAfile = /path/to/custom-ca.crt
checkHost = postgresql.svc.plus
```

### mTLS (Mutual TLS)

If the server requires client certificates:

```ini
[postgres-client]
client = yes
accept = 0.0.0.0:15432
connect = postgresql.svc.plus:443
verify = 2
CAfile = /etc/ssl/certs/ca-certificates.crt
checkHost = postgresql.svc.plus

; Client certificate
cert = /path/to/client-cert.pem
key = /path/to/client-key.pem
```

### Multiple database connections

```ini
; Database 1
[postgres-db1]
client = yes
accept = 127.0.0.1:15432
connect = db1.example.com:443
verify = 2
CAfile = /etc/ssl/certs/ca-certificates.crt
checkHost = db1.example.com

; Database 2
[postgres-db2]
client = yes
accept = 127.0.0.1:15433
connect = db2.example.com:443
verify = 2
CAfile = /etc/ssl/certs/ca-certificates.crt
checkHost = db2.example.com
```

## Performance Tuning

### Connection pooling

Use connection pooling in your application (e.g., PgBouncer) between your app and the local stunnel endpoint:

```
App → PgBouncer (localhost:6432) → stunnel (localhost:15432) → Server
```

### TCP tuning

For high-throughput scenarios, adjust TCP buffer sizes:

```ini
[postgres-client]
; ... other settings ...
socket = l:SO_RCVBUF=65536
socket = l:SO_SNDBUF=65536
socket = r:SO_RCVBUF=65536
socket = r:SO_SNDBUF=65536
```

## References

- [Stunnel Documentation](https://www.stunnel.org/docs.html)
- [PostgreSQL Connection Strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING)
- [TLS Best Practices](https://wiki.mozilla.org/Security/Server_Side_TLS)
