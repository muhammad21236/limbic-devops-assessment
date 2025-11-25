# Demo Video Checklist

This checklist will help you prepare and record your demo video for the Limbic Capital DevOps Technical Assessment.

## 🎯 Objective
Record a 10-15 minute screen-share video demonstrating your complete setup and explaining the architecture.

## 🎬 Recording Setup

### Recommended Tools
- **macOS**: QuickTime, Screen Studio, or OBS Studio
- **Windows**: OBS Studio, Xbox Game Bar, or ShareX
- **Linux**: SimpleScreenRecorder, OBS Studio, or Kazam
- **Cloud**: Loom (free tier available)

### Recording Settings
- **Resolution**: 1920x1080 (1080p) minimum
- **Frame Rate**: 30 FPS minimum
- **Audio**: Clear microphone (test before recording)
- **Format**: MP4 (most compatible)

### Preparation
- [ ] Close unnecessary applications
- [ ] Clear terminal history
- [ ] Prepare all commands in advance
- [ ] Test audio levels
- [ ] Have architecture diagrams open
- [ ] Ensure good lighting (if showing face)

## 📝 Demo Script

### Introduction (1 minute)
- [ ] Introduce yourself
- [ ] Briefly describe the project goal
- [ ] Mention key technologies: LXD, Docker, Cloudflare Tunnel

**Script Example:**
```
"Hi, I'm [Your Name]. Today I'll be demonstrating my DevOps assessment 
for Limbic Capital. I've built a secure multi-layer infrastructure using 
LXD containers, Docker, and Cloudflare Tunnels to deploy a microservices 
application without exposing any ports on the VPS."
```

### Architecture Overview (2-3 minutes)
- [ ] Show README.md with architecture diagram
- [ ] Explain the traffic flow: User → Cloudflare → Tunnel → LXD → Docker → Apps
- [ ] Highlight security layers
- [ ] Explain network isolation

**What to Show:**
```bash
# Display architecture diagram
cat README.md | grep -A 50 "Architecture Overview"

# Or open in VS Code/browser if Mermaid is rendered
```

### Host Server Configuration (1-2 minutes)
- [ ] Show UFW firewall rules
- [ ] Demonstrate SSH configuration
- [ ] Show only SSH port is open

**Commands to Run:**
```bash
# On host VPS
sudo ufw status verbose
cat /etc/ssh/sshd_config.d/99-limbic-hardening.conf
sudo netstat -tlnp  # Show no HTTP/HTTPS ports listening
```

### LXD Setup (1-2 minutes)
- [ ] List LXD containers
- [ ] Show LXD network configuration
- [ ] Show storage pool
- [ ] Display container info

**Commands to Run:**
```bash
lxc list
lxc network show lxdbr0
lxc storage list
lxc info app-host
```

### Docker Stack (2-3 minutes)
- [ ] Enter LXD container
- [ ] Show running Docker containers
- [ ] Display Docker network
- [ ] Show docker-compose.yml

**Commands to Run:**
```bash
# Enter container
lxc exec app-host -- bash

# Inside container
docker ps
docker network inspect internal_net
cat /opt/apps/docker-compose.yml
```

### Application Testing (3-4 minutes)
- [ ] Open browser and access app1.example.com
- [ ] Show welcome page
- [ ] Test /ping endpoint
- [ ] Demonstrate /call-app2 (internal service communication)
- [ ] Show the response JSON with app2 data
- [ ] Access app2.example.com
- [ ] Demonstrate Cloudflare Access authentication
- [ ] Show /status endpoint

**What to Show:**
```bash
# In browser:
https://app1.example.com/
https://app1.example.com/ping
https://app1.example.com/call-app2

# This should show authentication:
https://app2.example.com/status

# Or test via curl:
curl https://app1.example.com/call-app2 | jq
```

### Cloudflare Tunnel (1-2 minutes)
- [ ] Show cloudflared service status
- [ ] Display tunnel configuration
- [ ] Show Cloudflare dashboard (optional)
- [ ] Verify tunnel is connected

**Commands to Run:**
```bash
# Inside app-host container
systemctl status cloudflared
cat /etc/cloudflared/config.yml
journalctl -u cloudflared -n 20

# Check tunnel
cloudflared tunnel info limbic-tunnel
```

### Service Recovery (1-2 minutes)
- [ ] Restart one service (e.g., app1)
- [ ] Show logs during restart
- [ ] Verify service comes back up
- [ ] Test endpoint to confirm recovery

**Commands to Run:**
```bash
# Restart app1
docker restart app1

# Watch logs
docker logs -f app1

# Test recovery
curl http://localhost:3000/ping

# Or test externally
curl https://app1.example.com/ping
```

### Production Improvements Discussion (1-2 minutes)
- [ ] Discuss monitoring and alerting needs
- [ ] Mention high availability setup
- [ ] Talk about CI/CD pipeline
- [ ] Discuss additional security measures

**Topics to Cover:**
- Prometheus/Grafana for monitoring
- ELK stack for centralized logging
- Multiple VPS instances for HA
- Automated backups and disaster recovery
- Infrastructure as Code (Terraform)
- Secret management (HashiCorp Vault)
- Regular security audits

### Conclusion (30 seconds)
- [ ] Summarize what was demonstrated
- [ ] Thank the reviewers
- [ ] Mention documentation availability

**Script Example:**
```
"This completes my demonstration. I've shown a secure, multi-layered 
infrastructure with zero open ports, protected by Cloudflare's network. 
All documentation, scripts, and code are available in the Git repository. 
Thank you for your time."
```

## 🎥 Recording Tips

### Do's
✅ Speak clearly and at a steady pace
✅ Explain what you're doing before doing it
✅ Show actual working functionality
✅ Demonstrate error recovery
✅ Highlight security features
✅ Keep it within 10-15 minutes

### Don'ts
❌ Don't rush through explanations
❌ Don't show secrets/credentials
❌ Don't spend too much time on one section
❌ Don't read directly from notes (be natural)
❌ Don't skip error handling
❌ Don't forget to test before recording

## 📤 Upload and Share

### Recommended Platforms
- **YouTube**: Upload as unlisted video
- **Vimeo**: Free account available
- **Google Drive**: Share with link
- **Loom**: Direct shareable link

### Video Settings
- [ ] Set to **Unlisted** (not public)
- [ ] Add descriptive title: "Limbic Capital DevOps Assessment - [Your Name]"
- [ ] Add description with GitHub repo link
- [ ] Enable comments (optional)

### Share Link
- [ ] Copy shareable link
- [ ] Test link in incognito/private window
- [ ] Verify video plays correctly
- [ ] Add link to README.md

## ✅ Final Checklist

Before submitting:
- [ ] Video is 10-15 minutes long
- [ ] Audio is clear and understandable
- [ ] All required components demonstrated
- [ ] Shows actual working functionality
- [ ] No secrets/credentials visible
- [ ] Video link works in incognito mode
- [ ] GitHub repository is complete
- [ ] README.md is comprehensive
- [ ] All scripts are documented

## 📧 Submission

Submit both:
1. **Git Repository Link**: GitHub/GitLab URL
2. **Demo Video Link**: YouTube/Vimeo/Loom/Drive URL

---

**Good luck with your demo! 🚀**
