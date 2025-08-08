#!/bin/bash

# Database Change Watcher - Triggers sync when database changes
# Uses fswatch to monitor PostgreSQL WAL files for actual changes

DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="$SCRIPT_DIR/sync_databases.sh"
LOG_FILE="/tmp/database_watcher.log"
LAST_SYNC_FILE="/tmp/last_db_sync_time"

# PostgreSQL data directory - detect dynamically
PG_DATA=$(psql -U $DB_USER -d $DB_NAME -t -c "SHOW data_directory" 2>/dev/null | xargs)
WAL_DIR="$PG_DATA/pg_wal"

echo "🔍 Starting database watcher..." | tee -a "$LOG_FILE"
echo "📊 Monitoring: $DB_NAME" | tee -a "$LOG_FILE"
echo "👀 Watching WAL files at: $WAL_DIR" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Function to sync database
sync_database() {
    echo "[$(date)] Database change detected, syncing..." | tee -a "$LOG_FILE"
    bash "$SYNC_SCRIPT" >> "$LOG_FILE" 2>&1
    echo "[$(date)] Sync complete" | tee -a "$LOG_FILE"
    echo "---" | tee -a "$LOG_FILE"
    date +%s > "$LAST_SYNC_FILE"
}

# Check if WAL directory exists
if [ ! -d "$WAL_DIR" ]; then
    echo "⚠️  WAL directory not found, falling back to hash-based monitoring" | tee -a "$LOG_FILE"
    
    # Fallback: Monitor database content hash changes
    while true; do
        # Get database content hash
        CURRENT_HASH=$(psql -U $DB_USER -d $DB_NAME -t -c "
            SELECT md5(string_agg(
                COALESCE(e.id::text, '') || 
                COALESCE(e.entity_name, '') || 
                COALESCE(o.id::text, '') || 
                COALESCE(o.observation_text, '') || 
                COALESCE(o.created_at::text, ''), 
                ''
            ))
            FROM entities e
            LEFT JOIN observations o ON e.id = o.entity_id
        " 2>/dev/null | xargs)
        
        LAST_HASH=$(cat /tmp/db_content_hash 2>/dev/null || echo "")
        
        if [ "$CURRENT_HASH" != "$LAST_HASH" ] && [ -n "$CURRENT_HASH" ]; then
            sync_database
            echo "$CURRENT_HASH" > /tmp/db_content_hash
        fi
        
        # Check every 60 seconds as fallback
        sleep 60
    done
fi

# Initial sync
sync_database

# Watch WAL files for changes using fswatch
echo "✅ Using fswatch for efficient monitoring" | tee -a "$LOG_FILE"

fswatch -0 --event Updated --event Created "$WAL_DIR" | while read -d "" event; do
    # Debounce rapid changes
    sleep 2
    
    # Check time since last sync to avoid rapid syncs
    LAST_SYNC=$(cat "$LAST_SYNC_FILE" 2>/dev/null || echo "0")
    CURRENT_TIME=$(date +%s)
    TIME_DIFF=$((CURRENT_TIME - LAST_SYNC))
    
    # Only sync if at least 10 seconds passed since last sync
    if [ $TIME_DIFF -gt 10 ]; then
        sync_database
    fi
done
