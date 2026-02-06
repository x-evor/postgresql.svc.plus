#!/usr/bin/env bash
# scripts/diagnose_ssl_cert.sh
# Diagnose SSL certificate issues for stunnel server

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Stunnel SSL Certificate Diagnostic ===${NC}\n"

DOMAIN="${1:-postgresql.svc.plus}"
CERT_PATH="/var/lib/docker/volumes/caddy_data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN/$DOMAIN.crt"
KEY_PATH="/var/lib/docker/volumes/caddy_data/_data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/$DOMAIN/$DOMAIN.key"

echo -e "${CYAN}[1/5] Checking certificate files...${NC}"
if [ -f "$CERT_PATH" ]; then
    echo -e "${GREEN}✓ Certificate found: $CERT_PATH${NC}"
    ls -lh "$CERT_PATH"
else
    echo -e "${RED}✗ Certificate NOT found at: $CERT_PATH${NC}"
    echo "Checking alternative paths..."
    find /var/lib/docker/volumes/caddy_data/_data -name "*.crt" 2>/dev/null || echo "No certificates found"
fi
echo ""

if [ -f "$KEY_PATH" ]; then
    echo -e "${GREEN}✓ Private key found: $KEY_PATH${NC}"
    ls -lh "$KEY_PATH"
else
    echo -e "${RED}✗ Private key NOT found at: $KEY_PATH${NC}"
fi
echo ""

echo -e "${CYAN}[2/5] Checking certificate validity...${NC}"
if [ -f "$CERT_PATH" ]; then
    echo "Certificate details:"
    openssl x509 -in "$CERT_PATH" -noout -subject -issuer -dates -ext subjectAltName
    echo ""
    
    # Check if expired
    if openssl x509 -in "$CERT_PATH" -noout -checkend 0; then
        echo -e "${GREEN}✓ Certificate is valid (not expired)${NC}"
    else
        echo -e "${RED}✗ Certificate is EXPIRED${NC}"
    fi
    echo ""
    
    # Check if hostname matches
    echo "Checking hostname match for: $DOMAIN"
    if openssl x509 -in "$CERT_PATH" -noout -text | grep -q "$DOMAIN"; then
        echo -e "${GREEN}✓ Certificate matches domain: $DOMAIN${NC}"
    else
        echo -e "${RED}✗ Certificate does NOT match domain: $DOMAIN${NC}"
        echo "Certificate is for:"
        openssl x509 -in "$CERT_PATH" -noout -text | grep -A1 "Subject Alternative Name"
    fi
else
    echo -e "${YELLOW}⚠ Skipping validation - certificate file not found${NC}"
fi
echo ""

echo -e "${CYAN}[3/5] Checking stunnel container certificate mount...${NC}"
STUNNEL_CONTAINER=$(docker ps -q -f name=stunnel | head -n 1)
if [ -n "$STUNNEL_CONTAINER" ]; then
    echo "Checking certificate inside stunnel container:"
    docker exec "$STUNNEL_CONTAINER" ls -la /etc/stunnel/certs/ 2>/dev/null || echo "Certificate directory not accessible"
    echo ""
    
    echo "Verifying certificate inside container:"
    docker exec "$STUNNEL_CONTAINER" sh -c "if [ -f /etc/stunnel/certs/server-cert.pem ]; then openssl x509 -in /etc/stunnel/certs/server-cert.pem -noout -subject -dates; else echo 'Certificate not found in container'; fi" 2>/dev/null
else
    echo -e "${YELLOW}⚠ No running stunnel container found${NC}"
fi
echo ""

echo -e "${CYAN}[4/5] Testing SSL connection from localhost...${NC}"
if command -v openssl &> /dev/null; then
    echo "Testing connection to localhost:443..."
    timeout 5 openssl s_client -connect localhost:443 -servername "$DOMAIN" </dev/null 2>&1 | grep -E "(Certificate|Verify|subject|issuer)" || echo "Connection failed or no certificate info"
else
    echo -e "${YELLOW}⚠ openssl not found${NC}"
fi
echo ""

echo -e "${CYAN}[5/5] Checking stunnel logs for SSL errors...${NC}"
if [ -n "$STUNNEL_CONTAINER" ]; then
    echo "Recent SSL errors:"
    docker logs --tail 30 "$STUNNEL_CONTAINER" 2>&1 | grep -i "ssl\|error\|cert" || echo "No SSL errors in recent logs"
else
    echo -e "${YELLOW}⚠ No running stunnel container found${NC}"
fi
echo ""

echo -e "${CYAN}=== Summary and Recommendations ===${NC}"
echo ""

if [ ! -f "$CERT_PATH" ]; then
    echo -e "${RED}ISSUE: Certificate not found${NC}"
    echo "Solution: Run the initialization script to generate certificates:"
    echo -e "${GREEN}curl -fsSL https://raw.githubusercontent.com/cloud-neutral-toolkit/postgresql.svc.plus/main/scripts/init_vhost.sh | bash -s -- 17 $DOMAIN${NC}"
    echo ""
elif ! openssl x509 -in "$CERT_PATH" -noout -checkend 0 2>/dev/null; then
    echo -e "${RED}ISSUE: Certificate is expired${NC}"
    echo "Solution: Regenerate certificates:"
    echo -e "${GREEN}cd ~/postgresql.svc.plus/deploy/docker${NC}"
    echo -e "${GREEN}docker compose -f docker-compose.bootstrap.yml up -d${NC}"
    echo "Wait 60 seconds for certificate acquisition, then:"
    echo -e "${GREEN}docker compose -f docker-compose.bootstrap.yml down${NC}"
    echo -e "${GREEN}docker compose -f docker-compose.yml -f docker-compose.tunnel.yml restart stunnel${NC}"
    echo ""
else
    echo -e "${YELLOW}Certificate appears valid. The issue may be:${NC}"
    echo "1. Certificate not properly mounted in stunnel container"
    echo "2. Stunnel configuration error"
    echo "3. Client-server TLS version mismatch"
    echo ""
    echo "Try restarting stunnel with fresh certificate mount:"
    echo -e "${GREEN}cd ~/postgresql.svc.plus/deploy/docker${NC}"
    echo -e "${GREEN}docker compose -f docker-compose.yml -f docker-compose.tunnel.yml down${NC}"
    echo -e "${GREEN}docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d${NC}"
fi
echo ""
