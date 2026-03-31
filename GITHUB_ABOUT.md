# PostgreSQL Service Plus

Production-ready PostgreSQL runtime with vector search, Chinese tokenization, and message queue extensions. Flexible deployment with high-performance TLS tunneling.

## 🎯 Core Features

**Multi-Model Database** - Replace multiple specialized databases with one PostgreSQL:
- **pgvector** (0.8.1) - Vector embeddings and semantic search
- **pg_jieba** (2.0.1) - Chinese full-text tokenization  
- **pgmq** (1.8.0) - Lightweight message queue
- **JSONB + GIN** - Document store
- **hstore** - Key-value cache

## 🏗️ Architecture

**Two-Layer Security Design:**

1. **Certificate Management** (Nginx/Caddy)
   - Auto HTTPS for domains (e.g., `postgresql.svc.plus`)
   - Not tied to zero-trust platforms
   - Does NOT proxy SQL traffic

2. **Database Access** (Stunnel)
   - HTTPS endpoint (port 5433) for database connections
   - Avoids PostgreSQL sslmode performance overhead
   - PostgreSQL runs at maximum performance (no SSL overhead)

```
Client App → Stunnel Client (localhost:15432) 
          → TLS Encrypted 
          → Stunnel Server (5433) 
          → PostgreSQL (127.0.0.1:5432, no SSL)
```

## 🚀 Deployment Modes

| Mode | Complexity | HTTPS | TLS Tunnel | Use Case |
|------|-----------|-------|-----------|----------|
| Basic + Stunnel | ⭐ | ❌ | ✅ | Development |
| Nginx + Certbot | ⭐⭐ | ✅ Auto | ✅ | Small Production |
| Caddy | ⭐⭐ | ✅ Auto | ✅ | Small Production |
| Kubernetes/Helm | ⭐⭐⭐ | Manual | ✅ | Enterprise |

## 📦 Quick Start

```bash
# 1. Build image
make build-postgres-image

# 2. Generate certificates
cd deploy/docker && ./generate-certs.sh

# 3. Start services (PostgreSQL + Stunnel)
docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d

# 4. Connect (through TLS tunnel)
psql "host=localhost port=5433 user=postgres dbname=postgres"
```

## 🔐 Security

- ✅ PostgreSQL isolated (127.0.0.1:5432 only)
- ✅ Forced TLS 1.2/1.3 encryption
- ✅ Network isolation
- ✅ Flexible certificate management (not platform-locked)
- ✅ Optional mutual TLS authentication

## ⚡ Performance

**Why Stunnel instead of PostgreSQL sslmode?**

| Approach | PostgreSQL CPU | TLS Handling | Performance |
|----------|---------------|--------------|-------------|
| PostgreSQL sslmode | SQL + TLS | PostgreSQL | ⚠️ Slower |
| **Stunnel (This)** | **SQL only** | **Stunnel** | **✅ Faster** |

## 📚 Documentation

- [Quick Start](docs/QUICKSTART.md)
- [Architecture Design](docs/ARCHITECTURE.md)
- [Docker Deployment](docs/deployment/docker-deployment.md)
- [Helm Deployment](docs/deployment/helm-deployment.md)
- [Stunnel Server Guide](docs/guides/stunnel-server.md)
- [Stunnel Client Guide](docs/guides/stunnel-client.md)

## 🛠️ Technology Stack

- PostgreSQL 16.4 (PGDG)
- Extensions: pgvector, pg_jieba, pgmq
- TLS Tunnel: stunnel4
- Reverse Proxy: Nginx + Certbot or Caddy
- Orchestration: Docker Compose or Kubernetes/Helm

## 📝 License

MIT License

---

**One PostgreSQL, Replace Multiple Databases** 🚀
