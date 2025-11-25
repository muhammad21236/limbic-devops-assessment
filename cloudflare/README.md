# Cloudflare Tunnel Configuration Guide

This directory contains configuration files and documentation for setting up Cloudflare Tunnel (formerly Argo Tunnel) to expose your applications securely without opening any ports on your VPS.

## 📋 Overview

Cloudflare Tunnel creates a secure, encrypted connection between your applications and Cloudflare's edge network. Traffic flows:

```
User → Cloudflare Edge → Cloudflare Tunnel → Your Application
```

**Benefits:**
- ✅ No inbound firewall ports required
- ✅ Automatic DDoS protection
- ✅ Built-in SSL/TLS
- ✅ Zero Trust Access integration
- ✅ Global CDN caching

## 🚀 Setup Instructions

### Prerequisites

1. **Cloudflare Account**: Free or paid account
2. **Domain**: Added to Cloudflare (nameservers pointed to Cloudflare)
3. **Zero Trust Access**: Enabled in your Cloudflare account

### Step 1: Install cloudflared

Inside your LXD container (`app-host`):

```bash
# Enter container
lxc exec app-host -- bash

# Download and install cloudflared
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Verify installation
cloudflared --version
```

### Step 2: Authenticate with Cloudflare

```bash
# This will open a browser for authentication
cloudflared tunnel login
```

This creates a credentials file at `~/.cloudflared/cert.pem`

### Step 3: Create a Tunnel

```bash
# Create tunnel named 'limbic-tunnel'
cloudflared tunnel create limbic-tunnel

# Note the Tunnel ID from the output
# Example: Created tunnel limbic-tunnel with id abc123...
```

This creates a credentials JSON file at:
```
~/.cloudflared/<TUNNEL_ID>.json
```

### Step 4: Configure the Tunnel

```bash
# Create cloudflared config directory
sudo mkdir -p /etc/cloudflared

# Copy credentials
sudo cp ~/.cloudflared/<TUNNEL_ID>.json /etc/cloudflared/

# Copy and edit config file
sudo cp /opt/apps/cloudflare/config.yml.example /etc/cloudflared/config.yml
sudo nano /etc/cloudflared/config.yml
```

**Edit the following in config.yml:**

1. Replace `YOUR_TUNNEL_ID` with your actual tunnel ID
2. Replace `YOUR_TUNNEL_CREDENTIALS_FILE` with your credentials filename
3. Replace `YOUR_DOMAIN` with your actual domain

**Example:**
```yaml
tunnel: abc123-def456-ghi789
credentials-file: /etc/cloudflared/abc123-def456-ghi789.json

ingress:
  - hostname: app1.example.com
    service: http://localhost:3000
  - hostname: app2.example.com
    service: http://localhost:5000
  - service: http_status:404
```

### Step 5: Configure DNS in Cloudflare

You have two options:

#### Option A: Manual DNS Configuration

In Cloudflare Dashboard → DNS → Records, add:

```
Type: CNAME
Name: app1
Target: <TUNNEL_ID>.cfargotunnel.com
Proxy: Enabled (orange cloud)

Type: CNAME
Name: app2
Target: <TUNNEL_ID>.cfargotunnel.com
Proxy: Enabled (orange cloud)
```

#### Option B: Automatic DNS via CLI

```bash
# Route app1 subdomain
cloudflared tunnel route dns limbic-tunnel app1.example.com

# Route app2 subdomain
cloudflared tunnel route dns limbic-tunnel app2.example.com
```

### Step 6: Install as System Service

```bash
# Install cloudflared as a systemd service
sudo cloudflared service install

# Start the service
sudo systemctl start cloudflared

# Enable on boot
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

### Step 7: Verify Tunnel is Running

```bash
# Check service status
systemctl status cloudflared

# View logs
journalctl -u cloudflared -f

# Check tunnel info
cloudflared tunnel info limbic-tunnel

# List all tunnels
cloudflared tunnel list
```

### Step 8: Test Access

```bash
# From your local machine
curl https://app1.example.com/
curl https://app1.example.com/ping
curl https://app1.example.com/call-app2

# Note: app2.example.com requires authentication (setup next)
```

## 🔒 Cloudflare Zero Trust Access Setup

Protect App 2 with authentication.

### Step 1: Access Cloudflare Zero Trust Dashboard

1. Go to: https://one.dash.cloudflare.com/
2. Select your account
3. Navigate to **Access → Applications**

### Step 2: Create Application

Click **Add an application** → **Self-hosted**

**Application Configuration:**
- **Application name**: App 2 API
- **Application domain**: `app2.example.com`
- **Session duration**: 24 hours (or your preference)

### Step 3: Configure Policy

**Create an Access Policy:**

**Policy 1: Email Domain**
- **Name**: Allow Company Domain
- **Action**: Allow
- **Rule type**: Include
- **Selector**: Emails ending in
- **Value**: `yourcompany.com`

OR

**Policy 2: Specific Emails**
- **Name**: Allow Specific Users
- **Action**: Allow
- **Rule type**: Include
- **Selector**: Email
- **Values**: `user@example.com`, `admin@example.com`

OR

**Policy 3: One-Time PIN**
- **Name**: Allow via OTP
- **Action**: Allow
- **Rule type**: Include
- **Selector**: Emails
- **Values**: Anyone with a verified email

### Step 4: Save and Test

1. Click **Save application**
2. Visit `https://app2.example.com` in browser
3. You should see Cloudflare Access login page
4. Authenticate and verify access

### Step 5: Optional - Add Additional Settings

**Additional Settings:**
- **Enable CORS**: If your app needs CORS
- **Cookie settings**: Customize session cookies
- **IdP Integration**: Connect Azure AD, Okta, Google Workspace, etc.

## 🛠️ Management Commands

### Restart Tunnel

```bash
sudo systemctl restart cloudflared
```

### View Logs

```bash
# Real-time logs
journalctl -u cloudflared -f

# Last 100 lines
journalctl -u cloudflared -n 100

# Logs since specific time
journalctl -u cloudflared --since "1 hour ago"
```

### Update Tunnel Configuration

```bash
# Edit config
sudo nano /etc/cloudflared/config.yml

# Reload (for config changes that don't require restart)
sudo systemctl reload cloudflared

# Or restart for all changes
sudo systemctl restart cloudflared
```

### Check Tunnel Status

```bash
# Systemd service status
systemctl status cloudflared

# Tunnel info
cloudflared tunnel info limbic-tunnel

# List all tunnels
cloudflared tunnel list

# Check tunnel connections
cloudflared tunnel info limbic-tunnel --output json | jq '.connections'
```

### Delete Tunnel (if needed)

```bash
# Stop service
sudo systemctl stop cloudflared
sudo systemctl disable cloudflared

# Uninstall service
sudo cloudflared service uninstall

# Delete tunnel
cloudflared tunnel delete limbic-tunnel

# Remove credentials
rm ~/.cloudflared/<TUNNEL_ID>.json
sudo rm /etc/cloudflared/<TUNNEL_ID>.json
```

## 🔍 Troubleshooting

### Tunnel Not Connecting

**Check service status:**
```bash
systemctl status cloudflared
journalctl -u cloudflared -n 50
```

**Common issues:**
- Incorrect tunnel ID in config.yml
- Wrong path to credentials file
- Firewall blocking outbound QUIC (port 7844)
- DNS not properly configured

### Application Not Accessible

**Verify Docker containers are running:**
```bash
docker ps
```

**Test local connectivity:**
```bash
curl http://localhost:3000
curl http://localhost:5000
```

**Check cloudflared logs:**
```bash
journalctl -u cloudflared -f
```

### DNS Not Resolving

**Check DNS records:**
```bash
nslookup app1.example.com
dig app1.example.com
```

**Verify in Cloudflare:**
- Go to Cloudflare Dashboard → DNS
- Ensure CNAME records exist
- Ensure proxy is enabled (orange cloud)

### Cloudflare Access Not Working

**Check application configuration:**
- Verify domain matches exactly
- Check policy rules are correct
- Ensure email/IdP is properly configured

**Test authentication:**
- Clear browser cookies
- Try incognito/private browsing
- Check Access logs in Cloudflare dashboard

## 📊 Monitoring

### Metrics Endpoint

Cloudflared exposes Prometheus metrics:

```bash
# Access metrics (if metrics port is configured)
curl http://localhost:2000/metrics
```

**Key metrics:**
- `cloudflared_tunnel_connections_registered`: Active connections
- `cloudflared_tunnel_total_requests`: Request count
- `cloudflared_tunnel_request_errors`: Error count

### Health Checks

```bash
# Application health
curl https://app1.example.com/ping
curl https://app2.example.com/status  # Requires auth

# Tunnel health
cloudflared tunnel info limbic-tunnel
```

## 🔐 Security Best Practices

1. **Credentials Protection**
   - Never commit credentials to git
   - Store credentials with restricted permissions (600)
   - Rotate tunnel credentials periodically

2. **Access Control**
   - Use Zero Trust Access for sensitive endpoints
   - Implement least-privilege policies
   - Regularly audit access logs

3. **Monitoring**
   - Enable detailed logging
   - Set up alerts for failed connections
   - Monitor authentication attempts

4. **Configuration**
   - Use specific hostnames (avoid wildcards)
   - Set reasonable connection timeouts
   - Enable HTTP/2 for better performance

## 📚 Additional Resources

- **Cloudflare Tunnel Docs**: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/
- **Zero Trust Access**: https://developers.cloudflare.com/cloudflare-one/policies/access/
- **Tunnel GitHub**: https://github.com/cloudflare/cloudflared
- **Community Forum**: https://community.cloudflare.com/

## 🆘 Support

If you encounter issues:

1. Check logs: `journalctl -u cloudflared -f`
2. Verify config: `cat /etc/cloudflared/config.yml`
3. Test connectivity: `cloudflared tunnel info`
4. Review Cloudflare dashboard for errors

---

**Part of Limbic Capital DevOps Technical Assessment**
