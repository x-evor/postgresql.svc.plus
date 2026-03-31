# PostgreSQL Service Plus - Simplified Makefile

.PHONY: help build-postgres-image push-postgres-image test-postgres \
        deploy-docker deploy-helm clean init reset selftest selftest-strict \
        gitleaks-detect git-purge test-local-mac test-local-macos benchmarks \
        benchmarks-case-set

# Image configuration
POSTGRES_IMAGE_NAME ?= postgres-extensions
# Build arguments
PG_MAJOR ?= 16
POSTGRES_IMAGE_TAG ?= $(PG_MAJOR)
POSTGRES_FULL_IMAGE ?= $(POSTGRES_IMAGE_NAME):$(POSTGRES_IMAGE_TAG)
PG_VERSION ?= 16.4
PG_JIEBA_VERSION ?= v2.0.1
PG_VECTOR_VERSION ?= v0.8.1
PGMQ_VERSION ?= v1.8.0

# Docker registry (customize for your environment)
DOCKER_REGISTRY ?= 
DOCKER_IMAGE ?= $(DOCKER_REGISTRY)$(POSTGRES_FULL_IMAGE)

# Benchmarks defaults
BENCH_CASE ?= scripts/benchmarks/cases/db_pgbench_mixed_default.sh
PGHOST ?= 127.0.0.1
PGPORT ?= 15432
PGUSER ?= postgres
PGDATABASE ?= postgres

help:
	@echo "PostgreSQL Service Plus - Available targets:"
	@echo ""
	@echo "  build-postgres-image  - Build the PostgreSQL runtime image with extensions"
	@echo "  push-postgres-image   - Push image to registry (set DOCKER_REGISTRY)"
	@echo "  test-postgres         - Run a test container locally"
	@echo "  init                  - Interactive initialization (DOMAIN=db.example.com)"
	@echo "  reset                 - Reset environment (clean containers, volumes, certs)"
	@echo "  selftest              - Run linting and self-tests (Mode 1)"
	@echo "  selftest-strict       - Run self-tests in strict mode (Mode 2)"
	@echo "  test-local-mac        - Run macOS local integration test"
	@echo "  test-local-macos      - Alias for test-local-mac"
	@echo "  benchmarks           - Run benchmark case (default: mixed workload via stunnel-client)"
	@echo "                         e.g. make benchmarks PGHOST=127.0.0.1 PGPORT=15432 PGUSER=postgres PGDATABASE=postgres"
	@echo "  benchmarks-case-set  - Run benchmark case set and append results to docs/benchmarks.md"
	@echo "  gitleaks-detect       - Scan for secrets in Git history"
	@echo "  git-purge             - Purge history of specific paths (e.g., make git-purge PATHS=\"file1 dir2\")"
	@echo "  deploy-docker         - Deploy using Docker Compose (legacy, use init instead)"
	@echo "  deploy-helm           - Deploy using Helm chart"
	@echo "  clean                 - Stop and remove test containers"
	@echo ""
	@echo "Configuration:"
	@echo "  POSTGRES_IMAGE_NAME   = $(POSTGRES_IMAGE_NAME)"
	@echo "  POSTGRES_IMAGE_TAG    = $(POSTGRES_IMAGE_TAG)"
	@echo "  DOCKER_REGISTRY       = $(DOCKER_REGISTRY)"
	@echo "  PG_MAJOR              = $(PG_MAJOR)"
	@echo "  PG_VERSION            = $(PG_VERSION)"
	@echo "  BENCH_CASE            = $(BENCH_CASE)"
	@echo "  PGHOST/PGPORT/PGUSER/PGDATABASE (for benchmarks, default PGPORT=15432)"
	@echo "  ENV_FILE/PGHOST/PGPORT (for benchmarks-case-set)"

build-postgres-image:
	@echo "🔨 Building PostgreSQL $(PG_VERSION) with extensions..."
	docker build \
		-f deploy/base-images/postgres-runtime-wth-extensions.Dockerfile \
		--build-arg PG_MAJOR=$(PG_MAJOR) \
		--build-arg PG_VERSION=$(PG_VERSION) \
		--build-arg PG_JIEBA_VERSION=$(PG_JIEBA_VERSION) \
		--build-arg PG_VECTOR_VERSION=$(PG_VECTOR_VERSION) \
		--build-arg PGMQ_VERSION=$(PGMQ_VERSION) \
		-t $(POSTGRES_FULL_IMAGE) \
		deploy/base-images/
	@echo "✅ Image built: $(POSTGRES_FULL_IMAGE)"

push-postgres-image: build-postgres-image
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "❌ DOCKER_REGISTRY not set. Example: make push-postgres-image DOCKER_REGISTRY=myregistry.io/"; \
		exit 1; \
	fi
	@echo "📤 Pushing $(DOCKER_IMAGE)..."
	docker tag $(POSTGRES_FULL_IMAGE) $(DOCKER_IMAGE)
	docker push $(DOCKER_IMAGE)
	@echo "✅ Image pushed: $(DOCKER_IMAGE)"

test-postgres: build-postgres-image
	@echo "🧪 Starting test PostgreSQL container..."
	docker run -d \
		--name postgres-test \
		-e POSTGRES_PASSWORD=testpass \
		-p 5432:5432 \
		$(POSTGRES_FULL_IMAGE)
	@echo "⏳ Waiting for PostgreSQL to be ready..."
	@sleep 5
	@echo "✅ Testing extensions..."
	@docker exec postgres-test psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS vector;" || true
	@docker exec postgres-test psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_jieba;" || true
	@docker exec postgres-test psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pgmq;" || true
	@docker exec postgres-test psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" || true
	@docker exec postgres-test psql -U postgres -c "\dx" | grep -E "vector|jieba|pgmq|trgm"
	@echo "✅ Test container running. Connect with:"
	@echo "   psql -h localhost -U postgres -d postgres"
	@echo "   Password: testpass"
	@echo ""
	@echo "Stop with: make clean"

deploy-docker:
	@echo "🚀 Deploying with Docker Compose..."
	cd deploy/docker && docker-compose up -d
	@echo "✅ PostgreSQL deployed. Check status with:"
	@echo "   cd deploy/docker && docker-compose ps"

deploy-helm:
	@echo "🚀 Deploying with Helm..."
	@if ! command -v helm &> /dev/null; then \
		echo "❌ Helm not found. Please install Helm first."; \
		exit 1; \
	fi
	helm upgrade --install postgresql ./deploy/helm/postgresql \
		--set image.repository=$(POSTGRES_IMAGE_NAME) \
		--set image.tag=$(POSTGRES_IMAGE_TAG) \
		--create-namespace
	@echo "✅ PostgreSQL deployed via Helm. Check status with:"
	@echo "   kubectl get pods -l app.kubernetes.io/name=postgresql"

# Automation & Tests
init:
	@bash scripts/init_vhost.sh $(PG_MAJOR) $(DOMAIN)

reset:
	@bash scripts/init_vhost.sh reset

selftest:
	@STUNNEL_CONF=example/stunnel-client.conf \
	LOCAL_PORT=15432 \
	HOST=db.example.com \
	TLS_PORT=443 \
	OUTPUT_FILES="README.md docs/PROJECT_DETAILS.md scripts/init_vhost.sh" \
	bash scripts/selftest.sh

selftest-strict:
	@# Generate temporary strict config for testing
	@sed 's/; verifyChain = yes/verifyChain = yes/' example/stunnel-client.conf | \
	 sed 's/; checkHost = db.example.com/checkHost = db.example.com/' > example/stunnel-client-strict.conf
	@STRICT=1 \
	STUNNEL_CONF=example/stunnel-client-strict.conf \
	LOCAL_PORT=15432 \
	HOST=db.example.com \
	TLS_PORT=443 \
	bash scripts/selftest.sh
	@rm example/stunnel-client-strict.conf

gitleaks-detect:
	@echo "🔍 Scanning for secrets..."
	@gitleaks detect -v

git-purge:
	@if [ -z "$(PATHS)" ]; then \
		echo "❌ Error: PATHS variable is required. Example: make git-purge PATHS=\"dir1 file2\""; \
		exit 1; \
	fi
	@bash scripts/clean_git_history.sh $(PATHS)

test-local-mac:
	@echo "🍎 Starting macOS local integration test..."
	@bash test-cases/local/macos-client/run_test.sh

test-local-macos: test-local-mac

benchmarks:
	@echo "🔧 BENCH_CASE=$(BENCH_CASE)"
	@echo "🔧 PGHOST=$(PGHOST) PGPORT=$(PGPORT) PGUSER=$(PGUSER) PGDATABASE=$(PGDATABASE)"
	PGHOST=$(PGHOST) PGPORT=$(PGPORT) \
	PGUSER=$(PGUSER) PGDATABASE=$(PGDATABASE) \
	bash $(BENCH_CASE)

benchmarks-case-set:
	@bash scripts/benchmarks/run_case_set.sh

clean:
	@echo "🧹 Cleaning up test containers..."
	-@docker stop postgres-test 2>/dev/null || true
	-@docker rm postgres-test 2>/dev/null || true
	@echo "✅ Cleanup complete"
