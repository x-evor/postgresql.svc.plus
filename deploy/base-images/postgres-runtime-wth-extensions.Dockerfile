# ---------------------------------------------------------
# Version Definitions
# ---------------------------------------------------------
ARG PG_MAJOR=16
ARG PG_VERSION=16.4

# ---------------------------------------------------------
# Stage 1 — Build Extensions
# ---------------------------------------------------------
FROM postgres:${PG_MAJOR}-bookworm AS builder
ARG PG_MAJOR
ARG PG_JIEBA_VERSION=v2.0.1
ARG PG_VECTOR_VERSION=v0.8.1
ARG PGMQ_VERSION=v1.8.0

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    pkg-config \
    libicu-dev \
    postgresql-server-dev-${PG_MAJOR} \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# Build pg_jieba
# ---------------------------------------------------------
RUN tmp=$(mktemp -d) && \
    git clone --branch "${PG_JIEBA_VERSION}" \
    https://github.com/jaiminpan/pg_jieba.git "$tmp/pg_jieba" && \
    cd "$tmp/pg_jieba" && \
    git submodule update --init --recursive || true && \
    ln -s "$tmp/pg_jieba/third_party/cppjieba" "$tmp/pg_jieba/cppjieba" && \
    cmake -S "$tmp/pg_jieba" \
    -B "$tmp/pg_jieba/build" \
    -DPostgreSQL_TYPE_INCLUDE_DIR=/usr/include/postgresql/${PG_MAJOR}/server && \
    cmake --build "$tmp/pg_jieba/build" --config Release -- -j"$(nproc)" && \
    cmake --install "$tmp/pg_jieba/build" && \
    rm -rf "$tmp"

# ---------------------------------------------------------
# Build pgmq
# ---------------------------------------------------------
RUN tmp=$(mktemp -d) && \
    git clone --depth 1 --branch "${PGMQ_VERSION}" \
    https://github.com/tembo-io/pgmq.git "$tmp/pgmq" && \
    cd "$tmp/pgmq/pgmq-extension" && \
    make && make install && \
    rm -rf "$tmp"

# ---------------------------------------------------------
# Build pgvector
# ---------------------------------------------------------
RUN tmp=$(mktemp -d) && \
    git clone --depth 1 --branch "${PG_VECTOR_VERSION}" \
    https://github.com/pgvector/pgvector.git "$tmp/pgvector" && \
    cd "$tmp/pgvector" && \
    make && make install && \
    rm -rf "$tmp"

# ---------------------------------------------------------
# Stage 2 — Runtime
# ---------------------------------------------------------
FROM postgres:${PG_MAJOR}-bookworm

ARG PG_MAJOR
ARG PG_VERSION

LABEL maintainer="Cloud-Neutral Toolkit" \
    description="PostgreSQL ${PG_VERSION} + pgvector + pg_jieba + pgmq (Debian 12 Bookworm Base)"

# Copy .so + extension files from builder
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/ /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/ /usr/share/postgresql/${PG_MAJOR}/extension/

# Fix collation version mismatch warning automatically on startup
# We simply create a small script that the official entrypoint will run
RUN echo '#!/bin/bash\n\
    set -e\n\
    echo "Fixing collation version mismatch..."\n\
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "ALTER DATABASE $POSTGRES_DB REFRESH COLLATION VERSION;" || true\n\
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "template1" -c "ALTER DATABASE template1 REFRESH COLLATION VERSION;" || true\n\
    echo "Collation fix complete."' > /docker-entrypoint-initdb.d/fix-collation.sh && \
    chmod +x /docker-entrypoint-initdb.d/fix-collation.sh
