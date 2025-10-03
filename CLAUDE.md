# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Longterm Memory System** - Enterprise-grade semantic memory system for LLM applications on macOS. This is a local-first, privacy-focused system that provides bidirectional database sync between Macs via iCloud, semantic search with local embeddings, and MCP integration for Claude Desktop.

**Key Technologies**: PostgreSQL 17, pgvector 0.8.0, Ollama (nomic-embed-text), Model Context Protocol (MCP)

## Development Commands

### Setup & Installation
```bash
# Complete system installation
./install.sh

# Manual database setup (if needed)
psql -U postgres -f sql/01_create_database.sql
psql -U $USER -d longterm_memory -f sql/02_create_tables.sql
psql -U $USER -d longterm_memory -f sql/03_create_views.sql
```

### Testing & Health
```bash
# Run health check to verify all components
./scripts/health_check.sh

# Test database connection
psql -U $USER -d longterm_memory -c "SELECT 1;"

# Check service status
brew services list | grep -E "(postgresql|ollama)"
launchctl list | grep longtermmemory
```

### Database Operations
```bash
# Manual backup
./scripts/backup_longterm_memory.sh

# Restore from backup
./scripts/restore_memory.sh <backup_file>

# Manual sync between machines
./scripts/sync_databases.sh
```

### Embeddings
```bash
# Generate embeddings for all observations without embeddings
cd scripts && python3 ollama_embeddings.py embed

# Generate embeddings with limit (e.g., 100 observations)
cd scripts && python3 ollama_embeddings.py embed 100

# Semantic search
cd scripts && python3 ollama_embeddings.py search "your query here"

# View embedding status
cd scripts && python3 ollama_embeddings.py
```

### Logs
```bash
# View system logs
tail -f /tmp/longterm_memory_*.log

# View LaunchAgent logs
tail -f ~/Library/Logs/longterm-memory-backup.log
tail -f ~/Library/Logs/longterm-memory-embeddings.log

# PostgreSQL logs
tail -f /opt/homebrew/var/log/postgresql@17.log
```

## Architecture

### 6 Core Components

1. **Database Sync Engine** (`scripts/sync_databases.sh`)
   - Bidirectional PostgreSQL synchronization between Macs
   - Uses iCloud Drive as transport: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory/db_sync/`
   - Conflict resolution via timestamp comparison
   - Auto-detects hostname and handles metadata

2. **Real-time Change Detection** (`scripts/database_watcher.sh`)
   - Monitors PostgreSQL WAL files via fswatch
   - Triggers sync on database changes
   - Logs to `/tmp/database_watcher.log`

3. **Handoff File Monitoring** (`scripts/handoff_watcher.sh`)
   - Watches for file changes with batching
   - Part of the sync orchestration system

4. **Master Orchestration Daemon** (`scripts/memory_sync_daemon.sh`)
   - Coordinates all sync operations
   - Runs database sync hourly
   - Manages change-based handoff sync

5. **LaunchAgent Automation** (`config/launchagents/`)
   - `com.longtermmemory.backup.plist` - Daily backups at 3:00 AM
   - `com.longtermmemory.embeddings.plist` - Daily embedding generation at 4:00 AM

6. **Supporting Infrastructure**
   - Backups: `backup_longterm_memory.sh`, `restore_memory.sh`
   - Health checks: `health_check.sh`
   - Embeddings: `ollama_embeddings.py`

### Database Schema

**Three-table design with hot/cold storage pattern:**

- **entities** - Unique entities (people, projects, concepts, companies)
  - Fields: id, name (unique), entity_type, created_at, source_type, observation_count, metadata (JSONB)

- **observations** - Active observations with semantic embeddings
  - Fields: id, entity_id (FK), observation_text, observation_index, created_at, source_type, embedding vector(768)
  - Primary table for semantic search
  - Indexed with IVFFLAT for fast cosine similarity

- **observations_archive** - Historical/chunked observations
  - Same structure as observations plus archived_at timestamp
  - Deep freeze storage for long observations that were chunked

- **all_observations** (VIEW) - Unified view combining active + archive
  - Adds storage_location field ('active' or 'archive')
  - Use this for queries across all observations

### Auto-Chunking System

Observations longer than 800 characters are automatically chunked by `ollama_embeddings.py`:
- Splits by numbered topics like (1), (2), etc. when possible
- Falls back to sentence boundaries
- Each chunk gets embedded separately
- Original observation archived
- Chunks labeled as "(Part N/M)" for context

### MCP Integration

The system exposes PostgreSQL to Claude Desktop via the Model Context Protocol:
- Uses `postgres-mcp` server via `uvx`
- Connection string: `postgresql://$USER@localhost:5432/longterm_memory`
- Configuration location: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Enables direct SQL queries from Claude Desktop

### Environment Variables

Scripts accept these environment variables (with defaults):
- `LONGTERM_MEMORY_DB` - Database name (default: longterm_memory)
- `LONGTERM_MEMORY_USER` - Database user (default: current user)
- `LONGTERM_MEMORY_HOST` - Database host (default: localhost)
- `LONGTERM_MEMORY_PORT` - Database port (default: 5432)
- `LONGTERM_MEMORY_PASSWORD` - Database password (default: empty, uses .pgpass)

## Key Technical Details

### PostgreSQL Configuration
- Version: 17 (installed via Homebrew)
- Extensions: pgvector (0.8.0), uuid-ossp
- Path: `/opt/homebrew/opt/postgresql@17/bin` (add to PATH)
- Data location: `/opt/homebrew/var/postgresql@17`

### Embeddings
- Model: nomic-embed-text (768 dimensions)
- Provider: Ollama (local)
- API endpoint: `http://localhost:11434/api/embeddings`
- Batch size: 10 observations per commit
- Max chunk size: 800 characters with 50-char overlap

### Sync Mechanism
- Transport: iCloud Drive (requires "Files & Folders" access)
- Format: PostgreSQL pg_dump SQL with --clean --if-exists
- Metadata: JSON file with hostname, timestamps, counts
- Strategy: Last-write-wins based on max(created_at) across tables

### Background Services
- Managed via macOS LaunchAgents
- Backup retention: 7 days
- Service start: Automatic on login
- Logs: `~/Library/Logs/longterm-memory-*.log`

## Common Issues & Solutions

**Database name mismatch**: Scripts default to `longterm_memory` but README mentions `claude_memory` in places. The installer creates `longterm_memory`. Set `LONGTERM_MEMORY_DB` environment variable if using different name.

**iCloud sync not working**: Grant Claude Desktop or Terminal "Files & Folders" access in System Settings > Privacy & Security. Verify path exists: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory/`

**Ollama not responding**: Check with `curl http://localhost:11434/api/tags`. Restart with `brew services restart ollama`. Verify model with `ollama list | grep nomic-embed-text`.

**LaunchAgent not running**: Load with `launchctl load ~/Library/LaunchAgents/com.longtermmemory.*.plist`. Check status with `launchctl list | grep longtermmemory`.

**PostgreSQL connection failed**: Ensure running with `brew services list | grep postgresql@17`. Start with `brew services start postgresql@17`. Check PATH includes PostgreSQL bin directory.

## File Structure

```
.
├── install.sh                    # Complete system installer
├── scripts/
│   ├── sync_databases.sh         # Bidirectional sync via iCloud
│   ├── database_watcher.sh       # WAL file monitoring
│   ├── memory_sync_daemon.sh     # Master orchestrator
│   ├── backup_longterm_memory.sh # Manual backup
│   ├── restore_memory.sh         # Restore from backup
│   ├── health_check.sh           # System health verification
│   ├── ollama_embeddings.py      # Embedding generation & search
│   ├── handoff_watcher.sh        # File monitoring
│   └── sync_handoffs.sh          # Handoff sync
├── config/
│   ├── claude_desktop_config.json # MCP configuration example
│   └── env.example               # Environment variable template
└── docs/
    ├── ARCHITECTURE.md           # Detailed technical documentation
    └── QUICKSTART.md             # Quick start guide
```

## Python Dependencies

When modifying `ollama_embeddings.py`:
- psycopg2-binary - PostgreSQL adapter
- numpy - Vector operations (implicit in some operations)
- requests - Not directly used (uses curl via subprocess)

Install: `pip3 install psycopg2-binary --break-system-packages`
