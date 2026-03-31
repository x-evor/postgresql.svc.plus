#!/usr/bin/env bash
set -e

IMAGE="$1"
OUT="$2"

anchore-cli sbom generate "$IMAGE" -o "$OUT"
