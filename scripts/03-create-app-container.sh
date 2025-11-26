#!/bin/bash

################################################################################
# App Container Creation Script for Limbic Capital DevOps Assessment
# 
# This script creates and configures the application container:
# - Launches Ubuntu 22.04 LXD container (app-host)
# - Configures static IP address
# - Attaches persistent storage
# - Installs Docker and Docker Compose
# - Prepares environment for applications
#
# Usage: ./03-create-app-container.sh
################################################################################

set -e  # Exit on any error

# ==============================================================================
# CONFIGURATION
# ==============================================================================

CONTAINER_NAME="app-host"
CONTAINER_IMAGE="ubuntu:22.04"
STORAGE_POOL="limbic-pool"
VOLUME_NAME="app-data"
VOLUME_SIZE="10GiB"
STATIC_IP="10.10.10.100"
APPS_DIR="/opt/apps"

# ==============================================================================
# SCRIPT START
# ==============================================================================

echo "================================"
echo "Limbic Capital - App Container"
echo "================================"
echo ""

echo "📋 Configuration:"
echo "  - Container name: $CONTAINER_NAME"
echo "  - Container image: $CONTAINER_IMAGE"
echo "  - Static IP: $STATIC_IP"
echo "  - Storage volume: $VOLUME_NAME ($VOLUME_SIZE)"
echo ""

# ==============================================================================
# Check if Container Exists
# ==============================================================================

if lxc list --format csv | grep -q "^$CONTAINER_NAME,"; then
    echo "⚠️  Container '$CONTAINER_NAME' already exists!"
    echo ""
    lxc list $CONTAINER_NAME
    echo ""
    read -p "Delete and recreate? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "  🗑️  Deleting existing container..."
        lxc stop $CONTAINER_NAME --force 2>/dev/null || true
        lxc delete $CONTAINER_NAME --force
        echo "  ✅ Container deleted"
    else
        echo "  ℹ️  Using existing container"
        exit 0
    fi
fi

# ==============================================================================
# Launch Container
# ==============================================================================

echo ""
echo "🚀 Launching container: $CONTAINER_NAME"

# Launch container (explicitly as container, not VM)
lxc launch $CONTAINER_IMAGE $CONTAINER_NAME --vm=false

echo "  ⏳ Waiting for container to be ready..."

# Wait for container to be in RUNNING state
for i in {1..30}; do
    STATE=$(lxc list $CONTAINER_NAME --format csv --columns s 2>/dev/null | head -n1)
    if [ "$STATE" = "RUNNING" ]; then
        echo "  ✅ Container is running"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "  ❌ Container failed to start after 60 seconds"
        lxc info $CONTAINER_NAME
        exit 1
    fi
    sleep 2
done

# Give it a moment to settle
sleep 5

# Try to execute a simple command to verify container is responsive
echo "  🔍 Checking if container is responsive..."
RESPONSIVE=false
for i in {1..20}; do
    if lxc exec $CONTAINER_NAME --force-noninteractive -- /bin/sh -c "echo ready" &>/dev/null; then
        echo "  ✅ Container is responsive"
        RESPONSIVE=true
        break
    fi
    # Show progress every 5 attempts
    if [ $((i % 5)) -eq 0 ]; then
        echo "  ⏳ Still waiting... (attempt $i/20)"
    fi
    sleep 3
done

if [ "$RESPONSIVE" = "false" ]; then
    echo "  ⚠️  Container not responding normally, trying alternative approach..."
    # Sometimes the container needs a restart to become responsive
    lxc restart $CONTAINER_NAME
    sleep 10
    
    for i in {1..10}; do
        if lxc exec $CONTAINER_NAME --force-noninteractive -- /bin/sh -c "echo ready" &>/dev/null; then
            echo "  ✅ Container is now responsive after restart"
            RESPONSIVE=true
            break
        fi
        sleep 3
    done
    
    if [ "$RESPONSIVE" = "false" ]; then
        echo "  ❌ Container failed to become responsive"
        echo "  ℹ️  Container info:"
        lxc info $CONTAINER_NAME
        echo "  ℹ️  Container logs:"
        lxc console $CONTAINER_NAME --show-log | tail -20
        exit 1
    fi
fi

echo "  ✅ Container launched"

# ==============================================================================
# Configure Security Settings
# ==============================================================================

echo ""
echo "🔒 Configuring container security..."

# Enable nesting for Docker
lxc config set $CONTAINER_NAME security.nesting true
echo "  ✅ Nesting enabled (required for Docker)"

# Enable system calls for Docker
lxc config set $CONTAINER_NAME security.syscalls.intercept.mknod true
lxc config set $CONTAINER_NAME security.syscalls.intercept.setxattr true
echo "  ✅ System calls configured"

# Restart container to apply settings
echo "  🔄 Restarting container to apply settings..."
lxc restart $CONTAINER_NAME
sleep 5

# Wait for network connectivity
echo "  ⏳ Waiting for network connectivity..."
sleep 5

# ==============================================================================
# Configure Static IP
# ==============================================================================

echo ""
echo "🌐 Configuring static IP: $STATIC_IP"

# Stop container before network reconfiguration
lxc stop $CONTAINER_NAME

# Remove default eth0 and add with static IP
lxc config device remove $CONTAINER_NAME eth0 2>/dev/null || true
lxc config device add $CONTAINER_NAME eth0 nic \
    nictype=bridged \
    parent=lxdbr0 \
    name=eth0

# Start container
lxc start $CONTAINER_NAME
sleep 10

# Configure IP manually inside the container using netplan
echo "  ⏳ Configuring network with netplan..."
lxc exec $CONTAINER_NAME -- bash -c 'cat > /etc/netplan/10-lxc.yaml << EOF
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 10.10.10.100/24
      routes:
        - to: default
          via: 10.10.10.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF'

# Fix permissions to avoid warnings
lxc exec $CONTAINER_NAME -- chmod 600 /etc/netplan/10-lxc.yaml

# Apply netplan configuration (suppress warnings)
lxc exec $CONTAINER_NAME -- netplan apply 2>/dev/null || true

# Ensure DNS is properly configured (systemd-resolved can interfere)
echo "  ⏳ Configuring DNS..."
lxc exec $CONTAINER_NAME -- bash -c 'rm -f /etc/resolv.conf'
lxc exec $CONTAINER_NAME -- bash -c 'cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF'
lxc exec $CONTAINER_NAME -- bash -c 'chattr +i /etc/resolv.conf 2>/dev/null || true'

# Wait for network to be ready
echo "  ⏳ Waiting for network interface..."
sleep 5
for i in {1..15}; do
    IP=$(lxc exec $CONTAINER_NAME -- ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")
    if [ -n "$IP" ]; then
        echo "  ✅ Static IP configured: $IP"
        break
    fi
    sleep 2
done

echo "  ✅ Network configured"

# Verify IP address
ACTUAL_IP=$(lxc list $CONTAINER_NAME --format csv -c 4 | cut -d' ' -f1)
echo "  ℹ️  Container IP: $ACTUAL_IP"

# ==============================================================================
# Create and Attach Persistent Storage
# ==============================================================================

echo ""
echo "💾 Creating persistent storage volume..."

# Create storage volume if it doesn't exist
if ! lxc storage volume list $STORAGE_POOL | grep -q "$VOLUME_NAME"; then
    lxc storage volume create $STORAGE_POOL $VOLUME_NAME size=$VOLUME_SIZE
    echo "  ✅ Storage volume created"
else
    echo "  ℹ️  Storage volume already exists"
fi

# Attach volume to container
if ! lxc config device show $CONTAINER_NAME | grep -q "app-data:"; then
    lxc config device add $CONTAINER_NAME app-data disk \
        pool=$STORAGE_POOL \
        source=$VOLUME_NAME \
        path=/var/lib/docker/volumes
    echo "  ✅ Storage volume attached to container"
else
    echo "  ℹ️  Storage volume already attached"
fi

# ==============================================================================
# Install Docker
# ==============================================================================

echo ""
echo "🐳 Installing Docker in container..."

# Test network connectivity before proceeding
echo "  🔍 Testing network connectivity..."
NETWORK_OK=false

# First verify DNS resolution works
echo "  🔍 Testing DNS resolution..."
if lxc exec $CONTAINER_NAME -- nslookup google.com 8.8.8.8 &>/dev/null; then
    echo "  ✅ DNS resolution working"
    NETWORK_OK=true
else
    echo "  ❌ DNS resolution failed"
    echo ""
    echo "  🔧 Attempting to fix DNS and routing..."
    
    # Check if MASQUERADE rule exists for LXD network
    if ! sudo iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE.*10.10.10.0"; then
        echo "  ⚠️  No NAT MASQUERADE rule found - adding now..."
        
        # Add MASQUERADE rule for LXD bridge
        sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 ! -d 10.10.10.0/24 -j MASQUERADE
        
        # Allow forwarding from LXD bridge
        sudo iptables -I FORWARD 1 -i lxdbr0 -j ACCEPT
        sudo iptables -I FORWARD 1 -o lxdbr0 -j ACCEPT
        
        # Enable IP forwarding on host
        echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null
        
        echo "  ✅ NAT rules added"
        
        # Show the new rules
        echo "  ℹ️  Verifying NAT rules:"
        sudo iptables -t nat -L POSTROUTING -n -v
        sleep 3
    else
        echo "  ℹ️  MASQUERADE rule already exists"
    fi
    
    # Ensure LXD bridge has NAT enabled in config
    lxc network set lxdbr0 ipv4.nat true 2>/dev/null || true
    lxc network set lxdbr0 ipv4.firewall true 2>/dev/null || true
    
    # Try DNS resolution again
    if lxc exec $CONTAINER_NAME -- nslookup google.com 8.8.8.8 &>/dev/null; then
        echo "  ✅ DNS now working after fixes"
        NETWORK_OK=true
    else
        echo "  ⚠️  DNS still not working - will try to continue"
    fi
fi

if [ "$NETWORK_OK" = "false" ]; then
    echo ""
    echo "  ℹ️  Network diagnostics:"
    echo "  --- Container IP ---"
    lxc exec $CONTAINER_NAME -- ip addr show eth0
    echo "  --- Container Routes ---"
    lxc exec $CONTAINER_NAME -- ip route
    echo "  --- Container DNS ---"
    lxc exec $CONTAINER_NAME -- cat /etc/resolv.conf
    echo "  --- Host iptables NAT rules ---"
    sudo iptables -t nat -L -n | grep -A5 "Chain POSTROUTING"
    echo ""
fi

# Update package list
lxc exec $CONTAINER_NAME -- apt-get update

# Install prerequisites
lxc exec $CONTAINER_NAME -- apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker GPG key
lxc exec $CONTAINER_NAME -- bash -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"

# Add Docker repository
lxc exec $CONTAINER_NAME -- bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null'

# Update package list
lxc exec $CONTAINER_NAME -- apt-get update

# Install Docker
lxc exec $CONTAINER_NAME -- apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

echo "  ✅ Docker installed"

# Verify Docker installation
DOCKER_VERSION=$(lxc exec $CONTAINER_NAME -- docker --version)
echo "  ℹ️  $DOCKER_VERSION"

COMPOSE_VERSION=$(lxc exec $CONTAINER_NAME -- docker compose version)
echo "  ℹ️  $COMPOSE_VERSION"

# ==============================================================================
# Install Additional Tools
# ==============================================================================

echo ""
echo "🔧 Installing additional tools..."

lxc exec $CONTAINER_NAME -- apt-get install -y \
    net-tools \
    curl \
    wget \
    vim \
    nano \
    htop \
    git \
    jq \
    netcat

echo "  ✅ Additional tools installed"

# ==============================================================================
# Configure Docker
# ==============================================================================

echo ""
echo "⚙️  Configuring Docker..."

# Create Docker daemon configuration
lxc exec $CONTAINER_NAME -- bash -c 'cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "userland-proxy": false,
  "live-restore": true
}
EOF'

# Restart Docker to apply configuration
lxc exec $CONTAINER_NAME -- systemctl restart docker
sleep 3

# Verify Docker is running
if lxc exec $CONTAINER_NAME -- systemctl is-active --quiet docker; then
    echo "  ✅ Docker service is running"
else
    echo "  ❌ Docker service failed to start"
    exit 1
fi

# ==============================================================================
# Create Application Directory
# ==============================================================================

echo ""
echo "📁 Creating application directory..."

lxc exec $CONTAINER_NAME -- mkdir -p $APPS_DIR
lxc exec $CONTAINER_NAME -- chmod 755 $APPS_DIR

echo "  ✅ Application directory created: $APPS_DIR"

# ==============================================================================
# Test Docker Installation
# ==============================================================================

echo ""
read -p "Test Docker with hello-world container? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  🧪 Running Docker hello-world test..."
    lxc exec $CONTAINER_NAME -- docker run --rm hello-world
    echo "  ✅ Docker test successful"
fi

# ==============================================================================
# Configure Cloudflared User
# ==============================================================================

echo ""
echo "☁️  Preparing for Cloudflare Tunnel..."

# Create cloudflared directory
lxc exec $CONTAINER_NAME -- mkdir -p /etc/cloudflared
lxc exec $CONTAINER_NAME -- chmod 755 /etc/cloudflared

echo "  ✅ Cloudflared directory created"
echo "  ℹ️  Cloudflared will be installed in step 6"

# ==============================================================================
# Show Container Information
# ==============================================================================

echo ""
echo "📊 Container Information:"
echo ""

# List container details
lxc list $CONTAINER_NAME

echo ""
echo "🔍 Container details:"
lxc info $CONTAINER_NAME

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "================================"
echo "✅ App Container Setup Complete!"
echo "================================"
echo ""
echo "📋 Summary:"
echo "  - Container: $CONTAINER_NAME"
echo "  - IP Address: $STATIC_IP"
echo "  - Storage: $VOLUME_NAME ($VOLUME_SIZE)"
echo "  - Docker: Installed and running"
echo "  - Apps directory: $APPS_DIR"
echo ""
echo "📖 Useful commands:"
echo "  lxc list                              # List containers"
echo "  lxc exec $CONTAINER_NAME -- bash      # Enter container"
echo "  lxc exec $CONTAINER_NAME -- docker ps # Check Docker containers"
echo "  lxc file push file.txt $CONTAINER_NAME/path/  # Copy file to container"
echo "  lxc file pull $CONTAINER_NAME/path/file.txt . # Copy file from container"
echo ""
echo "🚀 Container is ready for application deployment!"
echo ""
echo "Next steps:"
echo "  1. Deploy Docker applications with docker-compose.yml"
echo "  2. Configure Cloudflare Tunnel"
echo ""
echo "To enter the container:"
echo "  lxc exec $CONTAINER_NAME -- bash"
echo ""
