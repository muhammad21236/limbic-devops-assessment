#!/bin/bash

################################################################################
# LXD Setup Script for Limbic Capital DevOps Assessment
# 
# This script installs and configures LXD:
# - Installs LXD via snap
# - Creates dedicated storage pool
# - Configures network bridge (lxdbr0)
# - Initializes LXD with preseed configuration
#
# Usage: ./02-lxd-setup.sh
################################################################################

set -e  # Exit on any error

# ==============================================================================
# CONFIGURATION
# ==============================================================================

STORAGE_POOL_NAME="limbic-pool"
STORAGE_POOL_SIZE="50GiB"
NETWORK_NAME="lxdbr0"
NETWORK_SUBNET="10.10.10.0/24"
NETWORK_DHCP_START="10.10.10.100"
NETWORK_DHCP_END="10.10.10.200"

# ==============================================================================
# SCRIPT START
# ==============================================================================

echo "================================"
echo "Limbic Capital - LXD Setup"
echo "================================"
echo ""

# Check if running as non-root with sudo
if [[ $EUID -eq 0 ]]; then
   echo "❌ Don't run this script as root. Run as your sudo user instead."
   exit 1
fi

echo "📋 Configuration:"
echo "  - Storage pool: $STORAGE_POOL_NAME ($STORAGE_POOL_SIZE)"
echo "  - Network: $NETWORK_NAME ($NETWORK_SUBNET)"
echo ""

# ==============================================================================
# Install LXD
# ==============================================================================

echo "📦 Installing LXD..."

# Remove old LXD if exists
if dpkg -l | grep -q lxd; then
    echo "  ℹ️  Removing old LXD package..."
    sudo apt-get remove -y lxd lxd-client
fi

# Install LXD snap
if snap list | grep -q "^lxd "; then
    echo "  ℹ️  LXD snap already installed"
else
    echo "  Installing LXD snap..."
    sudo snap install lxd
fi

# Add current user to lxd group
sudo usermod -aG lxd $USER
echo "  ✅ User $USER added to lxd group"

echo ""
echo "⚠️  You may need to log out and back in for group membership to take effect."
echo "    Or run: newgrp lxd"
echo ""

# Ensure we can use lxd commands
if ! groups | grep -q lxd; then
    echo "  🔄 Activating lxd group for current session..."
    newgrp lxd <<EONG
echo "  ✅ Group activated"
EONG
fi

# ==============================================================================
# Create Preseed Configuration
# ==============================================================================

echo ""
echo "📝 Creating LXD preseed configuration..."

PRESEED_FILE="/tmp/lxd-preseed.yaml"

cat > "$PRESEED_FILE" <<EOF
config:
  core.https_address: '[::]:8443'
  core.trust_password: ""
networks:
- config:
    ipv4.address: ${NETWORK_SUBNET%.*}.1/24
    ipv4.nat: "true"
    ipv4.dhcp: "true"
    ipv4.dhcp.ranges: ${NETWORK_DHCP_START}-${NETWORK_DHCP_END}
    ipv6.address: none
  description: "Limbic Capital network bridge"
  name: $NETWORK_NAME
  type: bridge
storage_pools:
- config:
    size: $STORAGE_POOL_SIZE
  description: "Limbic Capital storage pool"
  name: $STORAGE_POOL_NAME
  driver: zfs
profiles:
- config: {}
  description: "Default LXD profile"
  devices:
    eth0:
      name: eth0
      network: $NETWORK_NAME
      type: nic
    root:
      path: /
      pool: $STORAGE_POOL_NAME
      type: disk
  name: default
cluster: null
EOF

echo "  ✅ Preseed configuration created"

# ==============================================================================
# Initialize LXD
# ==============================================================================

echo ""
echo "🚀 Initializing LXD..."

# Check if already initialized
if sudo lxd waitready 2>/dev/null; then
    echo "  ⚠️  LXD appears to be already initialized"
    read -p "  Reinitialize? This will delete existing containers! (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "  🔄 Reinitializing LXD..."
        sudo lxd init --preseed < "$PRESEED_FILE"
    else
        echo "  ℹ️  Skipping initialization"
    fi
else
    sudo lxd init --preseed < "$PRESEED_FILE"
fi

echo "  ✅ LXD initialized"

# Wait for LXD to be ready
echo "  ⏳ Waiting for LXD to be ready..."
sudo lxd waitready --timeout=30

# ==============================================================================
# Verify Installation
# ==============================================================================

echo ""
echo "🔍 Verifying LXD installation..."

# Check LXD version
LXD_VERSION=$(lxc version)
echo "  ✅ LXD version: $LXD_VERSION"

# List storage pools
echo ""
echo "  📦 Storage pools:"
lxc storage list

# List networks
echo ""
echo "  🌐 Networks:"
lxc network list

# List profiles
echo ""
echo "  👤 Profiles:"
lxc profile list

# Show network details
echo ""
echo "  🔍 Network details ($NETWORK_NAME):"
lxc network show $NETWORK_NAME

# ==============================================================================
# Test with Ubuntu Image
# ==============================================================================

echo ""
read -p "Test LXD by launching a test container? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "  🧪 Launching test container..."
    
    # Launch test container
    lxc launch ubuntu:22.04 test-container
    
    echo "  ⏳ Waiting for container to start..."
    sleep 5
    
    # Check container status
    lxc list
    
    # Test network connectivity
    echo ""
    echo "  🌐 Testing network connectivity..."
    lxc exec test-container -- ping -c 3 8.8.8.8
    
    echo ""
    echo "  ✅ Test successful!"
    echo ""
    read -p "Delete test container? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lxc stop test-container
        lxc delete test-container
        echo "  ✅ Test container deleted"
    else
        echo "  ℹ️  Test container kept (name: test-container)"
    fi
fi

# ==============================================================================
# Configure LXD Networking for Docker
# ==============================================================================

echo ""
echo "🐳 Configuring LXD for Docker support..."

# Enable necessary kernel modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Make persistent
cat <<EOF | sudo tee /etc/modules-load.d/lxd-docker.conf
overlay
br_netfilter
EOF

# Configure sysctl for container networking
cat <<EOF | sudo tee /etc/sysctl.d/99-lxd-docker.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "  ✅ Kernel modules and networking configured"

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "================================"
echo "✅ LXD Setup Complete!"
echo "================================"
echo ""
echo "📋 Summary:"
echo "  - LXD version: $LXD_VERSION"
echo "  - Storage pool: $STORAGE_POOL_NAME ($STORAGE_POOL_SIZE)"
echo "  - Network: $NETWORK_NAME ($NETWORK_SUBNET)"
echo "  - DHCP range: $NETWORK_DHCP_START - $NETWORK_DHCP_END"
echo ""
echo "📖 Useful LXD commands:"
echo "  lxc list                    # List containers"
echo "  lxc launch ubuntu:22.04 name # Launch container"
echo "  lxc exec name -- bash       # Enter container"
echo "  lxc stop name               # Stop container"
echo "  lxc delete name             # Delete container"
echo "  lxc network list            # List networks"
echo "  lxc storage list            # List storage pools"
echo ""
echo "Next step: Run ./03-create-app-container.sh"
echo ""
