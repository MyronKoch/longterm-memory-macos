#!/bin/bash

# Memory Sync Daemon - Coordinates continuous database sync operations
# Databases sync hourly (scheduled) plus instantly via WAL monitoring

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/tmp"
DB_LOG="$LOG_DIR/database_sync.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🧠 Claude Memory Sync Daemon${NC}"
echo "============================="
echo -e "${BLUE}Manages database synchronization and monitoring${NC}"
echo ""

# Function to sync database
sync_database() {
    echo "[$(date)] Starting database sync..." >> "$DB_LOG"
    "$SCRIPT_DIR/sync_databases.sh" >> "$DB_LOG" 2>&1
    echo "[$(date)] Database sync complete" >> "$DB_LOG"
    echo "---" >> "$DB_LOG"
}

# Initial database sync
echo -e "${YELLOW}📊 Running initial database sync...${NC}"
sync_database

# Start database watcher for instant sync
echo -e "${YELLOW}⚡ Starting instant database sync...${NC}"
"$SCRIPT_DIR/database_watcher.sh" &
DB_SYNC_PID=$!
echo "  Database watcher PID: $DB_SYNC_PID"

echo ""
echo -e "${GREEN}✅ Memory Sync Daemon Running!${NC}"
echo ""
echo "📊 Database syncs instantly on changes (checks every 5 seconds)"
echo ""
echo "Logs:"
echo "  Database: tail -f $DB_LOG"
echo ""
echo "To stop: pkill -f memory_sync_daemon.sh"

# Keep daemon running
wait $DB_SYNC_PID
