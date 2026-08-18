!/bin/bash
# ----------------------------------------------------------------------
# Backup script for Paperless-ngx & PostgreSQL on Konstantin (Unraid)
# Stores consistent database dumps locally and syncs everything encrypted to Hetzner
# ----------------------------------------------------------------------

# --- CONFIGURATION ---
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

echo "=== [1/3] Starting PostgreSQL database dump ==="
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DUMP_FILE="$LOCAL_BACKUP_DIR/db_dump_$TIMESTAMP.sql"

# Run pg_dump inside the active container and redirect output to the local array
docker exec -t "$DB_CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$DUMP_FILE"

if [ $? -eq 0 ]; then
    echo "✔ Database dump successfully created: $DUMP_FILE"
else
    echo "❌ ERROR: Database dump failed!" >&2
    exit 1
fi

# Clean up local SQL dumps older than configured retention period
find "$LOCAL_BACKUP_DIR" -name "db_dump_*.sql" -mtime +$KEEP_LOCAL_DAYS -delete
echo "✔ Old local dumps (older than $KEEP_LOCAL_DAYS days) cleaned up."

echo "=== [2/3] Syncing media files to Hetzner Storage Box (Encrypted) ==="
# Synchronize PDF documents, thumbnails, and original files
rclone sync "$PAPERLESS_MEDIA_DIR" secure-backup:media --fast-list --verbose

echo "=== [3/3] Syncing database dumps to Hetzner Storage Box (Encrypted) ==="
# Synchronize SQL dumps to the designated directory on the Hetzner Storage Box
rclone sync "$LOCAL_BACKUP_DIR" secure-backup:database_dumps --fast-list --verbose

echo "=== Backup completed successfully! ==="