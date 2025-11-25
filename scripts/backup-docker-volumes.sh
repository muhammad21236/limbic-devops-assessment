#!/bin/bash

################################################################################
# Backup Script - Docker Volumes
# 
# Backs up all Docker volumes to compressed archives
################################################################################

set -e

BACKUP_DIR="/opt/backups/docker"
DATE=$(date +%Y%m%d-%H%M%S)
RETENTION_DAYS=30

echo "🔄 Starting Docker volume backup..."
echo "Backup directory: $BACKUP_DIR"
echo "Date: $DATE"

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup each volume
for volume in $(docker volume ls -q); do
    echo "📦 Backing up volume: $volume"
    docker run --rm \
        -v $volume:/source:ro \
        -v $BACKUP_DIR:/backup \
        alpine tar czf /backup/${volume}-${DATE}.tar.gz -C /source .
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Backup successful: ${volume}-${DATE}.tar.gz"
    else
        echo "  ❌ Backup failed for: $volume"
    fi
done

# Clean up old backups
echo ""
echo "🧹 Cleaning up backups older than $RETENTION_DAYS days..."
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo ""
echo "✅ Backup completed!"
ls -lh $BACKUP_DIR
