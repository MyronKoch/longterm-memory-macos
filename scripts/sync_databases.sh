#!/bin/bash

# Database Sync Script - Bidirectional sync between M1 and M3
# Uses iCloud as transport layer, handles conflicts by timestamp

set -e

# Add PostgreSQL to PATH
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# Configuration
DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
SYNC_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory/db_sync"
LOCAL_EXPORT="/tmp/longterm_memory_local_export.sql"
REMOTE_EXPORT="$SYNC_DIR/longterm_memory_export.sql"
SYNC_METADATA="$SYNC_DIR/sync_metadata.json"
HOSTNAME=$(hostname -s)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to copy file to iCloud using Finder (bypasses TCC restrictions)
copy_to_icloud() {
    local source_file="$1"
    local dest_dir="$2"
    osascript -e "
        tell application \"Finder\"
            set sourceFile to POSIX file \"$source_file\"
            set destFolder to POSIX file \"$dest_dir\"
            duplicate sourceFile to folder destFolder with replacing
        end tell
    " > /dev/null 2>&1
}

echo -e "${GREEN}🔄 Database Sync System${NC}"
echo "========================"

# Create sync directory if needed
mkdir -p "$SYNC_DIR"

# Function to get database last modified time
get_db_last_modified() {
    psql -U $DB_USER -d $DB_NAME -t -c "
        SELECT COALESCE(
            MAX(created_at),
            '1970-01-01'::timestamp
        )
        FROM (
            SELECT created_at FROM entities
            UNION ALL
            SELECT created_at FROM observations
        ) combined;
    " | xargs
}

# Function to export database
export_database() {
    echo -e "${YELLOW}📤 Exporting local database...${NC}"
    pg_dump -U $DB_USER -d $DB_NAME \
        --no-owner --no-privileges --clean --if-exists \
        > "$LOCAL_EXPORT"
    
    # Get metadata
    LAST_MODIFIED=$(get_db_last_modified)
    ENTITY_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM entities" | xargs)
    OBS_COUNT=$(psql -U $DB_USER -d $DB_NAME -t -c "SELECT COUNT(*) FROM observations" | xargs)
    
    # Create metadata file
    cat > "$SYNC_METADATA.tmp" << EOF
{
    "hostname": "$HOSTNAME",
    "last_modified": "$LAST_MODIFIED",
    "export_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "entity_count": $ENTITY_COUNT,
    "observation_count": $OBS_COUNT
}
EOF
    
    echo "  Entities: $ENTITY_COUNT, Observations: $OBS_COUNT"
    echo "  Last modified: $LAST_MODIFIED"
}

# Function to import database
import_database() {
    echo -e "${YELLOW}📥 Importing remote database...${NC}"
    
    # Backup current database first
    echo "  Creating backup..."
    pg_dump -U $DB_USER -d $DB_NAME > "/tmp/longterm_memory_backup_$(date +%Y%m%d_%H%M%S).sql"
    
    # Import the remote database
    psql -U $DB_USER -d $DB_NAME < "$REMOTE_EXPORT"
    
    echo -e "${GREEN}✅ Import complete!${NC}"
}

# Main sync logic
echo -e "${YELLOW}🔍 Checking sync status...${NC}"

# Export current database
export_database

# Check if remote exists
if [ -f "$SYNC_METADATA" ]; then
    # Read remote metadata
    REMOTE_HOSTNAME=$(jq -r '.hostname' "$SYNC_METADATA" 2>/dev/null || echo "unknown")
    REMOTE_MODIFIED=$(jq -r '.last_modified' "$SYNC_METADATA" 2>/dev/null || echo "1970-01-01")
    REMOTE_ENTITIES=$(jq -r '.entity_count' "$SYNC_METADATA" 2>/dev/null || echo "0")
    REMOTE_OBS=$(jq -r '.observation_count' "$SYNC_METADATA" 2>/dev/null || echo "0")
    
    echo "Remote: $REMOTE_HOSTNAME - $REMOTE_ENTITIES entities, $REMOTE_OBS observations (modified: $REMOTE_MODIFIED)"
    echo "Local: $HOSTNAME - $ENTITY_COUNT entities, $OBS_COUNT observations (modified: $LAST_MODIFIED)"
    
    # Compare timestamps
    if [[ "$REMOTE_MODIFIED" > "$LAST_MODIFIED" ]]; then
        echo -e "${YELLOW}⬇️  Remote database is newer. Importing...${NC}"
        
        # Download remote export
        brctl download "$REMOTE_EXPORT" 2>/dev/null || true
        
        # Import it
        import_database
        
    elif [[ "$LAST_MODIFIED" > "$REMOTE_MODIFIED" ]]; then
        echo -e "${YELLOW}⬆️  Local database is newer. Uploading...${NC}"
        
        # Upload local export using Finder (bypasses TCC)
        copy_to_icloud "$LOCAL_EXPORT" "$SYNC_DIR"
        mv "$SYNC_DIR/longterm_memory_local_export.sql" "$REMOTE_EXPORT" 2>/dev/null || true
        copy_to_icloud "$SYNC_METADATA.tmp" "$SYNC_DIR"
        mv "$SYNC_DIR/sync_metadata.json.tmp" "$SYNC_METADATA" 2>/dev/null || true

    else
        echo -e "${GREEN}✅ Databases are in sync!${NC}"
    fi
else
    echo -e "${YELLOW}🆕 First sync - uploading local database...${NC}"

    # Upload local export using Finder (bypasses TCC)
    copy_to_icloud "$LOCAL_EXPORT" "$SYNC_DIR"
    mv "$SYNC_DIR/longterm_memory_local_export.sql" "$REMOTE_EXPORT" 2>/dev/null || true
    copy_to_icloud "$SYNC_METADATA.tmp" "$SYNC_DIR"
    mv "$SYNC_DIR/sync_metadata.json.tmp" "$SYNC_METADATA" 2>/dev/null || true
fi

# Cleanup
rm -f "$LOCAL_EXPORT" "$SYNC_METADATA.tmp"

echo -e "${GREEN}✅ Sync complete!${NC}"
