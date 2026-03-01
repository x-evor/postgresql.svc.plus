#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🍎 macOS Local Integration Test${NC}"
echo "=============================="

# Check requirements
if ! command -v stunnel &> /dev/null; then
    echo -e "${RED}❌ stunnel not found. Please install: brew install stunnel${NC}"
    exit 1
fi
if ! command -v psql &> /dev/null; then
    echo -e "${RED}❌ psql not found. Please install: brew install libpq${NC}"
    exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
STUNNEL_CONF="$DIR/stunnel.conf"
SQL_FILE="$DIR/verify_extensions.sql"
REMOTE_HOST="${REMOTE_HOST:-postgresql-aws.svc.plus}"
REMOTE_PORT="${REMOTE_PORT:-5443}"
LOCAL_PORT="${LOCAL_PORT:-15432}"

# Build an effective stunnel config with optional overrides
STUNNEL_CONF_EFFECTIVE="$STUNNEL_CONF"
TMP_CONF=""
CAFILE=""
for p in /etc/ssl/cert.pem \
         /usr/local/etc/openssl@3/cert.pem \
         /opt/homebrew/etc/openssl@3/cert.pem \
         /usr/local/etc/openssl@1.1/cert.pem \
         /opt/homebrew/etc/openssl@1.1/cert.pem; do
    if [ -f "$p" ]; then
        CAFILE="$p"
        break
    fi
done

if [ -n "$CAFILE" ] || [ -n "${STUNNEL_INSECURE:-}" ]; then
    TMP_CONF="$(mktemp /tmp/stunnel-conf.XXXXXX)"
    cp "$STUNNEL_CONF" "$TMP_CONF"
    if [ -n "$CAFILE" ]; then
        perl -0pi -e "s|^CAfile\\s*=.*$|CAfile = $CAFILE|m" "$TMP_CONF"
        echo "🔐 Using CA bundle: $CAFILE"
    fi
    if [ -n "${STUNNEL_INSECURE:-}" ]; then
        perl -0pi -e 's|^verify\\s*=.*$|verify = 0|m; s|^checkHost\\s*=|; checkHost =|m' "$TMP_CONF"
        echo "⚠️  STUNNEL_INSECURE=1 set: TLS verification disabled"
    fi
    STUNNEL_CONF_EFFECTIVE="$TMP_CONF"
fi

# Apply runtime endpoint overrides (host/port/local port).
if [ -z "$TMP_CONF" ]; then
    TMP_CONF="$(mktemp /tmp/stunnel-conf.XXXXXX)"
    cp "$STUNNEL_CONF" "$TMP_CONF"
    STUNNEL_CONF_EFFECTIVE="$TMP_CONF"
fi
perl -0pi -e "s|^accept\\s*=.*$|accept = 127.0.0.1:${LOCAL_PORT}|m" "$STUNNEL_CONF_EFFECTIVE"
perl -0pi -e "s|^connect\\s*=.*$|connect = ${REMOTE_HOST}:${REMOTE_PORT}|m" "$STUNNEL_CONF_EFFECTIVE"
perl -0pi -e "s|^sni\\s*=.*$|sni = ${REMOTE_HOST}|m" "$STUNNEL_CONF_EFFECTIVE"
perl -0pi -e "s|^checkHost\\s*=.*$|checkHost = ${REMOTE_HOST}|m" "$STUNNEL_CONF_EFFECTIVE"

# Check if local tunnel port is free
if lsof -i :"$LOCAL_PORT" >/dev/null; then
    echo -e "${RED}❌ Port ${LOCAL_PORT} is already in use. Please free it first (e.g., kill running stunnel).${NC}"
    exit 1
fi

echo "🚀 Starting Stunnel..."
stunnel "$STUNNEL_CONF_EFFECTIVE" > /tmp/stunnel-test-stdout.log 2>&1 &
STUNNEL_PID=$!
echo "📝 Stunnel PID: $STUNNEL_PID"

cleanup() {
    echo ""
    echo "🛑 Stopping Stunnel..."
    kill $STUNNEL_PID 2>/dev/null || true
    if [ -n "$TMP_CONF" ] && [ -f "$TMP_CONF" ]; then
        rm -f "$TMP_CONF"
    fi
    echo "🧹 Done."
}
trap cleanup EXIT

echo "⏳ Waiting for tunnel to initialize (2s)..."
sleep 2

# Check if process is still running (ps may be restricted)
if ! ps -p $STUNNEL_PID >/dev/null 2>&1; then
    if ! kill -0 $STUNNEL_PID 2>/dev/null; then
        echo -e "${RED}❌ Stunnel failed to start. Check logs:${NC}"
        cat /tmp/stunnel-test-mac.log
        exit 1
    fi
fi

if ! kill -0 $STUNNEL_PID 2>/dev/null; then
    echo -e "${RED}❌ Stunnel failed to start. Check logs:${NC}"
    cat /tmp/stunnel-test-mac.log
    exit 1
fi

echo "🧪 Running SQL Tests..."
echo "Target: localhost:${LOCAL_PORT} -> ${REMOTE_HOST}:${REMOTE_PORT}"

# Resolve password in this order:
# 1) exported PGPASSWORD
# 2) POSTGRES_PASSWORD from repo .env files
# 3) backward-compatible fallback
resolve_pg_password() {
    if [ -n "${PGPASSWORD:-}" ]; then
        echo "$PGPASSWORD"
        return 0
    fi

    local script_dir repo_root env_file pw
    script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    repo_root="$( cd "$script_dir/../../.." && pwd )"
    for env_file in "$repo_root/.env" "$repo_root/deploy/docker/.env"; do
        if [ -f "$env_file" ]; then
            pw="$(sed -n 's/^POSTGRES_PASSWORD=//p' "$env_file" | tail -n 1 | tr -d '\r')"
            if [ -n "$pw" ]; then
                # Strip optional wrapping quotes
                pw="${pw%\"}"
                pw="${pw#\"}"
                pw="${pw%\'}"
                pw="${pw#\'}"
                echo "🔐 Using POSTGRES_PASSWORD from $env_file" >&2
                echo "$pw"
                return 0
            fi
        fi
    done

    echo "otdcRLTJamszk3AE"
}

PGPASSWORD_RESOLVED="$(resolve_pg_password)"
export PGPASSWORD="$PGPASSWORD_RESOLVED"
export PGHOST=127.0.0.1
export PGPORT="${LOCAL_PORT}"
export PGUSER="${PGUSER:-postgres}"
export PGDATABASE="${PGDATABASE:-postgres}"

run_sql_tests() {
    psql -f "$SQL_FILE" 2>/tmp/psql-test-mac.err
}

if run_sql_tests; then
    echo ""
    echo -e "${GREEN}✅ ALL TESTS PASSED SUCCESSFULLY!${NC}"
else
    if grep -qi "password authentication failed" /tmp/psql-test-mac.err 2>/dev/null; then
        echo "⚠️  Password auth failed. Trying source host password from root@postgresql.svc.plus..."
        if command -v ssh >/dev/null 2>&1; then
            SOURCE_PASS="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@postgresql.svc.plus "docker inspect postgresql-svc-plus --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^POSTGRES_PASSWORD=//p' | head -n1" 2>/dev/null || true)"
            if [ -n "$SOURCE_PASS" ]; then
                export PGPASSWORD="$SOURCE_PASS"
                if run_sql_tests; then
                    echo ""
                    echo -e "${GREEN}✅ ALL TESTS PASSED SUCCESSFULLY!${NC}"
                    exit 0
                fi
            fi
        fi
    fi
    cat /tmp/psql-test-mac.err 2>/dev/null || true
    echo ""
    echo -e "${RED}❌ TESTS FAILED.${NC}"
    exit 1
fi
