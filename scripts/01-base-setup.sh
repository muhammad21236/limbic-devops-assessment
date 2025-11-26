#!/bin/bash

################################################################################
# Base Server Setup Script for Limbic Capital DevOps Assessment
# 
# This script performs initial server hardening and user configuration:
# - Creates a non-root sudo user
# - Configures SSH key authentication
# - Disables password and root SSH login
# - Configures UFW firewall (SSH only)
# - Updates system packages
#
# Usage: Edit variables below, then run as root: sudo ./01-base-setup.sh
################################################################################

set -e  # Exit on any error

# ==============================================================================
# CONFIGURATION - EDIT THESE VALUES
# ==============================================================================

# New sudo user to create
NEW_USER="deployuser"

# Your SSH public key (paste your ~/.ssh/id_rsa.pub content here)
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQD... your-key-here user@hostname"

# SSH port (default: 22, change if desired)
SSH_PORT="22"

# ==============================================================================
# SCRIPT START
# ==============================================================================

echo "================================"
echo "Limbic Capital - Base Setup"
echo "================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root" 
   exit 1
fi

# Validate configuration
if [[ "$SSH_PUBLIC_KEY" == *"your-key-here"* ]]; then
    echo "❌ Please edit the script and add your SSH public key"
    exit 1
fi

echo "📋 Configuration:"
echo "  - New user: $NEW_USER"
echo "  - SSH port: $SSH_PORT"
echo ""
read -p "Continue with setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# ==============================================================================
# System Update
# ==============================================================================

echo ""
echo "📦 Updating system packages..."
apt-get update
apt-get upgrade -y
apt-get install -y \
    ufw \
    fail2ban \
    curl \
    wget \
    git \
    htop \
    net-tools \
    software-properties-common

# ==============================================================================
# User Creation
# ==============================================================================

echo ""
echo "👤 Creating user: $NEW_USER"

# Create user if doesn't exist
if id "$NEW_USER" &>/dev/null; then
    echo "  ℹ️  User $NEW_USER already exists"
else
    useradd -m -s /bin/bash "$NEW_USER"
    echo "  ✅ User created"
fi

# Add to sudo group
usermod -aG sudo "$NEW_USER"
echo "  ✅ Added to sudo group"

# Configure passwordless sudo
echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$NEW_USER
chmod 0440 /etc/sudoers.d/$NEW_USER
echo "  ✅ Configured passwordless sudo"

# ==============================================================================
# SSH Configuration
# ==============================================================================

echo ""
echo "🔐 Configuring SSH..."

# Create .ssh directory
USER_HOME="/home/$NEW_USER"
SSH_DIR="$USER_HOME/.ssh"
mkdir -p "$SSH_DIR"

# Add SSH public key
echo "$SSH_PUBLIC_KEY" > "$SSH_DIR/authorized_keys"
chmod 700 "$SSH_DIR"
chmod 600 "$SSH_DIR/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
echo "  ✅ SSH key added"

# Backup original sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
echo "  ✅ Backed up sshd_config"

# Configure SSH security settings
cat > /etc/ssh/sshd_config.d/99-limbic-hardening.conf <<EOF
# Limbic Capital SSH Hardening Configuration

# Disable root login
PermitRootLogin no

# Disable password authentication
PasswordAuthentication no
ChallengeResponseAuthentication no

# Enable public key authentication
PubkeyAuthentication yes

# Disable empty passwords
PermitEmptyPasswords no

# Disable X11 forwarding
X11Forwarding no

# Set SSH port
Port $SSH_PORT

# Use PAM
UsePAM yes

# Accept locale environment variables
AcceptEnv LANG LC_*

# Enable strict mode
StrictModes yes

# Disable TCP forwarding
AllowTcpForwarding no

# Disable agent forwarding
AllowAgentForwarding no

# Session timeout (5 minutes)
ClientAliveInterval 300
ClientAliveCountMax 2

# Maximum authentication attempts
MaxAuthTries 3

# Log verbosity
LogLevel VERBOSE
EOF

echo "  ✅ SSH hardening configured"

# ==============================================================================
# Firewall Configuration
# ==============================================================================

echo ""
echo "🔥 Configuring UFW firewall..."

# Disable UFW first to avoid lockout
ufw --force disable

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow $SSH_PORT/tcp comment 'SSH'

# Enable UFW
ufw --force enable

echo "  ✅ Firewall configured"
ufw status verbose

# ==============================================================================
# Fail2Ban Configuration
# ==============================================================================

echo ""
echo "🛡️  Configuring Fail2Ban..."

# Create local configuration
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = $SSH_PORT
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF

systemctl enable fail2ban
systemctl restart fail2ban
echo "  ✅ Fail2Ban configured and started"

# ==============================================================================
# Automatic Security Updates
# ==============================================================================

echo ""
echo "🔄 Configuring automatic security updates..."

apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

echo "  ✅ Automatic updates configured"

# ==============================================================================
# System Hardening
# ==============================================================================

echo ""
echo "🔒 Applying system hardening..."

# Disable IPv6 if not needed (optional)
# echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
# sysctl -p

# Kernel hardening
cat >> /etc/sysctl.conf <<EOF

# Limbic Capital - Kernel Hardening
# IP Forwarding (needed for LXD)
net.ipv4.ip_forward = 1

# Protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1
EOF

sysctl -p
echo "  ✅ Kernel parameters configured"

# ==============================================================================
# Restart SSH Service
# ==============================================================================

echo ""
echo "🔄 Restarting SSH service..."
systemctl restart ssh
echo "  ✅ SSH service restarted"

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "================================"
echo "✅ Base Setup Complete!"
echo "================================"
echo ""
echo "📋 Summary:"
echo "  - User created: $NEW_USER"
echo "  - SSH port: $SSH_PORT"
echo "  - SSH key authentication: Enabled"
echo "  - Password authentication: Disabled"
echo "  - Root login: Disabled"
echo "  - Firewall: UFW (SSH only)"
echo "  - Fail2Ban: Enabled"
echo "  - Auto-updates: Enabled"
echo ""
echo "⚠️  IMPORTANT - Test before logging out!"
echo ""
echo "In a NEW terminal window, test SSH access:"
echo "  ssh -i ~/.ssh/your_key $NEW_USER@$(hostname -I | awk '{print $1}') -p $SSH_PORT"
echo ""
echo "If successful, you can safely close the root session."
echo "If login fails, DO NOT close this window - troubleshoot first!"
echo ""
echo "Next step: Run ./02-lxd-setup.sh"
echo ""
