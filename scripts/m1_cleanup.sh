#!/bin/bash
# M1 Cleanup and Update Script
# Matches M3 configuration with longterm-memory-macos

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🧹 M1 Longterm Memory Cleanup & Update${NC}"
echo "=============================================="
echo ""

# 1. Check current status
echo -e "${YELLOW}📊 Current Status:${NC}"
echo "GitHub Repos:"
ls -1 ~/Documents/GitHub/ 2>/dev/null | grep -i memory | sed 's/^/  - /'
echo ""
echo "LaunchAgents:"
ls -1 ~/Library/LaunchAgents/ 2>/dev/null | grep -E "longterm|claude|memory" | sed 's/^/  - /'
echo ""

# 2. Archive old repos
echo -e "${YELLOW}📦 Archiving legacy repos...${NC}"
cd ~/Documents/GitHub
mkdir -p _archived_repos

# Archive if they exist
for repo in claude-memory-system longterm-memory longterm-vector-memory; do
    if [ -d "$repo" ]; then
        echo "  Archiving: $repo"
        mv "$repo" _archived_repos/
    fi
done

echo -e "${GREEN}  ✅ Legacy repos archived to ~/Documents/GitHub/_archived_repos/${NC}"
echo ""

# 3. Update LaunchAgents
echo -e "${YELLOW}🔧 Updating LaunchAgents...${NC}"

# Unload and remove old agents
for plist in com.claudememory.dailybackup com.claude.embeddings com.myron.claude-memory-backup com.longtermmemory.backup.old; do
    if [ -f ~/Library/LaunchAgents/${plist}.plist ]; then
        echo "  Removing: ${plist}"
        launchctl unload ~/Library/LaunchAgents/${plist}.plist 2>/dev/null || true
        rm -f ~/Library/LaunchAgents/${plist}.plist
    fi
done

# Create/update backup LaunchAgent
cat > ~/Library/LaunchAgents/com.longtermmemory.backup.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.longtermmemory.backup</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/Documents/GitHub/longterm-memory-macos/scripts/backup_longterm_memory.sh</string>
    </array>
    
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    
    <key>StandardOutPath</key>
    <string>/tmp/longterm_memory_backup.log</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/longterm_memory_backup_error.log</string>
    
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

# Create/update embeddings LaunchAgent
cat > ~/Library/LaunchAgents/com.longtermmemory.embeddings.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.longtermmemory.embeddings</string>

    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/python3</string>
        <string>$HOME/Documents/GitHub/longterm-memory-macos/scripts/ollama_embeddings.py</string>
        <string>embed</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/longterm-memory-embeddings.log</string>

    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/longterm-memory-embeddings.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>LONGTERM_MEMORY_DB</key>
        <string>longterm_memory</string>
        <key>LONGTERM_MEMORY_USER</key>
        <string>$USER</string>
    </dict>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
EOF

# Load new agents
launchctl load ~/Library/LaunchAgents/com.longtermmemory.backup.plist
launchctl load ~/Library/LaunchAgents/com.longtermmemory.embeddings.plist

echo -e "${GREEN}  ✅ LaunchAgents updated and loaded${NC}"
echo ""

# 4. Run sync to get new schema
echo -e "${YELLOW}🔄 Running database sync to get new schema...${NC}"
cd ~/Documents/GitHub/longterm-memory-macos
bash scripts/sync_databases.sh

echo ""
echo -e "${GREEN}✅ M1 Cleanup Complete!${NC}"
echo ""
echo "Summary:"
echo "  - Legacy repos archived"
echo "  - LaunchAgents updated to point to longterm-memory-macos"
echo "  - Database synced with new metadata columns"
echo ""
echo "Active Services:"
launchctl list | grep longterm | awk '{print "  - " $3}'
echo ""
echo "Next: Verify database has new columns:"
echo "  /opt/homebrew/Cellar/postgresql@14/*/bin/psql -d longterm_memory -c \"\\d observations\""
