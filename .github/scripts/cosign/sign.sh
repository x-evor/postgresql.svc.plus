#!/usr/bin/env bash
set -e

REG="ghcr.io/cloud-neutral-toolkit"

cosign sign --yes "$REG/node-builder@$NODE_BUILDER_DIGEST"
cosign sign --yes "$REG/node-runtime@$NODE_RUNTIME_DIGEST"
cosign sign --yes "$REG/openresty-geoip@$OPENRESTY_GEOIP_DIGEST"
cosign sign --yes "$REG/postgres-runtime@$POSTGRES_RUNTIME_DIGEST"
