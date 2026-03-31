#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_DIR="$ROOT_DIR/deploy/base-images"

OPENRESTY_IMAGE=${OPENRESTY_IMAGE:-xcontrol/openresty-geoip:latest}
POSTGRES_EXT_IMAGE=${POSTGRES_EXT_IMAGE:-xcontrol/postgres-extensions:16}
NODE_BUILDER_IMAGE=${NODE_BUILDER_IMAGE:-xcontrol/node-builder:22}
NODE_RUNTIME_IMAGE=${NODE_RUNTIME_IMAGE:-xcontrol/node-runtime:22}
GO_BUILDER_IMAGE=${GO_BUILDER_IMAGE:-xcontrol/go-builder:1.23}
GO_RUNTIME_IMAGE=${GO_RUNTIME_IMAGE:-xcontrol/go-runtime:1.23}

build_image() {
  local dockerfile=$1
  local tag=$2
  echo "\n🚧 Building ${tag} from ${dockerfile}"
  docker build -f "${IMAGE_DIR}/${dockerfile}" -t "${tag}" "${IMAGE_DIR}"
}

build_image "openresty-geoip.Dockerfile" "${OPENRESTY_IMAGE}"
build_image "postgres-extensions.Dockerfile" "${POSTGRES_EXT_IMAGE}"
build_image "node-builder.Dockerfile" "${NODE_BUILDER_IMAGE}"
build_image "node-runtime.Dockerfile" "${NODE_RUNTIME_IMAGE}"
build_image "go-builder.Dockerfile" "${GO_BUILDER_IMAGE}"
build_image "go-runtime.Dockerfile" "${GO_RUNTIME_IMAGE}"

echo "\n✅ Base images built successfully:"
echo " - ${OPENRESTY_IMAGE}"
echo " - ${POSTGRES_EXT_IMAGE}"
echo " - ${NODE_BUILDER_IMAGE}"
echo " - ${NODE_RUNTIME_IMAGE}"
echo " - ${GO_BUILDER_IMAGE}"
echo " - ${GO_RUNTIME_IMAGE}"
