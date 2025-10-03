# AGENT.md - Automated Installation Instructions

**For AI Coding Agents (Cursor, Windsurf, Claude Code, Aider, etc.)**

Drop this file into your agent's context and say: "Install the longterm-memory system following AGENT.md"

---

## Overview

You are installing a local semantic memory system for LLM applications on macOS. The system uses PostgreSQL with pgvector for vector storage, Ollama for local embeddings, and includes a Flask dashboard.

**Target Setup:**
- PostgreSQL 17 + pgvector 0.8.0
- Ollama with nomic-embed-text model
- Flask dashboard at localhost:5555
- Chrome browser extension
- Background services via LaunchAgents
- (Optional) Cross-Mac sync via iCloud

## Pre-Flight Checks

Before starting, verify these commands work:

```bash
# Check macOS
uname -s  # Should output: Darwin

# Check Homebrew
brew --version

# Check if PostgreSQL is already installed
brew list postgresql@17 2>/dev/null && echo "PostgreSQL 17 installed" || echo "Need to install PostgreSQL"

# Check if Ollama is installed
which ollama && echo "Ollama installed" || echo "Need to install Ollama"
```

## Installation Steps

Execute these in order. **Verify each step succeeds before proceeding.**

### Step 1: Clone Repository

```bash
mkdir -p ~/Documents/GitHub
cd ~/Documents/GitHub
git clone https://github.com/MyronKoch/longterm-memory-macos.git
cd longterm-memory-macos
```

**Verify:** `ls -la` shows README.md, install.sh, dashboard/, scripts/, etc.

### Step 2: Install PostgreSQL 17 + pgvector

```bash
brew install postgresql@17
brew install pgvector

# Start PostgreSQL
brew services start postgresql@17

# Wait for it to start
sleep 3

# Verify it's running
brew services info postgresql@17
```

**Verify:** Output shows `Running: true`

### Step 3: Create Database and Enable pgvector

```bash
# Create the database
createdb longterm_memory

# Enable pgvector extension
psql -d longterm_memory -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Verify
psql -d longterm_memory -c "SELECT extname FROM pg_extension WHERE extname = 'vector';"
```

**Verify:** Query returns `vector` in the output

### Step 4: Run Schema Setup

```bash
cd ~/Documents/GitHub/longterm-memory-macos

# Run schema files in order
psql -d longterm_memory -f sql/01_create_database.sql 2>/dev/null || true
psql -d longterm_memory -f sql/02_create_tables.sql
psql -d longterm_memory -f sql/03_create_views.sql
psql -d longterm_memory -f sql/04_extended_tables.sql
```

**Verify:** 
```bash
psql -d longterm_memory -c "\dt"
```
Should show tables: entities, observations, observations_archive, insights, etc.

### Step 5: Install Ollama and Embedding Model

```bash
# Install Ollama if not present
which ollama || brew install ollama

# Start Ollama service
ollama serve &
sleep 5

# Pull the embedding model
ollama pull nomic-embed-text

# Verify
ollama list | grep nomic-embed-text
```

**Verify:** `nomic-embed-text` appears in the list

### Step 6: Set Up Python Environment

```bash
cd ~/Documents/GitHub/longterm-memory-macos

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install flask psycopg2-binary requests numpy

# Install dashboard requirements
pip install -r dashboard/requirements.txt
```

**Verify:** `pip list | grep -E "flask|psycopg2"` shows both packages

### Step 7: Test Dashboard

```bash
cd ~/Documents/GitHub/longterm-memory-macos/dashboard
python3 app.py &
sleep 3

# Test API
curl -s http://localhost:5555/api/health | head -20
```

**Verify:** Returns JSON with database connection status

Kill the test server: `pkill -f "python3 app.py"`

### Step 8: Set Up LaunchAgents (Background Services)

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

# Load the agents
launchctl load ~/Library/LaunchAgents/com.longtermmemory.embeddings.plist
launchctl load ~/Library/LaunchAgents/com.longtermmemory.backup.plist
launchctl load ~/Library/LaunchAgents/com.longtermmemory.dbsync.plist
```

**Verify:** 
```bash
launchctl list | grep longterm
```
Should show 3 services with exit code 0 or -

### Step 9: Install Sleepwatcher (Optional - for wake sync)

```bash
brew install sleepwatcher
brew services start sleepwatcher

# Create wake script
cat > ~/.wakeup << 'EOF'
#!/bin/bash
LOG="$HOME/Documents/GitHub/longterm-memory-macos/logs/wake_sync.log"
SCRIPT="$HOME/Documents/GitHub/longterm-memory-macos/scripts/sync_databases.sh"
echo "[$(date)] Mac woke from sleep - starting database sync" >> "$LOG"
sleep 5
"$SCRIPT" >> "$LOG" 2>&1
echo "[$(date)] Wake sync complete" >> "$LOG"
EOF

# Create sleep script
cat > ~/.sleep << 'EOF'
#!/bin/bash
LOG="$HOME/Documents/GitHub/longterm-memory-macos/logs/wake_sync.log"
echo "[$(date)] Mac going to sleep" >> "$LOG"
EOF

chmod +x ~/.wakeup ~/.sleep
```

**Verify:** `brew services info sleepwatcher` shows `Running: true`

### Step 10: Configure MCP Client (Claude Desktop)

Create or update Claude Desktop config:

```bash
CONFIG_DIR="$HOME/Library/Application Support/Claude"
mkdir -p "$CONFIG_DIR"

# Check if config exists
if [ -f "$CONFIG_DIR/claude_desktop_config.json" ]; then
  echo "Config exists - add longterm-memory server manually"
  cat "$CONFIG_DIR/claude_desktop_config.json"
else
  # Create new config
  cat > "$CONFIG_DIR/claude_desktop_config.json" << EOF
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://$(whoami)@localhost:5432/longterm_memory"
      }
    }
  }
}
EOF
  echo "Created new config"
fi
```

**Verify:** Restart Claude Desktop, check MCP server connects

## Post-Installation Verification

Run this comprehensive check:

```bash
echo "=== Longterm Memory System Health Check ==="

echo -n "PostgreSQL: "
brew services info postgresql@17 | grep -q "Running: true" && echo "✅ Running" || echo "❌ Not running"

echo -n "Database: "
psql -d longterm_memory -c "SELECT 1" &>/dev/null && echo "✅ Connected" || echo "❌ Cannot connect"

echo -n "pgvector: "
psql -d longterm_memory -c "SELECT extname FROM pg_extension WHERE extname='vector'" 2>/dev/null | grep -q vector && echo "✅ Enabled" || echo "❌ Not enabled"

echo -n "Tables: "
TABLE_COUNT=$(psql -d longterm_memory -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null | tr -d ' ')
echo "✅ $TABLE_COUNT tables"

echo -n "Ollama: "
pgrep -x ollama &>/dev/null && echo "✅ Running" || echo "⚠️ Not running (start with: ollama serve)"

echo -n "Embedding model: "
ollama list 2>/dev/null | grep -q nomic-embed-text && echo "✅ nomic-embed-text installed" || echo "❌ Model not found"

echo -n "LaunchAgents: "
AGENT_COUNT=$(launchctl list | grep -c longterm)
echo "✅ $AGENT_COUNT services loaded"

echo -n "Dashboard: "
curl -s http://localhost:5555/api/health &>/dev/null && echo "✅ Running at :5555" || echo "⚠️ Not running"

echo "=== Check Complete ==="
```

## Troubleshooting

### PostgreSQL won't start
```bash
brew services restart postgresql@17
tail -100 /opt/homebrew/var/log/postgresql@17.log
```

### psycopg2 installation fails
```bash
pip install psycopg2-binary --break-system-packages
```

### Ollama model download fails
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Manual pull
OLLAMA_HOST=http://localhost:11434 ollama pull nomic-embed-text
```

### LaunchAgent errors
```bash
# Check logs
cat /tmp/longterm_memory_backup.log
cat ~/Documents/GitHub/longterm-memory-macos/logs/*.log

# Reload agent
launchctl unload ~/Library/LaunchAgents/com.longtermmemory.dbsync.plist
launchctl load ~/Library/LaunchAgents/com.longtermmemory.dbsync.plist
```

## Success Criteria

Installation is complete when:
- [ ] PostgreSQL 17 running with pgvector enabled
- [ ] Database `longterm_memory` exists with all tables
- [ ] Ollama running with `nomic-embed-text` model
- [ ] Dashboard accessible at http://localhost:5555
- [ ] 3 LaunchAgents loaded (embeddings, backup, dbsync)
- [ ] MCP client can connect to the database

**Total installation time: ~10-15 minutes**
