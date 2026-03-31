#!/usr/bin/env bash
# scripts/init_vhost.sh
#
# init_vhost.sh - One-shell initialization for Vhost mode (PostgreSQL + Stunnel)
#
# Supported OS:
#   - Debian 12, 13
#   - Ubuntu 22.04, 24.04
#   - Rocky Linux 8, 9, 10
#
# Usage:
#   bash scripts/init_vhost.sh [COMMAND] [PG_MAJOR] [DOMAIN]
#
# Commands:
#   (default)  - Initialize/start services
#   reset      - Stop all containers, remove volumes, regenerate certs, start fresh
#   help       - Show this help message
#
# Examples:
#   bash scripts/init_vhost.sh                          # Default init
#   bash scripts/init_vhost.sh 17 postgresql.svc.plus   # Init with PG 17
#   bash scripts/init_vhost.sh reset                    # Full reset

set -e

# Configuration
REPO_URL="https://github.com/cloud-neutral-toolkit/postgresql.svc.plus.git"
INSTALL_DIR="${HOME}/postgresql.svc.plus"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO] $1${NC}"; }
log_warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
log_err() { echo -e "${RED}[ERROR] $1${NC}"; }
log_step() { echo -e "${CYAN}==> $1${NC}"; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

image_supports_arch() {
    local image="$1"
    local arch="$2"
    local token=""
    case "$arch" in
      x86_64|amd64) token="amd64" ;;
      aarch64|arm64) token="arm64" ;;
      *) token="$arch" ;;
    esac

    if ! command_exists docker; then
        return 1
    fi
    if docker manifest inspect "$image" 2>/dev/null | grep -q "\"architecture\": \"${token}\""; then
        return 0
    fi
    return 1
}

configure_host_stunnel4() {
    local project_root="$1"
    local tls_port="$2"
    local pg_local_port="$3"
    local cert_src="$4"
    local key_src="$5"

    log_info "Configuring host stunnel4 (tls:${tls_port} -> 127.0.0.1:${pg_local_port})"
    sudo apt-get update -y >/dev/null
    sudo apt-get install -y stunnel4 >/dev/null

    sudo install -d -m 750 -o root -g stunnel4 /etc/stunnel/certs
    sudo cp -f "$cert_src" /etc/stunnel/certs/server-cert.pem
    sudo cp -f "$key_src" /etc/stunnel/certs/server-key.pem
    sudo chown root:stunnel4 /etc/stunnel/certs/server-cert.pem /etc/stunnel/certs/server-key.pem
    sudo chmod 640 /etc/stunnel/certs/server-cert.pem /etc/stunnel/certs/server-key.pem

    sudo tee /etc/stunnel/stunnel.conf >/dev/null <<EOF
pid = /var/run/stunnel4/stunnel.pid
setuid = stunnel4
setgid = stunnel4
foreground = no
debug = 4

[postgres_tls]
accept = 0.0.0.0:${tls_port}
connect = 127.0.0.1:${pg_local_port}
cert = /etc/stunnel/certs/server-cert.pem
key = /etc/stunnel/certs/server-key.pem
sslVersion = TLSv1.2
EOF

    # Debian stunnel4 init script reads FILES from /etc/default/stunnel4.
    if [ -f /etc/default/stunnel4 ]; then
        sudo sed -i 's|^FILES=.*|FILES="/etc/stunnel/stunnel.conf"|' /etc/default/stunnel4 || true
    fi

    sudo systemctl enable --now stunnel4 || true
    sudo systemctl restart stunnel4

    # If docker stunnel container exists (arm64 may fail with amd64 image), keep only host stunnel4.
    if command_exists docker; then
        sudo docker rm -f stunnel-server >/dev/null 2>&1 || true
    fi
}

# -----------------------------------------------------------------------------
# 1. OS Detection
# -----------------------------------------------------------------------------
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        log_err "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    log_info "Detected OS: $OS $VERSION_ID"

    case "$OS" in
        debian)
            if [[ "$VERSION_ID" -lt 12 ]]; then
                log_warn "Debian version $VERSION_ID might be too old (Recommended: 12+)."
            fi
            CMD_INSTALL="sudo apt-get update -y && sudo apt-get install -y"
            PKG_LIST="curl git make openssl postgresql-client"
            ;;
        ubuntu)
            # 22.04=jammy, 24.04=noble
            CMD_INSTALL="sudo apt-get update -y && sudo apt-get install -y"
            PKG_LIST="curl git make openssl postgresql-client"
            ;;
        rocky|rhel|centos|almalinux)
            CMD_INSTALL="sudo dnf install -y"
            PKG_LIST="curl git make openssl postgresql"
            ;;
        *)
            log_err "Unsupported OS: $OS. Attempting to proceed with generic assumptions..."
            CMD_INSTALL="sudo apt-get install -y || sudo yum install -y"
            PKG_LIST="curl git make"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# 2. Dependency Installation
# -----------------------------------------------------------------------------
install_deps() {
    log_step "Installing system dependencies..."
    eval "$CMD_INSTALL $PKG_LIST"

    # Install Docker if missing
    if ! command -v docker &> /dev/null; then
        log_step "Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        
        log_info "Starting Docker service..."
        sudo systemctl enable --now docker || true
        
        # Add current user to docker group (requires re-login to check, so we might use sudo for docker cmds later if this falls through)
        sudo usermod -aG docker "$USER" || true
    else
        log_info "Docker is already installed."
    fi

    # Ensure Docker Compose plugin
    if ! docker compose version &> /dev/null; then
        log_warn "Docker Compose V2 plugin not detected. Attempting to install..."
        # On some distros get.docker.com handles this, if not we might fail unless we install explicitly.
        # For simplicity, we assume get.docker.com or distro packages covered 'docker-compose-plugin'.
    fi
}

# -----------------------------------------------------------------------------
# 3. Project Setup
# -----------------------------------------------------------------------------
setup_project() {
    # Check if we are already inside the repo
    if [ -d ".git" ] && [ -f "Makefile" ] && [ -f "deploy/docker/docker-compose.yml" ]; then
        log_info "Already inside project root."
        PROJECT_ROOT=$(pwd)
    else
        log_step "Cloning/Updating project Repo..."
        if [ -d "$INSTALL_DIR" ]; then
            log_info "Updating existing repo at $INSTALL_DIR..."
            cd "$INSTALL_DIR"
            git pull
        else
            log_info "Cloning to $INSTALL_DIR..."
            git clone "$REPO_URL" "$INSTALL_DIR"
            cd "$INSTALL_DIR"
        fi
        PROJECT_ROOT="$INSTALL_DIR"
    fi
}

# -----------------------------------------------------------------------------
# 4. Certificate Detection & Mapping
# -----------------------------------------------------------------------------
find_acme_certs() {
    local domain=$1
    local found=0
    
    # Paths according to user-defined conventions
    local search_paths=(
        # Caddy (Docker volume or native)
        "/var/lib/docker/volumes/caddy_data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain"
        "/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain"
        # Certbot
        "/etc/letsencrypt/live/$domain"
    )

    for path in "${search_paths[@]}"; do
        if [ -d "$path" ]; then
            # Caddy style: domain.crt / domain.key
            if [ -f "$path/$domain.crt" ] && [ -f "$path/$domain.key" ]; then
                export STUNNEL_CRT_FILE="$path/$domain.crt"
                export STUNNEL_KEY_FILE="$path/$domain.key"
                log_info "Detected ACME (Caddy) certificates at $path"
                return 0
            # Certbot style: fullchain.pem / privkey.pem
            elif [ -f "$path/fullchain.pem" ] && [ -f "$path/privkey.pem" ]; then
                export STUNNEL_CRT_FILE="$path/fullchain.pem"
                export STUNNEL_KEY_FILE="$path/privkey.pem"
                log_info "Detected ACME (Certbot) certificates at $path"
                return 0
            fi
        fi
    done

    return 1
}

# -----------------------------------------------------------------------------
# 5. Build & Launch
# -----------------------------------------------------------------------------
launch_vhost() {
    cd "$PROJECT_ROOT"

    # Detect default domain if not provided
    LOCAL_HOSTNAME=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")

    # Support PG_MAJOR override
    # Usage: scripts/init_vhost.sh [PG_MAJOR]
    # Default: 16 (Latest stable)
    export PG_MAJOR="${1:-${PG_MAJOR:-16}}"
    
    # Validations for PG versions
    if [[ ! "$PG_MAJOR" =~ ^(14|15|16|17|18)$ ]]; then
        log_warn "PG_MAJOR=$PG_MAJOR is not in standard range (14, 15, 16, 17, 18)."
    fi

    # Support DOMAIN override
    # Usage: scripts/init_vhost.sh [PG_MAJOR] [DOMAIN] [ACME_MODE] [STUNNEL_MODE]
    export DOMAIN="${2:-${DOMAIN:-$LOCAL_HOSTNAME}}"
    local requested_acme_mode="${3:-${ACME_MODE:-auto}}"
    local requested_stunnel_mode="${4:-${STUNNEL_MODE:-auto}}"
    local acme_mode="$requested_acme_mode"
    local stunnel_mode="$requested_stunnel_mode"
    case "$acme_mode" in
        auto|bootstrap|host-caddy) ;;
        *)
            log_warn "Unknown ACME mode: $acme_mode. Falling back to auto."
            acme_mode="auto"
            ;;
    esac
    case "$stunnel_mode" in
        auto|docker-stunnel|host-stunnel4) ;;
        *)
            log_warn "Unknown STUNNEL mode: $stunnel_mode. Falling back to auto."
            stunnel_mode="auto"
            ;;
    esac

    local host_caddy_active=0
    local host_agent_stack=0
    local host_arch
    host_arch="$(uname -m)"
    if command_exists systemctl && systemctl is-active --quiet caddy; then
        host_caddy_active=1
    fi
    if command_exists systemctl; then
        if systemctl is-active --quiet xray || systemctl is-active --quiet xray-tcp || systemctl is-active --quiet agent-svc-plus; then
            host_agent_stack=1
        fi
    fi
    if [ "$acme_mode" = "auto" ]; then
        if [ "$host_caddy_active" -eq 1 ] && [ "$host_agent_stack" -eq 1 ]; then
            acme_mode="host-caddy"
        else
            acme_mode="bootstrap"
        fi
    fi
    if [ "$stunnel_mode" = "auto" ]; then
        stunnel_mode="docker-stunnel"
    fi
    local stunnel_image="${STUNNEL_IMAGE:-dweomer/stunnel:latest}"
    local stunnel_platform="linux/amd64"
    case "$host_arch" in
      aarch64|arm64) stunnel_platform="linux/arm64/v8" ;;
      x86_64|amd64) stunnel_platform="linux/amd64" ;;
    esac
    if [ "$stunnel_mode" = "docker-stunnel" ]; then
        if ! image_supports_arch "$stunnel_image" "$host_arch"; then
            log_warn "Image $stunnel_image may not expose ${host_arch} manifest. Compose will request platform=${stunnel_platform}."
        fi
    fi

    log_info "Configuration:"
    log_info "  - PostgreSQL Ver : $PG_MAJOR"
    log_info "  - Service Domain : $DOMAIN"
    log_info "  - ACME mode      : $acme_mode (requested: $requested_acme_mode)"
    log_info "  - STUNNEL mode   : $stunnel_mode (requested: $requested_stunnel_mode)"
    log_info "  - STUNNEL image  : $stunnel_image (${stunnel_platform})"

    # Update .env for docker-compose to pick up PG_MAJOR
    # We append or replace PG_MAJOR in .env to ensure persistence across restarts
    if [ -d "deploy/docker" ]; then
        if [ -f "deploy/docker/.env" ]; then
             if grep -q "PG_MAJOR=" "deploy/docker/.env"; then
                 if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' "s/^PG_MAJOR=.*/PG_MAJOR=$PG_MAJOR/" "deploy/docker/.env"
                 else
                    sed -i "s/^PG_MAJOR=.*/PG_MAJOR=$PG_MAJOR/" "deploy/docker/.env"
                 fi
             else
                 echo "PG_MAJOR=$PG_MAJOR" >> "deploy/docker/.env"
             fi
        fi
    fi

    # Fix permissions for scripts just in case
    chmod +x deploy/docker/generate-certs.sh
    chmod +x scripts/*.sh

    log_step "[Step 1/4] Building Docker Image (PG $PG_MAJOR)..."
    # Attempt build using make. Warning: requires 'docker' access.
    
    # Ensure make sees the variable
    if ! make build-postgres-image PG_MAJOR=$PG_MAJOR; then
        log_warn "Build failed, retrying with sudo..."
        sudo make build-postgres-image PG_MAJOR=$PG_MAJOR
    fi

    log_step "[Step 2/4] Configuring Environment..."
    cd deploy/docker
    if [ ! -f .env ]; then
        log_info "Creating .env from .env.example..."
        cp .env.example .env
        # Generate a random password
        PG_PASS=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9')
        # Replace the placeholder password
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/POSTGRES_PASSWORD=changeme_secure_password/POSTGRES_PASSWORD=$PG_PASS/" .env
        else
            sed -i "s/POSTGRES_PASSWORD=changeme_secure_password/POSTGRES_PASSWORD=$PG_PASS/" .env
        fi
        
        # Add PG_MAJOR to .env
        echo "PG_MAJOR=$PG_MAJOR" >> .env

        # Add default Stunnel variables
        echo "STUNNEL_SERVICE=postgres-tls" >> .env
        echo "STUNNEL_ACCEPT=5433" >> .env
        echo "STUNNEL_CONNECT=postgres:5432" >> .env
        echo "STUNNEL_PORT=5443" >> .env
        echo "STUNNEL_IMAGE=${stunnel_image}" >> .env
        echo "STUNNEL_PLATFORM=${stunnel_platform}" >> .env
        echo "PG_LOCAL_PORT=15432" >> .env
        
        log_info "Generated secure POSTGRES_PASSWORD in .env"
    else
        log_info "Existing .env found. Using existing configuration."
        # Read the password specifically for the final output
        PG_PASS=$(grep '^POSTGRES_PASSWORD=' .env | cut -d '=' -f2)
        
        # Ensure PG_MAJOR is in .env if it was missing
        if ! grep -q "PG_MAJOR=" .env; then
             echo "PG_MAJOR=$PG_MAJOR" >> .env
        fi
        
        # Ensure PG_DATA_PATH is in .env if it was missing
        if ! grep -q "PG_DATA_PATH=" .env; then
             echo "PG_DATA_PATH=/data" >> .env
        fi
        
        # Ensure EMAIL is in .env (for Let's Encrypt)
        if ! grep -q "EMAIL=" .env; then
            # Default to a dummy email or ask user. For automation, use admin@domain
            echo "EMAIL=admin@${DOMAIN}" >> .env
        fi
        if ! grep -q "PG_LOCAL_PORT=" .env; then
            echo "PG_LOCAL_PORT=15432" >> .env
        fi
        if ! grep -q "STUNNEL_IMAGE=" .env; then
            echo "STUNNEL_IMAGE=${stunnel_image}" >> .env
        fi
        if ! grep -q "STUNNEL_PLATFORM=" .env; then
            echo "STUNNEL_PLATFORM=${stunnel_platform}" >> .env
        fi
    fi

    # Read final port for display (handle duplicates if any)
    STUNNEL_PORT=$(grep '^STUNNEL_PORT=' .env | tail -n 1 | cut -d '=' -f2)
    STUNNEL_PORT=${STUNNEL_PORT:-5443}
    PG_LOCAL_PORT=$(grep '^PG_LOCAL_PORT=' .env | tail -n 1 | cut -d '=' -f2)
    PG_LOCAL_PORT=${PG_LOCAL_PORT:-15432}

    # Read final configuration for bootstrap
    export EMAIL=$(grep '^EMAIL=' .env | cut -d '=' -f2)
    export DOMAIN=$DOMAIN
    
    log_step "[Step 3/4] Certificates Management..."
    
    # Check if we are using "localhost" or a real domain
    if [[ "$DOMAIN" == "localhost" || "$DOMAIN" == "127.0.0.1" ]]; then
       log_info "Domain is localhost. Using project certs."
       ./generate-certs.sh "$DOMAIN"
       export STUNNEL_CRT_FILE="$(pwd)/certs/server-cert.pem"
       export STUNNEL_KEY_FILE="$(pwd)/certs/server-key.pem"
    else
       log_info "Real domain detected: $DOMAIN"
       
       # Try finding existing certs first
       if find_acme_certs "$DOMAIN"; then
           log_info "Using existing ACME certificates."
       else
           if [ "$acme_mode" = "host-caddy" ]; then
               log_info "ACME certificates not found. Requesting via host caddy.service..."
               if ! command_exists systemctl; then
                   log_err "systemctl not available; cannot use host-caddy mode."
                   exit 1
               fi
               if ! systemctl is-active --quiet caddy; then
                   log_err "caddy.service is not active, cannot use host-caddy mode."
                   log_err "Try ACME_MODE=bootstrap or start caddy.service first."
                   exit 1
               fi

               mkdir -p /etc/caddy/conf.d
               caddy_domain_file="/etc/caddy/conf.d/${DOMAIN}.caddy"
               # Keep only one site file for this domain to avoid ambiguous site definitions.
               find /etc/caddy/conf.d -maxdepth 1 -type f -name "*${DOMAIN}*.caddy" ! -name "${DOMAIN}.caddy" -delete || true
               cat > "${caddy_domain_file}" <<EOF
${DOMAIN} {
    respond "postgresql.svc.plus ACME endpoint" 200
}
EOF
               if grep -q "^#import /etc/caddy/conf.d/\\*.caddy" /etc/caddy/Caddyfile 2>/dev/null; then
                   sed -i "s|^#import /etc/caddy/conf.d/\\*.caddy|import /etc/caddy/conf.d/*.caddy|" /etc/caddy/Caddyfile
               fi
               if ! grep -q "^import /etc/caddy/conf.d/\\*.caddy" /etc/caddy/Caddyfile 2>/dev/null; then
                   echo "" >> /etc/caddy/Caddyfile
                   echo "import /etc/caddy/conf.d/*.caddy" >> /etc/caddy/Caddyfile
               fi

               systemctl reload caddy || systemctl restart caddy
               log_info "Waiting for ACME certificate acquisition via host caddy (up to 180s)..."
               local timeout=180
               local elapsed=0
               while [ $elapsed -lt $timeout ]; do
                   if find_acme_certs "$DOMAIN"; then
                       break
                   fi
                   sleep 10
                   elapsed=$((elapsed + 10))
                   log_info "Retrying certificate check... ($elapsed/$timeout s)"
               done

               if find_acme_certs "$DOMAIN"; then
                   log_info "Host caddy ACME successful."
               else
                   log_err "FAIL-FAST: host caddy could not issue ACME cert for $DOMAIN."
                   log_err "Please ensure DNS A/AAAA points to this host and ports 80/443 are reachable from Internet."
                   systemctl status caddy --no-pager -l || true
                   exit 1
               fi
           else
               log_info "ACME certificates not found. Starting Caddy Bootstrap..."

               # Ensure caddy_data volume exists
               docker volume create caddy_data >/dev/null 2>&1 || true

               DOCKER_CMD="docker compose"
               ! docker compose version &>/dev/null && DOCKER_CMD="docker-compose"

               $DOCKER_CMD -f docker-compose.bootstrap.yml up -d
               log_info "Waiting for ACME certificate acquisition (60s)..."

               # Check every 10 seconds for up to 120 seconds
               local timeout=120
               local elapsed=0
               while [ $elapsed -lt $timeout ]; do
                   if find_acme_certs "$DOMAIN"; then
                       break
                   fi
                   sleep 10
                   elapsed=$((elapsed + 10))
                   log_info "Retrying certificate check... ($elapsed/$timeout s)"
               done

               # Check again
               if find_acme_certs "$DOMAIN"; then
                    log_info "Bootstrap successful. ACME certificates acquired."
               else
                    log_err "FAIL-FAST: ACME certificates for $DOMAIN not found after bootstrap!"
                    log_err "Please ensure:"
                    log_err "  1. DNS is pointing to this host"
                    log_err "  2. Port 80 is open and not occupied"
                    log_err "  3. The domain name is correct"
                    $DOCKER_CMD -f docker-compose.bootstrap.yml down || true
                    exit 1
               fi
               $DOCKER_CMD -f docker-compose.bootstrap.yml down
           fi
       fi
    fi
    cd ../..

    log_step "[Step 4/4] Starting Services..."
    # We use 'docker compose' (v2) or fallback to 'docker-compose' (v1)
    DOCKER_CMD="docker compose"
    if ! docker compose version &>/dev/null; then
        if command -v docker-compose &>/dev/null; then
            DOCKER_CMD="docker-compose"
        else
            log_err "docker compose not found."
            exit 1
        fi
    fi

    log_info "Starting services with certificate mapping:"
    log_info "  CRT: $STUNNEL_CRT_FILE"
    log_info "  KEY: $STUNNEL_KEY_FILE"

    # Persist mapping to .env so manual 'docker compose' commands work too
    if [ -n "$STUNNEL_CRT_FILE" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^STUNNEL_CRT_FILE=/d" deploy/docker/.env || true
        else
            sed -i "/^STUNNEL_CRT_FILE=/d" deploy/docker/.env || true
        fi
        echo "STUNNEL_CRT_FILE=$STUNNEL_CRT_FILE" >> deploy/docker/.env
    fi
    if [ -n "$STUNNEL_KEY_FILE" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^STUNNEL_KEY_FILE=/d" deploy/docker/.env || true
        else
            sed -i "/^STUNNEL_KEY_FILE=/d" deploy/docker/.env || true
        fi
        echo "STUNNEL_KEY_FILE=$STUNNEL_KEY_FILE" >> deploy/docker/.env
    fi
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^STUNNEL_MODE=/d" deploy/docker/.env || true
    else
        sed -i "/^STUNNEL_MODE=/d" deploy/docker/.env || true
    fi
    echo "STUNNEL_MODE=$stunnel_mode" >> deploy/docker/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^STUNNEL_IMAGE=/d" deploy/docker/.env || true
    else
        sed -i "/^STUNNEL_IMAGE=/d" deploy/docker/.env || true
    fi
    echo "STUNNEL_IMAGE=${stunnel_image}" >> deploy/docker/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^STUNNEL_PLATFORM=/d" deploy/docker/.env || true
    else
        sed -i "/^STUNNEL_PLATFORM=/d" deploy/docker/.env || true
    fi
    echo "STUNNEL_PLATFORM=${stunnel_platform}" >> deploy/docker/.env

    # Cleanup potential docker-created directories if they exist where files should be
    # This happens if docker compose is run while variables are empty
    [ -d "deploy/docker/certs/server-cert.pem" ] && sudo rm -rf "deploy/docker/certs/server-cert.pem"
    [ -d "deploy/docker/certs/server-key.pem" ] && sudo rm -rf "deploy/docker/certs/server-key.pem"

    if [ "$stunnel_mode" = "host-stunnel4" ]; then
        log_info "Starting postgres only (host stunnel4 mode)"
        if ! $DOCKER_CMD -f deploy/docker/docker-compose.yml up -d postgres; then
            log_warn "Docker compose failed, retrying with sudo..."
            sudo -E $DOCKER_CMD -f deploy/docker/docker-compose.yml up -d postgres
        fi
        configure_host_stunnel4 "$PROJECT_ROOT" "$STUNNEL_PORT" "$PG_LOCAL_PORT" "$STUNNEL_CRT_FILE" "$STUNNEL_KEY_FILE"
    else
        # Docker stunnel mode must release 5443 from host stunnel4 if it exists.
        if command_exists systemctl; then
            sudo systemctl stop stunnel4 >/dev/null 2>&1 || true
        fi
        # Try standard up, fallback to sudo -E to preserve env if needed (though .env is primary now)
        if ! $DOCKER_CMD -f deploy/docker/docker-compose.yml -f deploy/docker/docker-compose.tunnel.yml up -d; then
             log_warn "Docker compose failed, retrying with sudo..."
             sudo -E $DOCKER_CMD -f deploy/docker/docker-compose.yml -f deploy/docker/docker-compose.tunnel.yml up -d
        fi
    fi
}

# -----------------------------------------------------------------------------
# Reset Mode - Full cleanup and restart
# -----------------------------------------------------------------------------
reset_vhost() {
    log_warn "🔄 RESET MODE: This will stop all containers and remove data!"
    echo ""
    read -p "Are you sure? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Reset cancelled."
        exit 0
    fi

    cd "$PROJECT_ROOT"
    
    log_step "[Reset 1/5] Stopping all containers..."
    DOCKER_CMD="docker compose"
    ! docker compose version &>/dev/null && DOCKER_CMD="docker-compose"
    
    cd deploy/docker
    $DOCKER_CMD -f docker-compose.yml -f docker-compose.tunnel.yml down --remove-orphans || true
    $DOCKER_CMD -f docker-compose.bootstrap.yml down --remove-orphans || true
    
    log_step "[Reset 2/5] Removing volumes..."
    # Get PG_DATA_PATH from .env before we delete it (default to /data)
    CURRENT_DATA_PATH=$(grep "^PG_DATA_PATH=" .env | cut -d'=' -f2 || echo "/data")
    
    # Preserve ACME certificates to avoid rate limits
    # docker volume rm docker_caddy_data 2>/dev/null || true
    # docker volume rm caddy_data 2>/dev/null || true
    docker volume rm docker_stunnel_logs 2>/dev/null || true
    docker volume rm stunnel_logs 2>/dev/null || true
    
    if [ -d "$CURRENT_DATA_PATH" ]; then
        log_warn "Cleaning PostgreSQL data directory: $CURRENT_DATA_PATH"
        sudo rm -rf "${CURRENT_DATA_PATH:?}"/* || true
    fi
    
    log_step "[Reset 3/5] Cleaning certificates..."
    rm -rf certs/*
    
    log_step "[Reset 4/5] Removing .env (will be regenerated)..."
    rm -f .env
    
    cd ../..
    
    log_step "[Reset 5/5] Restarting fresh initialization..."
    echo ""
}

show_help() {
    echo -e "${CYAN}PostgreSQL Service Plus - Vhost Initialization Script${NC}"
    echo ""
    echo "Usage:"
    echo "  init_vhost.sh [POSTGRES_VERSION] [DOMAIN] [ACME_MODE] [STUNNEL_MODE]"
    echo "  init_vhost.sh reset"
    echo ""
    echo "Arguments:"
    echo "  POSTGRES_VERSION  Support: 14 | 15 | 16 | 17 | 18 (Default: 16)"
    echo "  DOMAIN            stunnel TLS endpoint (Default: current hostname)"
    echo "  ACME_MODE         auto | bootstrap | host-caddy (Default: auto)"
    echo "  STUNNEL_MODE      auto | docker-stunnel | host-stunnel4 (Default: auto)"
    echo ""
    echo "Commands:"
    echo "  reset             Stop all containers, remove volumes, regenerate certs, start fresh"
    echo "  help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  bash scripts/init_vhost.sh 17 db.example.com"
    echo "  bash scripts/init_vhost.sh 17 db.example.com host-caddy host-stunnel4"
    echo "  bash scripts/init_vhost.sh 16 postgres.mycompany.net"
    echo "  curl -fsSL https://.../init_vhost.sh | bash -s -- 17 db.example.com"
    echo ""
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------
main() {
    # Parse command
    case "${1:-}" in
        reset)
            log_info "Starting Reset Mode..."
            detect_os
            install_deps
            setup_project
            reset_vhost
            shift
            launch_vhost "$@"
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            log_info "Starting Vhost Initialization..."
            detect_os
            install_deps
            setup_project
            launch_vhost "$@"
            ;;
    esac
    
    
    echo ""
    log_step "✅ PostgreSQL TLS Server Ready!"
    echo ""
    
    if [ -n "$PG_PASS" ]; then
        echo -e "🏗️  ${CYAN}SERVER-SIDE ARCHITECTURE:${NC}"
        echo -e "   External Client → TLS:443 → stunnel (server) → postgres:5432"
        echo ""
        echo -e "🌍 ${CYAN}Server TLS Endpoint:${NC}"
        echo -e "   ${GREEN}${DOMAIN}:${STUNNEL_PORT}${NC}"
        echo ""
        echo -e "🔑 ${CYAN}Database Credentials:${NC}"
        echo -e "   User: ${GREEN}postgres${NC}"
        echo -e "   Pass: ${YELLOW}\${POSTGRES_PASSWORD}${NC} (See deploy/docker/.env)"
        echo -e "   DB  : ${GREEN}postgres${NC}"
        echo ""
        echo -e "📦 ${CYAN}CLIENT-SIDE SETUP (User's Machine):${NC}"
        echo ""
        echo -e "   ${YELLOW}Step 1:${NC} Install stunnel client"
        echo -e "   - Docker: docker run -d -p 127.0.0.1:15432:15432 -v ./stunnel-client.conf:/etc/stunnel/stunnel.conf dweomer/stunnel"
        echo -e "   - Native: apt install stunnel4 / brew install stunnel"
        echo ""
        echo -e "   ${YELLOW}Step 2:${NC} Create stunnel client config (stunnel-client.conf):"
        echo -e "   ${GREEN}[postgres-client]${NC}"
        echo -e "   ${GREEN}client  = yes${NC}"
        echo -e "   ${GREEN}accept  = 127.0.0.1:15432${NC}"
        echo -e "   ${GREEN}connect = ${DOMAIN}:${STUNNEL_PORT}${NC}"
        echo -e "   ${GREEN}verify  = 2${NC}"
        echo -e "   ${GREEN}CAfile  = /etc/ssl/certs/ca-certificates.crt${NC}"
        echo -e "   ${GREEN}checkHost = ${DOMAIN}${NC}"
        echo ""
        echo -e "   ${YELLOW}Step 3:${NC} Start stunnel client"
        echo -e "   - stunnel stunnel-client.conf"
        echo ""
        echo -e "   ${YELLOW}Step 4:${NC} Connect your app to local stunnel endpoint"
        echo -e "   ${GREEN}postgres://postgres:\${POSTGRES_PASSWORD}@127.0.0.1:15432/postgres${NC}"
        echo ""
        echo -e "💡 ${CYAN}Architecture Flow:${NC}"
        echo -e "   App (127.0.0.1:15432) → stunnel (client) → TLS → ${DOMAIN}:${STUNNEL_PORT} → stunnel (server) → postgres:5432"
        echo ""
        echo -e "🔒 ${CYAN}Security Notes:${NC}"
        echo -e "   - Server uses Let's Encrypt/ACME certificates (auto-renewed)"
        echo -e "   - Client verifies server certificate (verify=2)"
        echo -e "   - All traffic encrypted with TLS 1.2+"
        echo -e "   - Optional: Enable mTLS for client certificate authentication"
    else
        echo "   (Initialization failed or password not found, check deploy/docker/.env)"
    fi
    echo ""

}

main "$@"
