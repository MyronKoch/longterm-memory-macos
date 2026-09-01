# Scripts Directory

This directory contains all the operational scripts for the Longterm Memory System.

## Core Scripts

### Database Operations
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

### AI/Embeddings
- **`ollama_embeddings.py`** - Generate and query embeddings
  - Uses Ollama + nomic-embed-text (768 dimensions)
  - Semantic similarity search
  - Automatic embedding generation for new observations

## Usage Examples

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
- Python 3 with psycopg2, numpy, requests

## Troubleshooting

**Embeddings failing?**
- Ensure Ollama is running: `ollama list`
- Pull model if missing: `ollama pull nomic-embed-text`

**Database connection issues?**
- Verify PostgreSQL is running: `brew services list`
- Check credentials in scripts
- Test connection: `psql -U $USER -d claude_memory -c "SELECT 1"`
