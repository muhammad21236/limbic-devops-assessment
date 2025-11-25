# Quick Start Guide

This guide will help you get the entire stack up and running quickly.

## ⚡ Prerequisites

- Fresh Ubuntu 22.04 VPS
- Root SSH access
- Domain configured in Cloudflare
- SSH key pair generated locally

## 🚀 Quick Setup (Complete Stack)

### Step 1: Initial Connection

```bash
# Connect to VPS as root
ssh root@your-vps-ip
```

### Step 2: Clone Repository

```bash
cd /tmp
git clone https://github.com/yourusername/limbic-devops-assessment.git
cd limbic-devops-assessment
```

### Step 3: Base Setup (5 minutes)

```bash
# Edit script with your SSH key
nano scripts/01-base-setup.sh
# Replace SSH_PUBLIC_KEY with your actual key

# Run base setup
chmod +x scripts/01-base-setup.sh
./scripts/01-base-setup.sh

# IMPORTANT: Test new user login in a separate terminal before closing root session!
# ssh -i ~/.ssh/your_key deployuser@your-vps-ip
```

### Step 4: LXD Setup (3 minutes)

```bash
# Now using new user (not root)
ssh deployuser@your-vps-ip

cd ~/
git clone https://github.com/yourusername/limbic-devops-assessment.git
cd limbic-devops-assessment

# Run LXD setup
chmod +x scripts/02-lxd-setup.sh
./scripts/02-lxd-setup.sh

# Activate LXD group
newgrp lxd
```

### Step 5: Create App Container (3 minutes)

```bash
# Run container creation script
chmod +x scripts/03-create-app-container.sh
./scripts/03-create-app-container.sh
```

### Step 6: Deploy Docker Applications (2 minutes)

```bash
# Push Docker files to container
lxc file push -r docker/ app-host/opt/apps/

# Enter container
lxc exec app-host -- bash

# Inside container - start Docker stack
cd /opt/apps
docker compose up -d

# Verify containers are running
docker ps

# Test internal connectivity
docker exec app1 curl http://app2:5000/status

# Exit container
exit
```

### Step 7: Configure Cloudflare Tunnel (5 minutes)

```bash
# Enter container
lxc exec app-host -- bash

# Install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Authenticate
cloudflared tunnel login

# Create tunnel
cloudflared tunnel create limbic-tunnel
# Note the tunnel ID from output

# Create config directory
sudo mkdir -p /etc/cloudflared

# Copy credentials
sudo cp ~/.cloudflared/<TUNNEL_ID>.json /etc/cloudflared/

# Edit config file
sudo nano /etc/cloudflared/config.yml

# Paste this (replace YOUR_TUNNEL_ID and YOUR_DOMAIN):
# tunnel: YOUR_TUNNEL_ID
# credentials-file: /etc/cloudflared/YOUR_TUNNEL_ID.json
# ingress:
#   - hostname: app1.YOUR_DOMAIN.com
#     service: http://localhost:3000
#   - hostname: app2.YOUR_DOMAIN.com
#     service: http://localhost:5000
#   - service: http_status:404

# Route DNS
cloudflared tunnel route dns limbic-tunnel app1.yourdomain.com
cloudflared tunnel route dns limbic-tunnel app2.yourdomain.com

# Install as service
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Check status
systemctl status cloudflared
```

### Step 8: Configure Cloudflare Access (3 minutes)

1. Go to: https://one.dash.cloudflare.com/
2. Navigate to **Access → Applications**
3. Click **Add an application** → **Self-hosted**
4. Configure:
   - Name: App 2 API
   - Domain: app2.yourdomain.com
   - Session: 24 hours
5. Add policy:
   - Name: Allow Emails
   - Action: Allow
   - Include: Emails ending in: yourdomain.com (or specific emails)
6. Save application

### Step 9: Test Everything! (2 minutes)

```bash
# From your local machine
curl https://app1.yourdomain.com/
curl https://app1.yourdomain.com/ping
curl https://app1.yourdomain.com/call-app2

# Open in browser (will require authentication):
# https://app2.yourdomain.com/status
```

## 🎯 That's It!

Total setup time: ~20-30 minutes

## 🔧 Useful Commands

### Check Status
```bash
# On host
lxc list
lxc exec app-host -- docker ps

# Inside container
docker ps
systemctl status cloudflared
docker logs app1
docker logs app2
```

### Restart Services
```bash
# Restart Docker containers
lxc exec app-host -- docker restart app1
lxc exec app-host -- docker restart app2

# Restart Cloudflare tunnel
lxc exec app-host -- systemctl restart cloudflared
```

### View Logs
```bash
# Docker logs
lxc exec app-host -- docker logs -f app1
lxc exec app-host -- docker logs -f app2

# Cloudflare logs
lxc exec app-host -- journalctl -u cloudflared -f
```

## 🆘 Troubleshooting

### Applications not accessible
```bash
# Check containers
lxc exec app-host -- docker ps

# Check if apps respond locally
lxc exec app-host -- curl http://localhost:3000/ping
lxc exec app-host -- curl http://localhost:5000/status

# Restart if needed
lxc exec app-host -- docker compose -f /opt/apps/docker-compose.yml restart
```

### Tunnel not working
```bash
# Check tunnel status
lxc exec app-host -- systemctl status cloudflared

# View logs
lxc exec app-host -- journalctl -u cloudflared -n 50

# Restart tunnel
lxc exec app-host -- systemctl restart cloudflared
```

### DNS not resolving
```bash
# Check DNS
nslookup app1.yourdomain.com
dig app1.yourdomain.com

# Verify in Cloudflare dashboard:
# - CNAME records exist
# - Proxy is enabled (orange cloud)
```

## 📚 Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Review [DEMO_CHECKLIST.md](DEMO_CHECKLIST.md) for video recording
- Explore backup scripts in `scripts/` directory
- Check Cloudflare documentation in `cloudflare/` directory

---

**Need help?** Refer to the comprehensive README.md or troubleshooting sections.
