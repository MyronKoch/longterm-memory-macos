#!/bin/bash

# Longterm Memory Database Backup Script
# Backs up PostgreSQL database with 7-day retention

set -e  # Exit on any error

# Configuration
DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
DB_HOST="${LONGTERM_MEMORY_HOST:-localhost}"
DB_PORT="${LONGTERM_MEMORY_PORT:-5432}"
BACKUP_DIR="${LONGTERM_MEMORY_BACKUP_DIR:-$HOME/Documents/longterm-memory-backups}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="longterm_memory_backup_${DATE}"

# Find pg_dump (try common locations)
if command -v pg_dump &> /dev/null; then
    PG_DUMP=$(command -v pg_dump)
elif [ -f "/opt/homebrew/bin/pg_dump" ]; then
    PG_DUMP="/opt/homebrew/bin/pg_dump"
elif [ -f "/usr/local/bin/pg_dump" ]; then
    PG_DUMP="/usr/local/bin/pg_dump"
else
    echo "❌ Error: pg_dump not found. Please install PostgreSQL."
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

echo "🔄 Starting Longterm Memory backup at $(date)"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo "   Backup dir: $BACKUP_DIR"

# Create the backup (custom format for fast restore)
"$PG_DUMP" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -F custom \
    -f "$BACKUP_DIR/${BACKUP_FILE}.backup" 2>/dev/null

# Also create SQL dump for portability
"$PG_DUMP" \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -f "$BACKUP_DIR/${BACKUP_FILE}.sql" 2>/dev/null

# Compress SQL dump
gzip -9 "$BACKUP_DIR/${BACKUP_FILE}.sql"

# Get file sizes
CUSTOM_SIZE=$(du -h "$BACKUP_DIR/${BACKUP_FILE}.backup" | cut -f1)
SQL_SIZE=$(du -h "$BACKUP_DIR/${BACKUP_FILE}.sql.gz" | cut -f1)

echo "✅ Backup completed successfully!"
echo "   📦 Custom format: ${BACKUP_FILE}.backup ($CUSTOM_SIZE)"
echo "   📄 SQL format: ${BACKUP_FILE}.sql.gz ($SQL_SIZE)"

# Cleanup old backups (keep last 7 days)
echo "🧹 Cleaning up old backups..."
OLD_COUNT=$(find "$BACKUP_DIR" -name "longterm_memory_backup_*.backup" -mtime +7 | wc -l | tr -d ' ')
find "$BACKUP_DIR" -name "longterm_memory_backup_*.backup" -mtime +7 -delete
find "$BACKUP_DIR" -name "longterm_memory_backup_*.sql.gz" -mtime +7 -delete

if [ "$OLD_COUNT" -gt 0 ]; then
    echo "   Deleted $OLD_COUNT old backup(s)"
fi

echo "✨ Backup process complete!"
