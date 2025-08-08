# Multi-Mac Setup Instructions

This document describes how to set up the background services on a **secondary Mac** after configuring them on your primary machine.

## Prerequisites

Both Macs should have:
- PostgreSQL 17 with pgvector
- The longterm-memory-macos repo cloned to `~/Documents/GitHub/longterm-memory-macos`
- Ollama with nomic-embed-text
- iCloud Drive enabled (for sync)

## 1. Install Sleepwatcher

```bash
brew install sleepwatcher
brew services start sleepwatcher
```

## 2. Create Wake/Sleep Scripts

Create `~/.wakeup`:
```bash
#!/bin/bash
LOG="$HOME/Documents/GitHub/longterm-memory-macos/logs/wake_sync.log"
SCRIPT="$HOME/Documents/GitHub/longterm-memory-macos/scripts/sync_databases.sh"

echo "[$(date)] Mac woke from sleep - starting database sync" >> "$LOG"
sleep 5
"$SCRIPT" >> "$LOG" 2>&1
echo "[$(date)] Wake sync complete" >> "$LOG"
echo "---" >> "$LOG"
```

Create `~/.sleep`:
```bash
#!/bin/bash
LOG="$HOME/Documents/GitHub/longterm-memory-macos/logs/wake_sync.log"
echo "[$(date)] Mac going to sleep" >> "$LOG"
```

Make executable:
```bash
chmod +x ~/.wakeup ~/.sleep
```

## 3. Generate LaunchAgents from Templates

The repo includes plist templates with `{{HOME}}` and `{{USER}}` placeholders. Generate your personalized plists:

```bash
# Create logs directory
mkdir -p ~/Documents/GitHub/longterm-memory-macos/logs

# Generate plists from templates
TEMPLATE_DIR=~/Documents/GitHub/longterm-memory-macos/config/launchagents
for template in "$TEMPLATE_DIR"/*.template; do
  plist="${template%.template}"
  plist_name=$(basename "$plist")
  sed -e "s|{{HOME}}|$HOME|g" -e "s|{{USER}}|$(whoami)|g" "$template" > ~/Library/LaunchAgents/"$plist_name"
done

echo "Generated plists in ~/Library/LaunchAgents/"
ls ~/Library/LaunchAgents/com.longtermmemory.*.plist
```

## 4. Load the LaunchAgents

```bash
launchctl load ~/Library/LaunchAgents/com.longtermmemory.embeddings.plist
launchctl load ~/Library/LaunchAgents/com.longtermmemory.backup.plist
launchctl load ~/Library/LaunchAgents/com.longtermmemory.dbsync.plist
```

## 5. Verify

```bash
# Check LaunchAgents are loaded
launchctl list | grep longterm

# Check sleepwatcher
brew services info sleepwatcher

# Test wake script manually
~/.wakeup
cat ~/Documents/GitHub/longterm-memory-macos/logs/wake_sync.log
```

## Schedule Summary

| Job | Schedule |
|-----|----------|
| Embeddings | 4:00 AM, 4:00 PM |
| Backup | Monday 4:20 PM |
| Database Sync | 8 AM, 12 PM, 6 PM, 11 PM |
| Wake Sync | On wake from sleep |

## Troubleshooting

### LaunchAgent won't load
```bash
# Check for errors
launchctl list | grep longterm
# Exit code 126 = permission issue, check script paths exist
# Exit code 0 = success (even if shown with -)
```

### Sync not working
```bash
# Check iCloud sync directory exists
ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/ClaudeMemory/db_sync/

# Run sync manually
~/Documents/GitHub/longterm-memory-macos/scripts/sync_databases.sh
```

### Path issues
Make sure your repo is at `~/Documents/GitHub/longterm-memory-macos`. If it's elsewhere, edit the generated plists in `~/Library/LaunchAgents/` to match your actual path.
