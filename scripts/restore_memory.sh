#!/bin/bash

# Longterm Memory Database Restore Script
# Restore backup for persistent memory system
#
# Authentication: Uses PostgreSQL .pgpass file or prompts for password
# Setup: echo "localhost:5432:*:USERNAME:PASSWORD" >> ~/.pgpass && chmod 600 ~/.pgpass

set -e

# Configuration (Override via environment variables)
DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
DB_HOST="${LONGTERM_MEMORY_HOST:-localhost}"
DB_PORT="${LONGTERM_MEMORY_PORT:-5432}"
BACKUP_DIR="${LONGTERM_MEMORY_BACKUP_DIR:-$HOME/longterm_memory_backups}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [backup_file]"
    echo ""
    echo "Available backups:"
    ls -la "$BACKUP_DIR"/*.backup 2>/dev/null || echo "No backup files found"
    echo ""
    echo "Example: $0 claude_memory_backup_20250723_140000.sql.backup"
}

# Check if backup file provided
if [ $# -eq 0 ]; then
    echo "❌ No backup file specified"
    show_usage
    exit 1
fi

BACKUP_FILE="$1"

# Check if file exists (try different locations)
if [ -f "$BACKUP_FILE" ]; then
    FULL_PATH="$BACKUP_FILE"
elif [ -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    FULL_PATH="$BACKUP_DIR/$BACKUP_FILE"
else
    echo "❌ Backup file not found: $BACKUP_FILE"
    show_usage
    exit 1
fi

echo "🔄 Starting Claude Memory restore from: $FULL_PATH"
echo "⚠️  WARNING: This will OVERWRITE the existing claude_memory database!"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

echo "Creating backup of current database before restore..."
CURRENT_DATE=$(date +%Y%m%d_%H%M%S)
pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --format=custom \
    --file="$BACKUP_DIR/pre_restore_backup_${CURRENT_DATE}.backup"

echo "Dropping existing database..."
dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" || true

echo "Creating new database..."
createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"

echo "Restoring from backup..."
if [[ "$FULL_PATH" == *.backup ]]; then
    # Custom format restore
    pg_restore \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        --verbose \
        --no-password \
        "$FULL_PATH"
else
    # SQL format restore
    if [[ "$FULL_PATH" == *.gz ]]; then
        gunzip -c "$FULL_PATH" | psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME"
    else
        psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$FULL_PATH"
    fi
fi

echo "✅ Longterm Memory restore completed successfully!"
echo "📊 Verifying restore..."

# Quick verification
ENTITY_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM entities;")
OBS_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc "SELECT COUNT(*) FROM observations;")

echo "📈 Database restored with:"
echo "   - Entities: $ENTITY_COUNT"
echo "   - Observations: $OBS_COUNT"
echo "$(date): Restore completed from $FULL_PATH" >> "$BACKUP_DIR/restore.log"
