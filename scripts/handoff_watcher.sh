#!/bin/bash

# Handoff File Watcher using fswatch
# Monitors handoffs folder and syncs automatically when files change

HANDOFFS_DIR="$HOME/Documents/GitHub/claude-memory-system/handoffs"
SYNC_SCRIPT="$HOME/Documents/GitHub/claude-memory-system/scripts/sync_handoffs.sh"
LOG_FILE="/tmp/handoff_watcher.log"

echo "🔍 Starting handoff watcher on: $HANDOFFS_DIR" >> "$LOG_FILE"
echo "📅 Started at: $(date)" >> "$LOG_FILE"

# Start fswatch to monitor the handoffs directory
fswatch -o "$HANDOFFS_DIR" | while read changes; do
    echo "📁 Handoff change detected at $(date)" >> "$LOG_FILE"
    echo "🔄 Running sync..." >> "$LOG_FILE"
    
    # Run the sync script
    SYNC_METHOD=icloud "$SYNC_SCRIPT" >> "$LOG_FILE" 2>&1
    
    echo "✅ Sync completed at $(date)" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"
done
