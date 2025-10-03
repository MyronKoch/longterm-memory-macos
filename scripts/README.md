# Scripts Directory

This directory contains all the operational scripts for the Longterm Memory System.

## Core Scripts

### Database Operations
- **`sync_databases.sh`** - Bidirectional PostgreSQL sync between Macs via iCloud
  - Auto-detects hostname (M1/M3)
  - Handles timestamp conflicts intelligently
  - Transport: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory/db_sync/`

- **`backup_longterm_memory.sh`** - Manual database backup
  - Creates timestamped backups
  - Stores in custom PostgreSQL format

- **`restore_memory.sh`** - Restore from backup
  - Restores PostgreSQL dumps
  - Handles database recreation if needed

- **`health_check.sh`** - System health verification
  - Checks PostgreSQL connection
  - Verifies table counts
  - Tests embedding functionality

### Real-time Sync System
- **`database_watcher.sh`** - Monitors PostgreSQL WAL files
  - Detects database changes via `fswatch`
  - Triggers `sync_databases.sh` on changes
  - Logs to `/tmp/database_watcher.log`

- **`memory_sync_daemon.sh`** - Master sync orchestrator
  - Manages both database and handoff sync
  - Runs database sync hourly
  - Handles change-based handoff sync

### AI/Embeddings
- **`ollama_embeddings.py`** - Generate and query embeddings
  - Uses Ollama + nomic-embed-text (768 dimensions)
  - Semantic similarity search
  - Automatic embedding generation for new observations

## Configuration

Database name is set to `claude_memory` in all scripts. If you used a different name during installation, update line 12 in `sync_databases.sh`:

```bash
DB_NAME="your_database_name"
```

## LaunchAgent Automation

See `config/launchagents/` for macOS automation plists:
- `com.claudememory.handoffsync.plist` - Handoff sync daemon
- `com.claudememory.handoffwatcher.plist` - Handoff file monitoring

Install with:
```bash
cp config/launchagents/*.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claudememory.*.plist
```

## Usage Examples

### Manual Sync
```bash
./scripts/sync_databases.sh
```

### Health Check
```bash
./scripts/health_check.sh
```

### Generate Embeddings
```bash
python3 scripts/ollama_embeddings.py
```

### Backup Database
```bash
./scripts/backup_longterm_memory.sh
```

## Dependencies

- PostgreSQL 17+ with pgvector
- Ollama with nomic-embed-text model
- iCloud Drive (for sync)
- fswatch (for WAL monitoring)
- Python 3 with psycopg2, numpy, requests

## Troubleshooting

**Sync not working?**
- Check iCloud Drive is enabled
- Verify path exists: `~/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory/`
- Check logs: `tail -f /tmp/*memory*.log`

**Embeddings failing?**
- Ensure Ollama is running: `ollama list`
- Pull model if missing: `ollama pull nomic-embed-text`

**Database connection issues?**
- Verify PostgreSQL is running: `brew services list`
- Check credentials in scripts
- Test connection: `psql -U $USER -d claude_memory -c "SELECT 1"`
