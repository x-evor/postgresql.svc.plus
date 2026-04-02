# Base container images

This directory provides Dockerfiles for the foundational images used across the
project. Each image is designed to keep commonly reused dependencies bundled so
service-specific images can build faster and remain consistent.

## Available images

- **OpenResty + GeoIP** (`openresty-geoip.Dockerfile`): OpenResty with GeoIP2
  libraries and `lua-resty-maxminddb` for MaxMind database lookups.
- **PostgreSQL 16 + extensions** (`postgres-runtime-wth-extensions.Dockerfile`): PostgreSQL
  with `pgvector`, `pg_jieba`, and `pg_cache` compiled into the server for
  vector search and full-text tokenization.
- **Go 1.23 builder** (`go-builder.Dockerfile`): Ubuntu 24.04 with the Go
  toolchain and build dependencies for the Account service and RAG server.
- **Go runtime** (`go-runtime.Dockerfile`): Slim Ubuntu 24.04 runtime with CA
  certificates for running statically linked Go binaries.
- **Node.js builder** (`node-builder.Dockerfile`): Node.js 22 with Yarn, the
  latest npm, and build essentials for compiling native Next.js dependencies.
- **Node.js runtime** (`node-runtime.Dockerfile`): Slim Node.js 22 runtime ready
  for production Next.js deployments.
- **stunnel runtime** (`stunnel.Dockerfile`): Minimal stunnel image for
  PostgreSQL TLS tunnel service (inspired by
  [`dweomer/dockerfiles-stunnel`](https://github.com/dweomer/dockerfiles-stunnel),
  supports ARM64/AMD64 via Buildx).

## Build commands

You can build all base images at once via the repository `Makefile`:

```bash
make build-base-images
```

Or build individual images manually:

```bash
# OpenResty with GeoIP
make docker-openresty-geoip

# PostgreSQL 16 with extensions
make docker-postgres-extensions

# Node.js builder (Node 22 + Yarn)
make docker-node-builder

# Node.js 22 runtime
make docker-node-runtime

# stunnel runtime (local build)
docker build -f deploy/base-images/stunnel.Dockerfile -t stunnel-runtime:local deploy/base-images

# stunnel runtime (arm64 local build)
docker buildx build --platform linux/arm64/v8 \
  -f deploy/base-images/stunnel.Dockerfile \
  -t stunnel-runtime:arm64-local \
  --load \
  deploy/base-images

# stunnel runtime (multi-arch push)
docker buildx build --platform linux/amd64,linux/arm64/v8 \
  -f deploy/base-images/stunnel.Dockerfile \
  -t <registry>/stunnel-runtime:latest \
  --push \
  deploy/base-images
```

Each target accepts an optional tag override, for example:

```bash
make docker-postgres-extensions POSTGRES_EXT_IMAGE=my-registry/postgresql-svc-plus:16

# Go builder (Go 1.23 + build tools)
make docker-go-builder GO_BUILDER_IMAGE=my-registry/go-builder:1.23

# Go runtime (Ubuntu 24.04 + CA certificates)
make docker-go-runtime GO_RUNTIME_IMAGE=my-registry/go-runtime:1.23
```
