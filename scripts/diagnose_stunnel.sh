#!/usr/bin/env bash
# scripts/diagnose_stunnel.sh
# Quick diagnostic script to check stunnel server status

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Stunnel Server Diagnostic ===${NC}\n"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Note: Some checks may require sudo privileges${NC}\n"
fi

# 1. Check if stunnel container is running
echo -e "${CYAN}[1/6] Checking Docker containers...${NC}"
if docker ps | grep -q stunnel; then
    echo -e "${GREEN}✓ Stunnel container is running${NC}"
    docker ps | grep stunnel
else
    echo -e "${RED}✗ Stunnel container is NOT running${NC}"
    echo "Checking all containers:"
    docker ps -a | grep stunnel || echo "No stunnel containers found"
fi
echo ""

# 2. Check if port 443 is listening
echo -e "${CYAN}[2/6] Checking if port 443 is listening...${NC}"
if command -v ss &> /dev/null; then
    if ss -tlnp | grep -q :443; then
        echo -e "${GREEN}✓ Port 443 is listening${NC}"
        ss -tlnp | grep :443
    else
        echo -e "${RED}✗ Port 443 is NOT listening${NC}"
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tlnp | grep -q :443; then
        echo -e "${GREEN}✓ Port 443 is listening${NC}"
        netstat -tlnp | grep :443
    else
        echo -e "${RED}✗ Port 443 is NOT listening${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Neither ss nor netstat found, skipping port check${NC}"
fi
echo ""

# 3. Check firewall status
echo -e "${CYAN}[3/6] Checking firewall rules...${NC}"
if command -v ufw &> /dev/null; then
    echo "UFW status:"
    sudo ufw status | grep -E "(443|Status)" || echo "UFW not active"
elif command -v firewall-cmd &> /dev/null; then
    echo "Firewalld status:"
    sudo firewall-cmd --list-ports | grep 443 && echo -e "${GREEN}✓ Port 443 is allowed${NC}" || echo -e "${YELLOW}⚠ Port 443 may not be allowed${NC}"
else
    echo -e "${YELLOW}⚠ No firewall tool detected (ufw/firewalld)${NC}"
fi
echo ""

# 4. Check stunnel logs
echo -e "${CYAN}[4/6] Checking stunnel logs (last 20 lines)...${NC}"
STUNNEL_CONTAINER=$(docker ps -q -f name=stunnel | head -n 1)
if [ -n "$STUNNEL_CONTAINER" ]; then
    docker logs --tail 20 "$STUNNEL_CONTAINER"
else
    echo -e "${YELLOW}⚠ No running stunnel container found${NC}"
fi
echo ""

# 5. Check docker-compose services
echo -e "${CYAN}[5/6] Checking docker-compose services...${NC}"
if [ -d "$HOME/postgresql.svc.plus/deploy/docker" ]; then
    cd "$HOME/postgresql.svc.plus/deploy/docker"
    if [ -f "docker-compose.yml" ]; then
        docker compose -f docker-compose.yml -f docker-compose.tunnel.yml ps 2>/dev/null || \
        docker-compose -f docker-compose.yml -f docker-compose.tunnel.yml ps 2>/dev/null || \
        echo -e "${YELLOW}⚠ Could not check docker-compose status${NC}"
    else
        echo -e "${YELLOW}⚠ docker-compose.yml not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Project directory not found at $HOME/postgresql.svc.plus${NC}"
fi
echo ""

# 6. Test local connection to stunnel
echo -e "${CYAN}[6/6] Testing local connection to port 443...${NC}"
if command -v nc &> /dev/null; then
    if timeout 3 nc -zv 127.0.0.1 443 2>&1; then
        echo -e "${GREEN}✓ Local connection to port 443 successful${NC}"
    else
        echo -e "${RED}✗ Cannot connect to port 443 locally${NC}"
    fi
else
    echo -e "${YELLOW}⚠ netcat (nc) not found, skipping connection test${NC}"
fi
echo ""

# Summary and recommendations
echo -e "${CYAN}=== Summary ===${NC}"
echo ""
echo "If stunnel is not running, try:"
echo -e "${GREEN}cd ~/postgresql.svc.plus/deploy/docker${NC}"
echo -e "${GREEN}docker compose -f docker-compose.yml -f docker-compose.tunnel.yml up -d${NC}"
echo ""
echo "If port 443 is not listening after starting stunnel:"
echo -e "${GREEN}docker logs <stunnel-container-id>${NC}"
echo ""
echo "If firewall is blocking port 443:"
echo -e "${GREEN}sudo ufw allow 443/tcp${NC}  # For Ubuntu/Debian"
echo -e "${GREEN}sudo firewall-cmd --permanent --add-port=443/tcp && sudo firewall-cmd --reload${NC}  # For CentOS/Rocky"
echo ""
