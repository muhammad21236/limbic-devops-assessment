#!/bin/bash

################################################################################
# Health Check Script
# 
# Performs comprehensive health checks on all system components
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================"
echo "  System Health Check"
echo "================================"
echo ""

# ============================================================================
# Check LXD
# ============================================================================

echo "=== LXD Status ==="
if command -v lxc &> /dev/null; then
    lxc list
    echo -e "${GREEN}✅ LXD is available${NC}"
else
    echo -e "${RED}❌ LXD not found${NC}"
fi
echo ""

# ============================================================================
# Check Docker Containers (if inside LXD container)
# ============================================================================

echo "=== Docker Containers ==="
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Check container health
    for container in $(docker ps --format '{{.Names}}'); do
        health=$(docker inspect --format='{{.State.Health.Status}}' $container 2>/dev/null || echo "no healthcheck")
        if [ "$health" = "healthy" ]; then
            echo -e "  ${GREEN}✅ $container: healthy${NC}"
        elif [ "$health" = "no healthcheck" ]; then
            echo -e "  ${YELLOW}⚠️  $container: no healthcheck defined${NC}"
        else
            echo -e "  ${RED}❌ $container: $health${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  Docker not available (run inside app-host container)${NC}"
fi
echo ""

# ============================================================================
# Check Application Health
# ============================================================================

echo "=== Application Health ==="

# Check App1
echo -n "App1 (/ping): "
if curl -f -s https://app1.example.com/ping > /dev/null 2>&1 || \
   curl -f -s http://localhost:3000/ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Healthy${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi

# Check App2
echo -n "App2 (/status): "
if curl -f -s http://localhost:5000/status > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Healthy${NC}"
else
    echo -e "${RED}❌ Failed${NC}"
fi
echo ""

# ============================================================================
# Check Cloudflare Tunnel
# ============================================================================

echo "=== Cloudflare Tunnel ==="
if systemctl is-active --quiet cloudflared 2>/dev/null; then
    echo -e "${GREEN}✅ Cloudflared service is running${NC}"
    systemctl status cloudflared --no-pager | grep "Active:"
else
    if command -v systemctl &> /dev/null; then
        echo -e "${RED}❌ Cloudflared service is not running${NC}"
    else
        echo -e "${YELLOW}⚠️  Systemctl not available (run inside app-host container)${NC}"
    fi
fi
echo ""

# ============================================================================
# Check Disk Space
# ============================================================================

echo "=== Disk Usage ==="
df -h | grep -E '(Filesystem|/dev/|lxd|docker)' || df -h
echo ""

# ============================================================================
# Check Memory
# ============================================================================

echo "=== Memory Usage ==="
free -h
echo ""

# ============================================================================
# Check Network
# ============================================================================

echo "=== Network Status ==="
if command -v lxc &> /dev/null; then
    echo "LXD Network:"
    lxc network info lxdbr0 2>/dev/null || echo "  Not available (run on host)"
fi

if command -v docker &> /dev/null; then
    echo ""
    echo "Docker Networks:"
    docker network ls
fi
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "================================"
echo "  Health Check Complete"
echo "================================"
