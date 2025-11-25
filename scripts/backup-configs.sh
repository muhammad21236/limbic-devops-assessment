#!/bin/bash

################################################################################
# Backup Script - Configuration Files
# 
# Backs up important configuration files and settings
################################################################################

set -e

BACKUP_DIR="/opt/backups/configs/$(date +%Y%m%d)"
DATE=$(date +%Y%m%d-%H%M%S)

echo "🔄 Starting configuration backup..."
echo "Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup Cloudflare config
if [ -d "/etc/cloudflared" ]; then
    echo "📋 Backing up Cloudflare Tunnel config..."
    cp -r /etc/cloudflared $BACKUP_DIR/
    echo "  ✅ Cloudflare config backed up"
fi

# Backup Docker Compose files
if [ -f "/opt/apps/docker-compose.yml" ]; then
    echo "📋 Backing up Docker Compose config..."
    cp /opt/apps/docker-compose.yml $BACKUP_DIR/
    echo "  ✅ Docker Compose config backed up"
fi

# Backup environment files (be careful with secrets!)
if [ -f "/opt/apps/.env" ]; then
    echo "📋 Backing up environment variables..."
    cp /opt/apps/.env $BACKUP_DIR/
    chmod 600 $BACKUP_DIR/.env
    echo "  ✅ Environment variables backed up"
fi

# Create archive
echo ""
echo "📦 Creating compressed archive..."
cd /opt/backups/configs
tar czf config-backup-${DATE}.tar.gz $(basename $BACKUP_DIR)

echo ""
echo "✅ Configuration backup completed!"
echo "Archive: /opt/backups/configs/config-backup-${DATE}.tar.gz"
ls -lh /opt/backups/configs/config-backup-${DATE}.tar.gz
