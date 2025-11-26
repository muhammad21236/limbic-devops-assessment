# Limbic DevOps Assessment – LXD, Docker, Cloudflare Tunnel

This repo deploys a small, secure stack on Ubuntu: one LXD container that runs Docker, two demo apps (Node.js and Python), and Cloudflare Tunnel for HTTPS access without opening any inbound ports.

## What You Get

- Ubuntu 22.04 host locked down to SSH.
- One LXD container (`app-host`) with Docker installed.
- Two services via Docker Compose:
  - `app1` (Node.js, port 3000)
  - `app2` (Flask, port 5000)
- Cloudflare Tunnel (`cloudflared`) routing requests to the apps over an encrypted tunnel.

## Prerequisites

- Ubuntu 22.04 (VM/VPS) with sudo and SSH key login.
- Cloudflare account with a domain on Cloudflare (Quick Tunnel also works for testing).
- Git installed on the server.

## Quick Start

All commands run on the Ubuntu server unless noted.

1. Clone the repo

   ```bash
   git clone https://github.com/muhammad21236/limbic-devops-assessment.git
   cd limbic-devops-assessment
   ```

1. Base hardening (create sudo user, secure SSH, enable UFW)

   ```bash
   chmod +x scripts/01-base-setup.sh
   # Edit the script to set your username and SSH public key first
   nano scripts/01-base-setup.sh
   ./scripts/01-base-setup.sh
   ```

1. Install and initialize LXD

   ```bash
   chmod +x scripts/02-lxd-setup.sh
   ./scripts/02-lxd-setup.sh
   ```

1. Create the application container and install Docker inside it

   ```bash
   chmod +x scripts/03-create-app-container.sh
   ./scripts/03-create-app-container.sh
   ```

1. Deploy the apps with Docker Compose (run inside the container)

   ```bash
   lxc exec app-host -- bash -lc "mkdir -p /opt/apps && rm -rf /opt/apps/* && exit"
   lxc file push -r docker/ app-host/opt/apps/
   lxc exec app-host -- bash -lc "cd /opt/apps && docker compose up -d"
   ```

1. Set up Cloudflare Tunnel (inside the container)

   ```bash
   # Install cloudflared (amd64 example)
   lxc exec app-host -- bash -lc "wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb \ \
     && dpkg -i cloudflared-linux-amd64.deb"

   # Authenticate and create/use a tunnel (follow the URL shown)
   lxc exec app-host -- bash -lc "cloudflared tunnel login"
   lxc exec app-host -- bash -lc "cloudflared tunnel create limbic-apps"

   # Write config (replace hostnames and it will auto-pick the tunnel ID)
   lxc exec app-host -- bash -lc 'TID=$(cloudflared tunnel list | awk "/^limbic-apps/ {print \$1}"); \
     mkdir -p /etc/cloudflared; \
     cat > /etc/cloudflared/config.yml <<EOF\
   tunnel: ${TID}\
   credentials-file: /root/.cloudflared/${TID}.json\
   ingress:\
     - hostname: app1.example.com\
       service: http://localhost:3000\
     - hostname: app2.example.com\
       service: http://localhost:5000\
     - service: http_status:404\
   EOF'

   # Create DNS routes for your domain
   lxc exec app-host -- bash -lc "cloudflared tunnel route dns limbic-apps app1.example.com"
   lxc exec app-host -- bash -lc "cloudflared tunnel route dns limbic-apps app2.example.com"

   # Run the tunnel (or install as a service)
   lxc exec app-host -- bash -lc "cloudflared tunnel run limbic-apps"  # foreground
   # or
   lxc exec app-host -- bash -lc "cloudflared service install && systemctl enable --now cloudflared"
   ```

## Verify

From your machine (or any browser):

```bash
curl https://app1.example.com/
curl https://app1.example.com/ping
curl https://app1.example.com/call-app2
# app2: https://app2.example.com/status (may require Cloudflare Access if enabled)
```

## Repository Layout

- `scripts/`: server hardening, LXD init, container provisioning
- `docker/`: `docker-compose.yml`, `app1` (Node.js), `app2` (Flask)
- `cloudflare/`: `config.yml.example` template for `cloudflared`
- `lxd-config/`: optional preseed for `lxd init`

For a longer, step‑by‑step guide, see `DEPLOYMENT-GUIDE.md`.
