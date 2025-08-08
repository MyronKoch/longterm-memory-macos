#!/bin/bash

# Claude Memory System - Handoff Sync Script
# Syncs handoff files between local and iCloud

SYNC_METHOD=${SYNC_METHOD:-"icloud"}
LOCAL_HANDOFFS="$HOME/Documents/GitHub/longterm-memory-macos/handoffs"
ICLOUD_HANDOFFS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory/handoffs"

echo "🔄 Syncing handoffs via $SYNC_METHOD..."

case $SYNC_METHOD in
    "icloud")
        # Ensure directories exist
        mkdir -p "$LOCAL_HANDOFFS"
        mkdir -p "$ICLOUD_HANDOFFS"
        
        # Force download any cloud-only files
        find "$ICLOUD_HANDOFFS" -type f -exec brctl download {} \; 2>/dev/null || true
        
        # Sync from iCloud to local
        rsync -av --update "$ICLOUD_HANDOFFS/" "$LOCAL_HANDOFFS/"
        
        # Sync from local to iCloud
        rsync -av --update "$LOCAL_HANDOFFS/" "$ICLOUD_HANDOFFS/"
        
        echo "✅ iCloud sync complete"
        ;;
    *)
        echo "❌ Unknown sync method: $SYNC_METHOD"
        exit 1
        ;;
esac

# PATCH: Force download iCloud files
if [ "$SYNC_METHOD" = "icloud" ]; then
    # Force download any cloud-only files before syncing
    find "$ICLOUD_HANDOFFS" -type f -exec brctl download {} \; 2>/dev/null || true
fi
