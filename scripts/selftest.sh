#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configurable inputs
# =========================
HOST="${HOST:-postgresql.svc.plus}"
TLS_PORT="${TLS_PORT:-5433}"        # remote stunnel server port
LOCAL_PORT="${LOCAL_PORT:-5432}"    # local stunnel accept port
STUNNEL_CONF="${STUNNEL_CONF:-./stunnel.conf}"   # path to generated stunnel client config
OUTPUT_FILES="${OUTPUT_FILES:-./README.md ./output.txt}"  # files to lint (space-separated)
STUNNEL_CA_FILE="${STUNNEL_CA_FILE:-}"           # optional, required for private/self-signed CA
STRICT="${STRICT:-0}"                             # 1 = enforce verifyChain+checkHost lint & test
DOCKER_COMPOSE="${DOCKER_COMPOSE:-docker compose}" # or "docker-compose"
COMPOSE_FILE="${COMPOSE_FILE:-}"                  # optional: -f docker-compose.yml
STUNNEL_CONTAINER_NAME="${STUNNEL_CONTAINER_NAME:-stunnel-client}" # if compose defines it
TIMEOUT_SEC="${TIMEOUT_SEC:-15}"

# =========================
# Helpers
# =========================
fail() { echo "❌ FAIL: $*" >&2; exit 1; }
warn() { echo "⚠️  WARN: $*" >&2; }
ok()   { echo "✅ $*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}

has_file() {
  [[ -f "$1" ]] || fail "Missing file: $1"
}

grep_forbid() {
  local pat="$1"; shift
  local target="$1"; shift
  if grep -RIn --binary-files=without-match -E "$pat" $target >/dev/null 2>&1; then
    echo "---- Forbidden pattern matched: $pat in $target ----" >&2
    grep -RIn --binary-files=without-match -E "$pat" $target >&2 || true
    fail "Forbidden content detected"
  fi
}

grep_require() {
  local pat="$1"; shift
  local file="$1"; shift
  grep -E "$pat" "$file" >/dev/null 2>&1 || fail "Required pattern not found in $file: $pat"
}

compose_up_if_present() {
  if [[ -f "docker-compose.yml" || -f "compose.yml" || -n "$COMPOSE_FILE" ]]; then
    ok "Compose file detected; bringing up services..."
    local fargs=()
    if [[ -n "$COMPOSE_FILE" ]]; then
      fargs=(-f "$COMPOSE_FILE")
    fi
    $DOCKER_COMPOSE "${fargs[@]}" up -d
  else
    warn "No compose file detected; skipping docker-compose checks."
  fi
}

check_container_running() {
  local name="$1"
  if docker ps --format '{{.Names}}' | grep -qx "$name"; then
    ok "Container is running: $name"
  else
    warn "Container not found running: $name (skipping container-specific checks)"
    return 1
  fi

  local status
  status="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)"
  [[ "$status" == "running" ]] || fail "Container $name status is '$status' (expected running)"

  local restarting
  restarting="$(docker inspect -f '{{.State.Restarting}}' "$name" 2>/dev/null || true)"
  [[ "$restarting" == "false" ]] || fail "Container $name is restarting"
}

check_listen_inside_container() {
  local name="$1"
  ok "Checking listening ports inside container: $name"
  # try ss, fallback netstat
  if docker exec "$name" sh -lc "command -v ss >/dev/null 2>&1"; then
    docker exec "$name" sh -lc "ss -lnt | grep -E ':(\b$LOCAL_PORT\b|\b$TLS_PORT\b)' || true"
  elif docker exec "$name" sh -lc "command -v netstat >/dev/null 2>&1"; then
    docker exec "$name" sh -lc "netstat -lnt | grep -E ':(\b$LOCAL_PORT\b|\b$TLS_PORT\b)' || true"
  else
    warn "Neither ss nor netstat found in container; cannot verify listen ports inside container."
  fi
}

openssl_handshake() {
  need_cmd openssl
  ok "TLS handshake test to ${HOST}:${TLS_PORT}"

  local cafile_args=()
  if [[ -n "$STUNNEL_CA_FILE" ]]; then
    has_file "$STUNNEL_CA_FILE"
    cafile_args=(-CAfile "$STUNNEL_CA_FILE" -verify_return_error)
  else
    # no CAfile provided; rely on system trust.
    cafile_args=()
    warn "STUNNEL_CA_FILE not set: relying on system trust store for openssl test."
  fi

  # Always set SNI servername to HOST (safe even without strict checkHost).
  # Timeout to avoid hanging.
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SEC" openssl s_client -connect "${HOST}:${TLS_PORT}" -servername "$HOST" "${cafile_args[@]}" </dev/null >/tmp/openssl_s_client.out 2>&1 \
      || fail "openssl s_client failed (see /tmp/openssl_s_client.out)"
  else
    openssl s_client -connect "${HOST}:${TLS_PORT}" -servername "$HOST" "${cafile_args[@]}" </dev/null >/tmp/openssl_s_client.out 2>&1 \
      || fail "openssl s_client failed (see /tmp/openssl_s_client.out)"
  fi

  # Basic success markers
  grep -q "Verify return code: 0 (ok)" /tmp/openssl_s_client.out || warn "openssl verify did not return 0 (ok). Check /tmp/openssl_s_client.out"
  ok "openssl s_client completed"
}

lint_outputs() {
  ok "Linting generated outputs..."

  # Lint endpoint scheme: forbid https:// for stunnel endpoints
  for f in $OUTPUT_FILES; do
    [[ -f "$f" ]] || continue
    grep_forbid 'https://[^[:space:]]+:[0-9]+' "$f"
  done
  ok "No https:// stunnel endpoint misuse detected"

  # Lint stunnel config exists and contains default requirements
  has_file "$STUNNEL_CONF"
  grep_require '^\s*\[postgres-client\]\s*$' "$STUNNEL_CONF"
  grep_require '^\s*client\s*=\s*yes\s*$' "$STUNNEL_CONF"
  grep_require "^\s*accept\s*=\s*127\.0\.0\.1:${LOCAL_PORT}\s*$" "$STUNNEL_CONF"
  grep_require "^\s*connect\s*=\s*.*$HOST.*:.*$TLS_PORT.*$" "$STUNNEL_CONF"
  grep_require '^\s*verify\s*=\s*2\s*$' "$STUNNEL_CONF"

  # Default forbids advanced options unless STRICT=1 is explicitly used for this run
  if [[ "$STRICT" != "1" ]]; then
    grep_forbid '^\s*cert\s*=' "$STUNNEL_CONF"
    grep_forbid '^\s*key\s*=' "$STUNNEL_CONF"
    grep_forbid '^\s*verifyChain\s*=' "$STUNNEL_CONF"
    grep_forbid '^\s*checkHost\s*=' "$STUNNEL_CONF"
    ok "Default mode: no mTLS/strict options present"
  else
    # strict run expects verifyChain+checkHost (but still forbids cert/key)
    grep_require '^\s*verifyChain\s*=\s*yes\s*$' "$STUNNEL_CONF"
    grep_require "^\s*checkHost\s*=\s*${HOST}\s*$" "$STUNNEL_CONF"
    grep_forbid '^\s*cert\s*=' "$STUNNEL_CONF"
    grep_forbid '^\s*key\s*=' "$STUNNEL_CONF"
    ok "Strict mode lint passed (no mTLS, strict verification enabled)"
  fi

  # CAfile option
  if grep '^\s*CAfile\s*=' "$STUNNEL_CONF" >/dev/null 2>&1; then
    ok "CAfile is present in config"
  else
    ok "CAfile is not present (relying on system trust)"
  fi
}

# =========================
# Main Execution
# =========================
main() {
  lint_outputs
  # compose_up_if_present
  # check_container_running "$STUNNEL_CONTAINER_NAME"
  # openssl_handshake
  ok "All tests passed!"
}

main "$@"
