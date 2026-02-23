#!/usr/bin/env bash
set -euo pipefail

SOURCE_HOST="root@postgresql.svc.plus"
TARGET_HOST="ubuntu@57.183.19.25"
SOURCE_DOMAIN="postgresql.svc.plus"
TARGET_DOMAIN="postgresql.svc.plus"
PG_MAJOR="17"
PG_USER="postgres"
SOURCE_CONTAINER="postgresql-svc-plus"
TARGET_CONTAINER="postgresql-svc-plus"
TARGET_REPO="/root/postgresql.svc.plus"
TARGET_TLS_PORT="5443"
LOCAL_WORKDIR="/tmp/pg-migration"
KEEP_LOCAL_DUMP="false"
SKIP_INIT="false"
SKIP_IMPORT="false"
SKIP_COMPARE="false"
IMPORT_GLOBALS="false"
INIT_DB="false"
SOURCE_PG_PASSWORD=""
ACME_MODE="auto"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [SRC_HOST] [DEST_HOST] [options]

Options:
  SRC_HOST                    Optional positional source SSH, e.g. root@postgresql.svc.plus
  DEST_HOST                   Optional positional target SSH, e.g. ubuntu@57.183.19.25
  --source-host <ssh>        Source host SSH (default: ${SOURCE_HOST})
  --target-host <ssh>        Target host SSH (default: ${TARGET_HOST})
  --source-domain <domain>   Source service domain (default: ${SOURCE_DOMAIN})
  --target-domain <domain>   Target service domain for init/cert (default: ${TARGET_DOMAIN})
  --domain <domain>          Alias of --target-domain (backward compatibility)
  --pg-major <ver>           PostgreSQL major version for target init (default: ${PG_MAJOR})
  --pg-user <user>           PostgreSQL superuser for dump/import (default: ${PG_USER})
  --source-container <name>  Source postgres container (default: ${SOURCE_CONTAINER})
  --target-container <name>  Target postgres container (default: ${TARGET_CONTAINER})
  --target-repo <path>       Target repo path (default: ${TARGET_REPO})
  --target-tls-port <port>   Target TLS port (default: ${TARGET_TLS_PORT})
  --keep-local-dump          Keep local dump bundle under ${LOCAL_WORKDIR}
  --skip-init                Skip target initialization stage
  --init-db                  Force run target init stage via scripts/init_vhost.sh
  --acme-mode <mode>        ACME mode: auto|bootstrap|host-caddy (default: ${ACME_MODE})
  --skip-import              Skip dump transfer/import stage
  --skip-compare             Skip source/target compare stage
  --import-globals           Import globals.sql (roles/tablespaces); default is off
  -h, --help                 Show this help
USAGE
}

log() { printf '[%s] %s\n' "$(date +'%F %T')" "$*"; }
err() { printf '[%s] ERROR: %s\n' "$(date +'%F %T')" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }
}

run_ssh() {
  local host="$1"
  shift
  ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$host" "$@"
}

run_scp() {
  scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 "$@"
}

retry_cmd() {
  local attempts="${1:-5}"
  shift
  local n=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [[ "$n" -ge "$attempts" ]]; then
      return 1
    fi
    n=$((n + 1))
    sleep 3
  done
}

parse_args() {
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source-host) SOURCE_HOST="$2"; shift 2 ;;
      --target-host) TARGET_HOST="$2"; shift 2 ;;
      --source-domain) SOURCE_DOMAIN="$2"; shift 2 ;;
      --target-domain) TARGET_DOMAIN="$2"; shift 2 ;;
      --domain) TARGET_DOMAIN="$2"; shift 2 ;;
      --pg-major) PG_MAJOR="$2"; shift 2 ;;
      --pg-user) PG_USER="$2"; shift 2 ;;
      --source-container) SOURCE_CONTAINER="$2"; shift 2 ;;
      --target-container) TARGET_CONTAINER="$2"; shift 2 ;;
      --target-repo) TARGET_REPO="$2"; shift 2 ;;
      --target-tls-port) TARGET_TLS_PORT="$2"; shift 2 ;;
      --keep-local-dump) KEEP_LOCAL_DUMP="true"; shift ;;
      --skip-init) SKIP_INIT="true"; shift ;;
      --init-db) INIT_DB="true"; shift ;;
      --acme-mode) ACME_MODE="$2"; shift 2 ;;
      --skip-import) SKIP_IMPORT="true"; shift ;;
      --skip-compare) SKIP_COMPARE="true"; shift ;;
      --import-globals) IMPORT_GLOBALS="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*)
        err "Unknown argument: $1"
        usage
        exit 1
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  if [[ "${#positional[@]}" -ge 1 ]]; then
    SOURCE_HOST="${positional[0]}"
  fi
  if [[ "${#positional[@]}" -ge 2 ]]; then
    TARGET_HOST="${positional[1]}"
  fi
  if [[ "${#positional[@]}" -gt 2 ]]; then
    err "Too many positional arguments. Use: $(basename "$0") [SRC] [DEST] [options]"
    exit 1
  fi
}

preflight() {
  require_cmd ssh
  require_cmd scp
  mkdir -p "$LOCAL_WORKDIR"

  log "Checking SSH connectivity"
  run_ssh "$SOURCE_HOST" "echo source-ok: \$(hostname)"
  run_ssh "$TARGET_HOST" "echo target-ok: \$(hostname)"

  log "Reading source admin credentials from source container env"
  local src_user
  local src_pass
  src_user="$(retry_cmd 5 run_ssh "$SOURCE_HOST" "docker inspect '$SOURCE_CONTAINER' --format '{{range .Config.Env}}{{println .}}{{end}}' | awk -F= '/^POSTGRES_USER=/{print \$2; exit}'" || true)"
  src_pass="$(retry_cmd 5 run_ssh "$SOURCE_HOST" "docker inspect '$SOURCE_CONTAINER' --format '{{range .Config.Env}}{{println .}}{{end}}' | awk -F= '/^POSTGRES_PASSWORD=/{print \$2; exit}'" || true)"

  if [[ -n "$src_user" ]]; then
    PG_USER="$src_user"
  fi
  if [[ -n "$src_pass" ]]; then
    SOURCE_PG_PASSWORD="$src_pass"
  fi
}

init_target() {
  log "[1/5] Initializing target host with init_vhost.sh (acme-mode=${ACME_MODE})"
  case "$ACME_MODE" in
    auto|bootstrap|host-caddy) ;;
    *) err "Invalid --acme-mode: $ACME_MODE (use auto|bootstrap|host-caddy)"; return 1 ;;
  esac

  if ! run_ssh "$TARGET_HOST" "sudo DEBIAN_FRONTEND=noninteractive bash -lc 'if [ -x ${TARGET_REPO}/scripts/init_vhost.sh ]; then ${TARGET_REPO}/scripts/init_vhost.sh ${PG_MAJOR} ${TARGET_DOMAIN} ${ACME_MODE}; else curl -fsSL https://raw.githubusercontent.com/cloud-neutral-toolkit/postgresql.svc.plus/main/scripts/init_vhost.sh | bash -s -- ${PG_MAJOR} ${TARGET_DOMAIN} ${ACME_MODE}; fi'"; then
    log "WARN: init_vhost failed, attempting ACME auto-fix"
    run_ssh "$TARGET_HOST" "sudo bash -s" <<EOS
set -euo pipefail
repo="$TARGET_REPO"
domain="$TARGET_DOMAIN"
acme_mode="$ACME_MODE"
cd "\$repo/deploy/docker"

[ -f .env ] || cp .env.example .env
if grep -q '^DOMAIN=' .env; then
  sed -i "s/^DOMAIN=.*/DOMAIN=\$domain/" .env
else
  echo "DOMAIN=\$domain" >> .env
fi
if ! grep -q '^EMAIL=' .env; then
  echo "EMAIL=admin@\${domain}" >> .env
fi

crt=""
key=""
find_cert() {
  local d="\$1"
  for base in \
    "/var/lib/docker/volumes/caddy_data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory" \
    "/var/lib/docker/volumes/docker_caddy_data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory" \
    "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory"; do
    if [ -f "\$base/\$d/\$d.crt" ] && [ -f "\$base/\$d/\$d.key" ]; then
      crt="\$base/\$d/\$d.crt"
      key="\$base/\$d/\$d.key"
      return 0
    fi
  done
  if [ -f "/etc/letsencrypt/live/\$d/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/\$d/privkey.pem" ]; then
    crt="/etc/letsencrypt/live/\$d/fullchain.pem"
    key="/etc/letsencrypt/live/\$d/privkey.pem"
    return 0
  fi
  return 1
}

if [ "\$acme_mode" = "host-caddy" ] || { [ "\$acme_mode" = "auto" ] && systemctl is-active --quiet caddy; }; then
  mkdir -p /etc/caddy/conf.d
  cat > "/etc/caddy/conf.d/postgresql-\$domain.caddy" <<EOC
\$domain {
  respond "postgresql.svc.plus ACME endpoint" 200
}
EOC
  if ! grep -q "/etc/caddy/conf.d/\\*.caddy" /etc/caddy/Caddyfile 2>/dev/null; then
    echo "" >> /etc/caddy/Caddyfile
    echo "import /etc/caddy/conf.d/*.caddy" >> /etc/caddy/Caddyfile
  fi
  systemctl reload caddy || systemctl restart caddy
  for i in \$(seq 1 24); do
    find_cert "\$domain" && break
    sleep 10
  done
else
  docker volume create caddy_data >/dev/null 2>&1 || true
  docker compose -f docker-compose.bootstrap.yml down --remove-orphans || true
  docker compose -f docker-compose.bootstrap.yml up -d --remove-orphans
  for i in \$(seq 1 18); do
    find_cert "\$domain" && break
    sleep 10
  done
  docker compose -f docker-compose.bootstrap.yml down --remove-orphans || true
fi

if [ -z "\$crt" ] || [ -z "\$key" ]; then
  echo "ACME auto-fix failed: certificate for \$domain not found" >&2
  exit 1
fi

if grep -q '^STUNNEL_CRT_FILE=' .env; then
  sed -i "s|^STUNNEL_CRT_FILE=.*|STUNNEL_CRT_FILE=\$crt|" .env
else
  echo "STUNNEL_CRT_FILE=\$crt" >> .env
fi
if grep -q '^STUNNEL_KEY_FILE=' .env; then
  sed -i "s|^STUNNEL_KEY_FILE=.*|STUNNEL_KEY_FILE=\$key|" .env
else
  echo "STUNNEL_KEY_FILE=\$key" >> .env
fi
EOS
  fi

  log "Enforcing target TLS port=${TARGET_TLS_PORT} and aligning admin user/password with source"
  run_ssh "$TARGET_HOST" "sudo bash -s" <<EOS
set -euo pipefail
cd "$TARGET_REPO"
ENV_FILE="deploy/docker/.env"
[ -f "\$ENV_FILE" ] || cp deploy/docker/.env.example "\$ENV_FILE"
if grep -q '^POSTGRES_USER=' "\$ENV_FILE"; then
  sed -i "s/^POSTGRES_USER=.*/POSTGRES_USER=${PG_USER}/" "\$ENV_FILE"
else
  echo "POSTGRES_USER=${PG_USER}" >> "\$ENV_FILE"
fi
if [ -n "${SOURCE_PG_PASSWORD}" ]; then
  if grep -q '^POSTGRES_PASSWORD=' "\$ENV_FILE"; then
    sed -i "s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=${SOURCE_PG_PASSWORD}/" "\$ENV_FILE"
  else
    echo "POSTGRES_PASSWORD=${SOURCE_PG_PASSWORD}" >> "\$ENV_FILE"
  fi
fi
if grep -q '^STUNNEL_PORT=' "\$ENV_FILE"; then
  sed -i 's/^STUNNEL_PORT=.*/STUNNEL_PORT=${TARGET_TLS_PORT}/' "\$ENV_FILE"
else
  echo 'STUNNEL_PORT=${TARGET_TLS_PORT}' >> "\$ENV_FILE"
fi
cd deploy/docker
mode="$(awk -F= '/^STUNNEL_MODE=/{print \$2; exit}' .env || true)"
if [ "\$mode" = "host-stunnel4" ]; then
  docker compose -f docker-compose.yml up -d postgres
  systemctl restart stunnel4 || true
else
  docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d postgres stunnel
fi
EOS
}

export_from_source() {
  TIMESTAMP="$(date +%F_%H%M%S)"
  BUNDLE_NAME="bundle_${TIMESTAMP}"
  SRC_BUNDLE_DIR="/root/migration-backup/${BUNDLE_NAME}"
  LOCAL_BUNDLE_DIR="${LOCAL_WORKDIR}/${BUNDLE_NAME}"

  log "[2/5] Exporting source into bundle: ${SRC_BUNDLE_DIR}"
  run_ssh "$SOURCE_HOST" "sudo bash -s" <<EOS
set -euo pipefail
bundle_dir="$SRC_BUNDLE_DIR"
pg_user="$PG_USER"
container="$SOURCE_CONTAINER"

mkdir -p "\$bundle_dir"

docker exec "\$container" pg_dumpall -U "\$pg_user" --globals-only > "\$bundle_dir/globals.sql"

docker exec "\$container" psql -U "\$pg_user" -Atc "select datname from pg_database where datistemplate=false order by 1" > "\$bundle_dir/db.list"
: > "\$bundle_dir/manifest.tsv"
echo "===== db.list ====="
cat "\$bundle_dir/db.list"
echo "==================="

while read -r db; do
  [ -n "\$db" ] || continue
  err_file="\$bundle_dir/\${db}.err"
  force_fallback="false"
  if docker exec "\$container" psql -U "\$pg_user" -d "\$db" -Atc "select 1 from pg_extension where extname='pg_jieba' limit 1" | grep -q 1; then
    force_fallback="true"
  fi

  if [ "\$force_fallback" != "true" ] && docker exec "\$container" sh -lc "pg_dump -U '\$pg_user' -d '\$db' -Fc" > "\$bundle_dir/\${db}.dump" 2>"\$err_file"; then
    echo "\$db|custom|\${db}.dump" >> "\$bundle_dir/manifest.tsv"
    rm -f "\$err_file"
    continue
  fi

  if [ "\$force_fallback" = "true" ] || grep -q "pg_ts_config_map" "\$err_file"; then
    if [ "\$force_fallback" = "true" ]; then
      echo "fallback on \$db due to pg_jieba extension presence" >&2
    else
      echo "fallback on \$db due to pg_ts_config_map" >&2
    fi

    docker exec "\$container" psql -U "\$pg_user" -d "\$db" -Atc "select 'CREATE EXTENSION IF NOT EXISTS '||quote_ident(e.extname)||' WITH SCHEMA '||quote_ident(n.nspname)||';' from pg_extension e join pg_namespace n on n.oid=e.extnamespace where e.extname not in ('plpgsql','pg_jieba') order by 1" > "\$bundle_dir/\${db}.extensions.sql"
    if docker exec "\$container" psql -U "\$pg_user" -d "\$db" -Atc "select 1 from pg_extension where extname='pg_jieba' limit 1" | grep -q 1; then
      cat >> "\$bundle_dir/\${db}.extensions.sql" <<'SQL'
DO \$\$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_ts_config c
    JOIN pg_namespace n ON n.oid = c.cfgnamespace
    WHERE n.nspname = 'public' AND c.cfgname = 'jieba_search'
  ) THEN
    CREATE TEXT SEARCH CONFIGURATION public.jieba_search (COPY = pg_catalog.simple);
  END IF;
END \$\$;
SQL
    fi

    docker exec "\$container" sh -lc "table_args=\\\$(psql -U '\$pg_user' -d '\$db' -Atc \"select quote_ident(schemaname)||'.'||quote_ident(tablename) from pg_tables where schemaname not in ('pg_catalog','information_schema') order by 1\" | sed 's/^/-t /' | tr '\\n' ' '); pg_dump -U '\$pg_user' -d '\$db' --schema-only \\\$table_args" > "\$bundle_dir/\${db}.schema.sql"

    docker exec "\$container" sh -lc "pg_dump -U '\$pg_user' -d '\$db' --data-only --inserts" > "\$bundle_dir/\${db}.data.sql"

    echo "\$db|fallback|\${db}.extensions.sql|\${db}.schema.sql|\${db}.data.sql" >> "\$bundle_dir/manifest.tsv"
    continue
  fi

  echo "export failed on db=\$db" >&2
  cat "\$err_file" >&2
  exit 1
done < "\$bundle_dir/db.list"

sha256sum "\$bundle_dir"/* > "\$bundle_dir/SHA256SUMS"
ls -lah "\$bundle_dir"
EOS

  log "Downloading bundle from source"
  rm -rf "$LOCAL_BUNDLE_DIR"
  mkdir -p "$LOCAL_BUNDLE_DIR"
  retry_cmd 5 run_scp -q -r "${SOURCE_HOST}:${SRC_BUNDLE_DIR}/." "$LOCAL_BUNDLE_DIR/"

  BUNDLE_NAME="$BUNDLE_NAME"
  LOCAL_BUNDLE_DIR="$LOCAL_BUNDLE_DIR"
}

import_to_target() {
  TARGET_IMPORT_ROOT="/root/migration-backup"
  TARGET_STAGE_ROOT="/home/ubuntu/migration-backup"
  TARGET_BUNDLE_DIR="${TARGET_IMPORT_ROOT}/${BUNDLE_NAME}"

  log "[3/5] Uploading bundle to target: ${TARGET_BUNDLE_DIR}"
  run_ssh "$TARGET_HOST" "mkdir -p '$TARGET_STAGE_ROOT'"
  retry_cmd 5 run_scp -q -r "$LOCAL_BUNDLE_DIR" "${TARGET_HOST}:${TARGET_STAGE_ROOT}/"
  run_ssh "$TARGET_HOST" "sudo mkdir -p '$TARGET_IMPORT_ROOT' && sudo rm -rf '$TARGET_BUNDLE_DIR' && sudo mv '${TARGET_STAGE_ROOT}/${BUNDLE_NAME}' '$TARGET_BUNDLE_DIR'"

  log "Importing bundle into target"
  run_ssh "$TARGET_HOST" "sudo bash -s" <<EOS
set -euo pipefail
bundle_dir="$TARGET_BUNDLE_DIR"
pg_user="$PG_USER"
container="$TARGET_CONTAINER"

cd "$TARGET_REPO/deploy/docker"
docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d postgres

if [ "$IMPORT_GLOBALS" = "true" ]; then
  cat "\$bundle_dir/globals.sql" | docker exec -i "\$container" psql -U "\$pg_user" -d postgres || true
fi

while IFS='|' read -r db mode f1 f2 f3; do
  [ -n "\$db" ] || continue

  if [ "\$db" != "postgres" ]; then
    docker exec "\$container" psql -U "\$pg_user" -d postgres -c "select pg_terminate_backend(pid) from pg_stat_activity where datname='\$db' and pid <> pg_backend_pid();" >/dev/null || true
    docker exec "\$container" dropdb -U "\$pg_user" --if-exists "\$db" || true
    docker exec "\$container" createdb -U "\$pg_user" "\$db"
  fi

  if [ "\$mode" = "custom" ]; then
    cat "\$bundle_dir/\$f1" | docker exec -i "\$container" pg_restore -U "\$pg_user" -d "\$db" --clean --if-exists --no-owner --no-privileges
  elif [ "\$mode" = "fallback" ]; then
    cat "\$bundle_dir/\$f1" | docker exec -i "\$container" psql -U "\$pg_user" -d "\$db" -v ON_ERROR_STOP=1
    cat "\$bundle_dir/\$f2" | docker exec -i "\$container" psql -U "\$pg_user" -d "\$db" -v ON_ERROR_STOP=1
    cat "\$bundle_dir/\$f3" | docker exec -i "\$container" psql -U "\$pg_user" -d "\$db" -v ON_ERROR_STOP=1
  else
    echo "unknown mode: \$mode" >&2
    exit 1
  fi
done < "\$bundle_dir/manifest.tsv"
EOS
}

collect_summary_source() {
  local out_file="$1"
  run_ssh "$SOURCE_HOST" "sudo bash -s" <<'EOS' > "$out_file"
set -euo pipefail
container="postgresql-svc-plus"
pg_user="postgres"

docker exec "$container" psql -U "$pg_user" -Atc "select datname from pg_database where datistemplate=false order by 1" \
| while read -r db; do
  size_bytes=$(docker exec "$container" psql -U "$pg_user" -d "$db" -Atc "select pg_database_size(current_database());")
  table_count=$(docker exec "$container" psql -U "$pg_user" -d "$db" -Atc "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema');")
  est_rows=$(docker exec "$container" psql -U "$pg_user" -d "$db" -Atc "select coalesce(sum(n_live_tup)::bigint,0) from pg_stat_user_tables;")
  echo "${db}|${size_bytes}|${table_count}|${est_rows}"
done | sort
EOS
}

collect_summary_target() {
  local out_file="$1"
  run_ssh "$TARGET_HOST" "sudo bash -s" <<EOS > "$out_file"
set -euo pipefail
cd "$TARGET_REPO/deploy/docker"
container="$TARGET_CONTAINER"
pg_user="$PG_USER"

docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d postgres >/dev/null

docker exec "\$container" psql -U "\$pg_user" -Atc "select datname from pg_database where datistemplate=false order by 1" \
| while read -r db; do
  size_bytes=\$(docker exec "\$container" psql -U "\$pg_user" -d "\$db" -Atc "select pg_database_size(current_database());")
  table_count=\$(docker exec "\$container" psql -U "\$pg_user" -d "\$db" -Atc "select count(*) from information_schema.tables where table_schema not in ('pg_catalog','information_schema');")
  est_rows=\$(docker exec "\$container" psql -U "\$pg_user" -d "\$db" -Atc "select coalesce(sum(n_live_tup)::bigint,0) from pg_stat_user_tables;")
  echo "\${db}|\${size_bytes}|\${table_count}|\${est_rows}"
done | sort
EOS
}

compare_source_target() {
  local src_summary="$LOCAL_WORKDIR/source_summary.txt"
  local tgt_summary="$LOCAL_WORKDIR/target_summary.txt"

  log "[4/5] Collecting source summary"
  collect_summary_source "$src_summary"

  log "[4/5] Collecting target summary"
  collect_summary_target "$tgt_summary"

  log "[4/5] Comparing source vs target"
  if diff -u "$src_summary" "$tgt_summary" >/dev/null; then
    log "Validation PASS: source and target summaries match"
  else
    err "Validation WARN: source/target summaries differ"
    diff -u "$src_summary" "$tgt_summary" || true
    err "Review differences before DNS cutover"
  fi

  log "Source summary: $src_summary"
  log "Target summary: $tgt_summary"
}

dns_cutover_notice() {
  log "[5/5] DNS cutover reminder"
  cat <<DNS

Next step: DNS cutover
1. Source domain: ${SOURCE_DOMAIN}
2. Target domain: ${TARGET_DOMAIN}
3. If keeping same business domain, update A/AAAA of ${SOURCE_DOMAIN} to target host IP (expected: 57.183.19.25).
4. If using independent target domain, switch app connection host from ${SOURCE_DOMAIN} to ${TARGET_DOMAIN}.
5. Wait for DNS TTL expiration and verify:
   - dig +short ${TARGET_DOMAIN}
   - psql "host=${TARGET_DOMAIN} port=${TARGET_TLS_PORT} user=${PG_USER} dbname=postgres sslmode=require"
6. After DNS points to target, re-run target init to acquire ACME cert for ${TARGET_DOMAIN} if needed.

DNS
}

cleanup() {
  if [[ "$KEEP_LOCAL_DUMP" != "true" && -n "${LOCAL_BUNDLE_DIR:-}" && -d "$LOCAL_BUNDLE_DIR" ]]; then
    rm -rf "$LOCAL_BUNDLE_DIR" || true
  fi
}

main() {
  parse_args "$@"
  preflight

  if [[ "$INIT_DB" == "true" ]]; then
    init_target
  elif [[ "$SKIP_INIT" != "true" ]]; then
    init_target
  else
    log "Skipping target initialization (--skip-init)"
  fi

  if [[ "$SKIP_IMPORT" != "true" ]]; then
    export_from_source
    import_to_target
  else
    log "Skipping import stage (--skip-import)"
  fi

  if [[ "$SKIP_COMPARE" != "true" ]]; then
    compare_source_target
  else
    log "Skipping compare stage (--skip-compare)"
  fi

  dns_cutover_notice
  cleanup

  log "Migration flow completed"
}

main "$@"
