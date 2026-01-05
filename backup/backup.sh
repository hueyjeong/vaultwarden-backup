#!/bin/bash

# Configuration
DATA_DIR="/data" # Mounted vaultwarden data
BACKUP_DIR="/tmp/backup_stage"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="vaultwarden_backup_${TIMESTAMP}.zip"
RETENTION_DAYS=30
LOG_FILE="/var/log/backup.log"

# Redirect all output to log file AND stdout (for docker logs)
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[$(date)] Starting backup process..."

# 0. Pre-flight Check: Integrity Check
echo "[$(date)] Checking DB integrity..."
if [ -f "$DATA_DIR/db.sqlite3" ]; then
    INTEGRITY=$(sqlite3 "$DATA_DIR/db.sqlite3" "PRAGMA integrity_check;")
    if [ "$INTEGRITY" != "ok" ]; then
        echo "CRITICAL ERROR: Database integrity check failed! Output: $INTEGRITY"
        echo "Aborting backup to prevent overwriting/saving corrupted data."
        exit 1
    else
        echo "Database integrity check passed."
    fi
else
    echo "Warning: db.sqlite3 not found. Skipping integrity check."
fi

# 1. Prepare Staging Area
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# 2. SQLite Backup (Hot Backup) - CRITICAL: Do this first to ensure consistent DB
echo "[$(date)] Creating SQLite snapshot..."
if [ -f "$DATA_DIR/db.sqlite3" ]; then
    sqlite3 "$DATA_DIR/db.sqlite3" ".backup '$BACKUP_DIR/db.sqlite3'"
else
    echo "Warning: db.sqlite3 not found. Skipping DB backup."
fi

# 3. Copy ALL other files (attachments, sends, keys, config, etc.)
# We exclude the live database files (db.sqlite3*) to avoid copying locked/inconsistent files.
# The consistent DB is already in staging from step 2.
echo "[$(date)] Copying all other data files..."
find "$DATA_DIR" -maxdepth 1 -mindepth 1 -not -name "db.sqlite3*" -not -name "tmp" -exec cp -r "{}" "$BACKUP_DIR/" \;

# 4. Compressing (and Encrypting if configured)
echo "[$(date)] Compressing..."
cd "$BACKUP_DIR"

if [ -n "$ZIP_PASSWORD" ]; then
    echo "Encrypting backup with password..."
    zip -P "$ZIP_PASSWORD" -r "/tmp/$BACKUP_FILE" .
else
    echo "Creating unencrypted backup (No ZIP_PASSWORD set)..."
    zip -r "/tmp/$BACKUP_FILE" .
fi

cd /app

# 5. Upload to all 4 Drive remotes
REMOTES=("gdrive1" "gdrive2" "gdrive3" "gdrive4")

for REMOTE in "${REMOTES[@]}"; do
    echo "[$(date)] Uploading to $REMOTE..."
    # Upload to a 'vaultwarden_backups' folder in the drive
    if rclone copy "/tmp/$BACKUP_FILE" "$REMOTE:vaultwarden_backups"; then
        echo "Success: Uploaded to $REMOTE"
        
        # Cleanup old files on remote (optional, e.g., delete older than 30 days)
        echo "Cleaning up old backups on $REMOTE..."
        rclone delete "$REMOTE:vaultwarden_backups" --min-age ${RETENTION_DAYS}d --include "vaultwarden_backup_*.zip"
    else
        echo "Error: Failed to upload to $REMOTE"
    fi
done

# 6. Cleanup Local
rm -rf "$BACKUP_DIR"
rm -f "/tmp/$BACKUP_FILE"

echo "[$(date)] Backup process completed."
