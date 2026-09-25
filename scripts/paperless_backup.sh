#!/bin/bash
# ----------------------------------------------------------------------
# Backup script for Paperless-ngx & PostgreSQL on Konstantin (Unraid)
# Stores consistent database dumps locally and syncs everything encrypted to Hetzner
# ----------------------------------------------------------------------

# --- CONFIGURATION ---

#Log file config:
LOG_PATH="/mnt/user/logs/backups"
LOGFILE="$LOG_PATH/paperless_backup.log"

#Function for logging:
log() {
    local LEVEL="$1"   
    local MESSAGE="$2"
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "$TIMESTAMP [$LEVEL] $MESSAGE" | tee -a "$LOGFILE"
}

# Local directory on Unraid Array (bypassing Cache for instant parity protection)
LOCAL_BACKUP_DIR="/mnt/user/backups/paperless"

# Number of days to retain local SQL dumps
KEEP_LOCAL_DAYS=7

# Name of the PostgreSQL Docker container
DB_CONTAINER_NAME="postgresql17"

# Database credentials (must match credentials defined in gitops-secrets.env)
DB_USER="paperless"
DB_NAME="paperless"

# Path to the active local Paperless media directory (originals & archive)
PAPERLESS_MEDIA_DIR="/mnt/user/paperless/media"
# ---------------------

# Ensure the local backup directory exists
mkdir -p "$LOCAL_BACKUP_DIR"

# Ensure the logfile directory exists
mkdir -p "$LOG_PATH"

log "INFO" "=== [1/3] Starting PostgreSQL database dump ==="
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$LOCAL_BACKUP_DIR/db_dump_$TIMESTAMP.sql"

# Run pg_dump inside the active container and redirect output to the local array
docker exec -t "$DB_CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$DUMP_FILE"

if [ $? -eq 0 ]; then
    log "INFO" "Database dump successfully created: $DUMP_FILE"
else
    log "ERROR" "Database dump failed!"
    exit 1
fi

# Clean up local SQL dumps older than configured retention period
find "$LOCAL_BACKUP_DIR" -name "db_dump_*.sql" -mtime +$KEEP_LOCAL_DAYS -delete
log "INFO" "Old local dumps (older than $KEEP_LOCAL_DAYS days) cleaned up."

log "INFO" "=== [2/3] Syncing media files to Hetzner Storage Box (Encrypted) ==="
# Synchronize PDF documents, thumbnails, and original files
rclone sync "$PAPERLESS_MEDIA_DIR" secure-backup:media --fast-list >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    log "INFO" "Media files synced successfully."
else
    log "ERROR" "Failed to sync media files!"
    exit 1
fi

log "INFO" "=== [3/3] Syncing database dumps to Hetzner Storage Box (Encrypted) ==="
# Synchronize SQL dumps to the designated directory on the Hetzner Storage Box
rclone sync "$LOCAL_BACKUP_DIR" secure-backup:database_dumps --fast-list >> "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    log "INFO" "Database dumps synced successfully."
else
    log "ERROR" "Failed to sync database dumps!"
    exit 1
fi

log "INFO" "=== Backup completed successfully! ==="