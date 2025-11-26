# Limbic Capital DevOps Assessment - Complete Deployment Guide

## 📋 Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Testing & Verification](#testing--verification)
6. [Cloudflare Tunnel Setup](#cloudflare-tunnel-setup)
7. [Troubleshooting](#troubleshooting)
8. [Key Learnings](#key-learnings)

---

## Overview

This project demonstrates a **secure, multi-layered infrastructure** setup featuring:
- **Ubuntu VPS** with hardened security (SSH key-only, UFW firewall)
- **LXD containers** for application isolation
- **Docker** running inside LXD for application deployment
- **Cloudflare Tunnel** for zero-port exposure to the internet
- **Two applications**: Node.js web app and Python Flask API
- **Internal communication** between services without external exposure

### 🎯 Key Achievement
Successfully deployed a production-grade infrastructure with **ZERO open ports** exposed to the internet (except SSH), with all application access routed through Cloudflare's secure tunnel.

---

## Architecture

```
Internet
    ↓
Cloudflare Tunnel (cloudflared)
    ↓
Ubuntu VPS (AWS EC2)
    ├── SSH Only (Port 22)
    ├── UFW Firewall
    └── LXD Container (app-host)
        ├── Static IP: 10.10.10.100
        └── Docker Engine
            ├── App1 (Node.js) - Port 3000
            │   └── Calls App2 internally
            └── App2 (Python Flask) - Port 5000
                └── Protected by Cloudflare Zero Trust
```

### Network Flow
1. **Internet → Cloudflare Tunnel** - All external traffic routes through Cloudflare
2. **Cloudflare → VPS** - Encrypted tunnel connection (no open ports needed)
3. **VPS → LXD Container** - Isolated network bridge (10.10.10.0/24)
4. **LXD → Docker** - Internal Docker network (172.20.0.0/16)
5. **App1 ↔ App2** - Internal Docker DNS resolution

---

## Prerequisites

### Local Machine
- Git
- SSH client
- Code editor

### AWS EC2 Instance
- Ubuntu 22.04 LTS
- Minimum: t2.medium (2 vCPU, 4GB RAM)
- Recommended: t2.large (2 vCPU, 8GB RAM) for better Docker build performance
- 30GB storage minimum
- SSH key pair for access

### Cloudflare Account
- Free account at cloudflare.com
- Domain registered (can use free Cloudflare domain)
- Zero Trust Access enabled

---

## Step-by-Step Deployment

### Phase 1: VPS Base Setup

**Duration**: ~10 minutes

1. **SSH into your EC2 instance**:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/muhammad21236/limbic-devops-assessment.git
   cd limbic-devops-assessment
   ```

3. **Configure SSH public key**:
   - Extract public key from your .pem file:
     ```bash
     ssh-keygen -y -f your-key.pem
     ```
   - Edit `scripts/01-base-setup.sh`
   - Add your public key to the `SSH_PUBLIC_KEY` variable

4. **Run base setup script**:
   ```bash
   sudo bash scripts/01-base-setup.sh
   ```
   
   **What it does**:
   - Creates `deployuser` with sudo access
   - Configures SSH key-only authentication
   - Hardens SSH (disables root login, password auth)
   - Sets up UFW firewall (SSH only)
   - Installs Fail2Ban for brute-force protection
   - Applies kernel hardening settings

5. **Exit and reconnect as deployuser**:
   ```bash
   exit
   ssh -i your-key.pem deployuser@your-ec2-ip
   ```

### Phase 2: LXD Container Platform Setup

**Duration**: ~5 minutes

1. **Run LXD setup script**:
   ```bash
   cd limbic-devops-assessment
   sudo bash scripts/02-lxd-setup.sh
   ```

   **What it does**:
   - Installs LXD via snap
   - Creates ZFS storage pool (50GB)
   - Configures network bridge (10.10.10.0/24)
   - Loads required kernel modules for Docker
   - Tests container networking

2. **Activate LXD group** (important!):
   ```bash
   newgrp lxd
   ```

### Phase 3: Application Container Setup

**Duration**: ~15-20 minutes

1. **Run container creation script**:
   ```bash
   bash scripts/03-create-app-container.sh
   ```

   **What it does**:
   - Launches Ubuntu 22.04 LXD container
   - Configures static IP (10.10.10.100)
   - Enables Docker-in-LXD security settings
   - Sets up networking with NAT rules
   - Installs Docker and Docker Compose
   - Creates application directory structure

   **Common Issues Encountered**:
   
   a. **Network connectivity issues**:
   - **Problem**: Container couldn't resolve DNS
   - **Solution**: Script automatically adds iptables NAT rules:
     ```bash
     sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 ! -d 10.10.10.0/24 -j MASQUERADE
     ```
   
   b. **Docker permission errors**:
   - **Problem**: `unable to apply apparmor profile`
   - **Solution**: Made container privileged:
     ```bash
     lxc config set app-host security.privileged true
     ```

### Phase 4: Application Deployment

**Duration**: ~10 minutes

1. **Copy application files to container**:
   ```bash
   lxc file push -r docker/ app-host/opt/apps/
   ```

2. **Enter container**:
   ```bash
   lxc exec app-host -- bash
   ```

3. **Navigate to app directory**:
   ```bash
   cd /opt/apps/docker
   ```

4. **Start applications with Docker Compose**:
   ```bash
   docker compose up -d --build
   ```

   **Build time**: 3-5 minutes

5. **Verify containers are running**:
   ```bash
   docker ps
   ```

   Expected output:
   ```
   CONTAINER ID   IMAGE         STATUS          PORTS                    NAMES
   xxxxx          docker-app1   Up (healthy)    0.0.0.0:3000->3000/tcp   app1
   xxxxx          docker-app2   Up (healthy)    0.0.0.0:5000->5000/tcp   app2
   ```

---

## Testing & Verification

### Test 1: App1 Health Check
```bash
docker exec app1 curl http://localhost:3000/ping
```
**Expected**: `{"status":"ok","message":"pong","timestamp":"..."}`

### Test 2: App2 Health Check
```bash
docker exec app2 curl http://localhost:5000/status
```
**Expected**: `{"status":"healthy","service":"app2-api-service",...}`

### Test 3: Internal Communication (App1 → App2)
```bash
docker exec app1 curl http://app2:5000/status
```
**Expected**: JSON response from App2

### Test 4: From Host VPS
```bash
curl http://10.10.10.100:3000/ping
```
**Expected**: `{"status":"ok",...}`

### Test 5: Verify No External Access
From your local machine:
```bash
curl http://your-ec2-ip:3000
```
**Expected**: Connection refused (firewall blocking)

---

## Cloudflare Tunnel Setup

### Step 1: Install Cloudflared

Inside the app-host container:
```bash
cd ~
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared
```

### Step 2: Authenticate
```bash
cloudflared tunnel login
```
- Opens browser for authentication
- Authorizes your Cloudflare account

### Step 3: Create Tunnel
```bash
cloudflared tunnel create limbic-apps
```
- Creates tunnel credentials
- Saves to `~/.cloudflared/`

### Step 4: Configure DNS
```bash
cloudflared tunnel route dns limbic-apps app1.yourdomain.com
cloudflared tunnel route dns limbic-apps app2.yourdomain.com
```

### Step 5: Create Configuration

Create `/etc/cloudflared/config.yml`:
```yaml
tunnel: <your-tunnel-id>
credentials-file: /root/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: app1.yourdomain.com
    service: http://localhost:3000
  
  - hostname: app2.yourdomain.com
    service: http://localhost:5000
  
  - service: http_status:404
```

### Step 6: Run Tunnel
```bash
cloudflared tunnel run limbic-apps
```

### Step 7: Setup as Service
```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl enable cloudflared
```

### Step 8: Configure Zero Trust Access for App2

In Cloudflare Zero Trust dashboard:
1. Navigate to **Access** → **Applications**
2. Click **Add an Application**
3. Select **Self-hosted**
4. Configure:
   - **Application name**: App2 API
   - **Domain**: app2.yourdomain.com
   - **Session duration**: 24 hours
5. Add policy:
   - **Rule name**: Email Authentication
   - **Action**: Allow
   - **Include**: Emails ending in @yourdomain.com

### Verification
```bash
# App1 should be publicly accessible
curl https://app1.yourdomain.com/ping

# App2 requires authentication
curl https://app2.yourdomain.com/status
# Should return Cloudflare login page
```

---

## Troubleshooting

### Issue 1: Container Can't Access Internet

**Symptoms**:
- `apt-get update` fails with "Temporary failure resolving"
- DNS lookups fail

**Solution**:
```bash
# On VPS host
sudo modprobe br_netfilter
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 10.10.10.0/24 ! -d 10.10.10.0/24 -j MASQUERADE
sudo iptables -A FORWARD -i lxdbr0 -j ACCEPT
sudo iptables -A FORWARD -o lxdbr0 -j ACCEPT
```

### Issue 2: Docker Build Out of Memory

**Symptoms**:
- Build fails with exit code 137
- "Killed" message during build

**Solution**:
- Use t2.large instance instead of t2.medium
- Simplify Dockerfiles (remove multi-stage builds if needed)
- Add swap space:
  ```bash
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  ```

### Issue 3: Docker Permission Errors

**Symptoms**:
- `unable to apply apparmor profile`
- `permission denied` errors

**Solution**:
```bash
lxc config set app-host security.privileged true
lxc restart app-host
```

### Issue 4: Container Not Responsive After Launch

**Symptoms**:
- `lxc exec` hangs
- Container shows RUNNING but doesn't respond

**Solution**:
```bash
lxc restart app-host
# Wait 10 seconds
lxc exec app-host -- bash
```

### Issue 5: Flask Version Error

**Symptoms**:
- App2 crashes with `AttributeError: type object 'Flask' has no attribute '__version__'`

**Solution**:
- Updated app.py to import flask module correctly
- Fixed in latest version

---

## Key Learnings

### 1. Security Best Practices Implemented
- ✅ SSH key-only authentication (no passwords)
- ✅ Firewall with minimal ports (SSH only)
- ✅ Fail2Ban for brute-force protection
- ✅ Non-root user with sudo access
- ✅ Kernel hardening parameters
- ✅ Zero Trust Access for sensitive endpoints
- ✅ No direct port exposure (Cloudflare Tunnel)

### 2. LXD Container Insights
- **Nested Docker requires**: `security.nesting=true`
- **Network isolation**: Separate bridge network prevents conflicts
- **Static IPs**: Use netplan inside container for reliability
- **Privileged mode**: Required for full Docker functionality
- **NAT rules**: Must be manually configured on host

### 3. Docker in LXD Challenges
- **Apparmor conflicts**: Solved with privileged containers
- **Memory constraints**: Multi-stage builds can exceed limits
- **Network complexity**: Three layers (host → LXD → Docker)
- **DNS resolution**: Requires proper /etc/resolv.conf configuration

### 4. Cloudflare Tunnel Benefits
- **Zero port exposure**: No inbound firewall rules needed
- **DDoS protection**: Cloudflare's network shields origin
- **SSL/TLS**: Automatic certificate management
- **Zero Trust**: Granular access control without VPN
- **Global CDN**: Low-latency access worldwide

### 5. Production Considerations
- **Monitoring**: Add Prometheus + Grafana for metrics
- **Logging**: Centralize logs with ELK stack or CloudWatch
- **Backups**: Automate LXD snapshots and volume backups
- **CI/CD**: GitHub Actions for automated deployments
- **Secrets**: Use HashiCorp Vault or AWS Secrets Manager
- **High Availability**: Multiple LXD hosts with load balancing

---

## Architecture Decisions

### Why LXD + Docker?

**LXD Layer**:
- Provides OS-level isolation
- Easier system-level management
- Snapshot and migration capabilities
- Resource quotas and limits

**Docker Layer**:
- Application portability
- Microservices architecture
- Easy scaling and updates
- Extensive ecosystem

### Why Cloudflare Tunnel?

**Alternatives Considered**:
1. **Traditional VPN**: More complex, requires client software
2. **Direct port exposure**: Security risk, DDoS vulnerable
3. **AWS ALB**: More expensive, tightly coupled to AWS
4. **Nginx reverse proxy**: Still requires open ports

**Cloudflare Wins**:
- Zero infrastructure changes for remote users
- Built-in DDoS protection
- Integrated Zero Trust Access
- Free for basic use
- Global network performance

### Why Static IP in LXD?

**Benefits**:
- Predictable networking for troubleshooting
- Easier firewall rule management
- Consistent container identity
- Simplified Cloudflare Tunnel configuration

---

## Next Steps for Production

### 1. Enhanced Monitoring
```bash
# Install Prometheus
docker run -d -p 9090:9090 prom/prometheus

# Install Grafana
docker run -d -p 3001:3000 grafana/grafana
```

### 2. Automated Backups
```bash
# LXD snapshot script
lxc snapshot app-host backup-$(date +%Y%m%d)
lxc export app-host backup-$(date +%Y%m%d).tar.gz
```

### 3. CI/CD Pipeline
- GitHub Actions workflow
- Automated testing
- Docker image builds
- Rolling deployments

### 4. High Availability
- Multiple LXD hosts
- Shared storage (NFS/Ceph)
- Load balancer (HAProxy)
- Database replication

### 5. Enhanced Security
- CIS benchmark compliance
- Regular vulnerability scanning
- Automated patching
- Intrusion detection (OSSEC)

---

## Useful Commands Reference

### LXD Management
```bash
# List containers
lxc list

# Enter container shell
lxc exec app-host -- bash

# Container info
lxc info app-host

# Copy files to container
lxc file push local-file.txt app-host/path/

# Copy files from container
lxc file pull app-host/path/file.txt .

# Container snapshots
lxc snapshot app-host snapshot-name
lxc restore app-host snapshot-name

# Network info
lxc network list
lxc network show lxdbr0
```

### Docker Management
```bash
# Inside container
docker ps                    # Running containers
docker ps -a                # All containers
docker logs app1            # Container logs
docker logs -f app1         # Follow logs
docker exec app1 bash       # Enter container
docker compose down         # Stop all services
docker compose up -d        # Start services
docker compose restart app2 # Restart service
docker system prune -af     # Clean everything
```

### Networking Diagnostics
```bash
# Test container connectivity
lxc exec app-host -- ping 8.8.8.8

# Check DNS resolution
lxc exec app-host -- nslookup google.com

# View container IP
lxc list app-host

# Test Docker networking
docker exec app1 curl http://app2:5000/status

# Check iptables NAT
sudo iptables -t nat -L -n -v
```

### Firewall Management
```bash
# UFW status
sudo ufw status verbose

# Allow port temporarily
sudo ufw allow 8080/tcp

# Remove rule
sudo ufw delete allow 8080/tcp

# Reset firewall
sudo ufw reset
```

---

## Conclusion

This project successfully demonstrates:

✅ **Multi-layered security architecture** with zero exposed ports  
✅ **Container orchestration** using LXD and Docker  
✅ **Secure remote access** via Cloudflare Tunnel  
✅ **Zero Trust Access** for sensitive endpoints  
✅ **Production-ready infrastructure** with monitoring and backups  
✅ **Comprehensive documentation** for maintenance and scaling  

### Total Deployment Time
- **Initial setup**: 45-60 minutes
- **With experience**: 20-30 minutes
- **Automation potential**: <10 minutes with scripts

### Skills Demonstrated
- Linux system administration
- Container technologies (LXD, Docker)
- Network architecture and security
- Infrastructure as Code practices
- Cloud platform deployment (AWS)
- CI/CD concepts
- Zero Trust security model
- Technical documentation

---

## Repository Structure
```
limbic-devops-assessment/
├── README.md                  # Project overview
├── QUICKSTART.md             # Quick setup guide
├── DEPLOYMENT-GUIDE.md       # This comprehensive guide
├── scripts/
│   ├── 01-base-setup.sh      # VPS hardening
│   ├── 02-lxd-setup.sh       # LXD installation
│   ├── 03-create-app-container.sh  # Container setup
│   ├── 04-backup.sh          # Backup automation
│   └── 05-health-check.sh    # Monitoring script
├── docker/
│   ├── docker-compose.yml    # Service orchestration
│   ├── app1/                 # Node.js application
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   └── app2/                 # Python Flask API
│       ├── Dockerfile
│       ├── requirements.txt
│       └── app.py
├── cloudflare/
│   ├── config.yml.example    # Tunnel configuration
│   └── README.md             # Setup instructions
└── lxd-config/
    └── preseed.yaml          # LXD initialization
```

---

## Support & Resources

### Documentation
- [LXD Documentation](https://documentation.ubuntu.com/lxd/)
- [Docker Documentation](https://docs.docker.com/)
- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Ubuntu Security Guide](https://ubuntu.com/security)

### Community
- LXD Discourse: https://discourse.ubuntu.com/c/lxd/
- Docker Forums: https://forums.docker.com/
- Cloudflare Community: https://community.cloudflare.com/

### Author
Muhammad  
GitHub: [@muhammad21236](https://github.com/muhammad21236)  
Repository: [limbic-devops-assessment](https://github.com/muhammad21236/limbic-devops-assessment)

---

**Last Updated**: November 25, 2025  
**Version**: 1.0.0  
**Status**: Production Ready ✅
