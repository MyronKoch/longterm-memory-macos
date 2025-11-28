# Quick Start Guide

## 🚀 Installation (5 minutes)

### One-Command Install

```bash
curl -fsSL https://raw.githubusercontent.com/MyronKoch/longterm-memory-macos/main/install.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/MyronKoch/longterm-memory-macos.git
cd longterm-memory-macos
chmod +x install.sh
./install.sh
```

The installer will:
1. ✅ Install PostgreSQL 17 + pgvector
2. ✅ Install Ollama + nomic-embed-text model
3. ✅ Create database and tables
4. ✅ Setup background automation
5. ✅ Run health check

## ⚙️ Post-Installation Setup

### 1. Configure Claude Desktop (2 minutes)

Open Claude Desktop → Settings → Developer → Edit config:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": [
        "postgres-mcp",
        "--access-mode", "unrestricted",
        "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory"
      ]
    }
  }
}
```

Replace `YOUR_USERNAME` with your macOS username.

Restart Claude Desktop.

### 2. Verify Installation

```bash
cd longterm-memory
./scripts/health_check.sh
```

Should show all ✅ green checks.

## 📝 Basic Usage

### Add Your First Entity and Observation

In Claude Desktop:

```sql
-- Create an entity
INSERT INTO entities (name, entity_type) 
VALUES ('My First Project', 'project') 
RETURNING id;

-- Add an observation
INSERT INTO observations (entity_id, observation_text, observation_index)
VALUES (1, 'Started working on semantic memory system', 1);
```

### Generate Embeddings

```bash
cd scripts
python3 ollama_embeddings.py embed
```

### Search Semantically

```bash
cd scripts
python3 ollama_embeddings.py search "memory system"
```

## 🎯 Common Workflows

### Daily Use (Automated)

The system runs automatically:
- **3:00 AM**: Daily backup
- **4:00 AM**: Generate embeddings for new observations

You don't need to do anything! 🎉

### Manual Operations

```bash
# Run health check
./scripts/health_check.sh

# Manual backup
./scripts/backup_longterm_memory.sh

# Force embedding generation
cd scripts && python3 ollama_embeddings.py embed

# Search
cd scripts && python3 ollama_embeddings.py search "your query"
```

### View Data in Claude

```sql
-- See all entities
SELECT * FROM entities ORDER BY created_at DESC;

-- Recent observations
SELECT e.name, o.observation_text, o.created_at
FROM observations o
JOIN entities e ON o.entity_id = e.id
ORDER BY o.created_at DESC
LIMIT 20;

-- Check embedding coverage
SELECT 
  COUNT(*) as total,
  COUNT(embedding) as embedded,
  ROUND(100.0 * COUNT(embedding) / COUNT(*), 1) as coverage_pct
FROM observations;
```

## 📊 Monitoring

### Check Logs

```bash
# Backup logs
tail -f ~/Library/Logs/longterm-memory-backup.log

# Embedding logs
tail -f ~/Library/Logs/longterm-memory-embeddings.log
```

### Database Stats

```sql
-- Entity count
SELECT COUNT(*) FROM entities;

-- Observation count
SELECT COUNT(*) FROM observations;

-- Embedding coverage
SELECT 
  COUNT(*) FILTER (WHERE embedding IS NOT NULL) as embedded,
  COUNT(*) FILTER (WHERE embedding IS NULL) as pending
FROM observations;
```

## 🐛 Troubleshooting

### "Cannot connect to database"

```bash
# Start PostgreSQL
brew services start postgresql@17

# Test connection
psql -U $(whoami) -d longterm_memory -c "SELECT 1;"
```

### "Ollama not responding"

```bash
# Start Ollama
brew services start ollama

# Test Ollama
curl http://localhost:11434/api/tags

# Pull model if needed
ollama pull nomic-embed-text
```

### "Embeddings not generating"

```bash
# Check if service is loaded
launchctl list | grep longtermmemory

# Load service
launchctl load ~/Library/LaunchAgents/com.longtermmemory.embeddings.plist

# Manual run
cd scripts && python3 ollama_embeddings.py embed
```

## 🎓 Next Steps

1. **Read Full Docs**: Check `docs/ARCHITECTURE.md` for deep dive
2. **Customize**: Edit `config/env.example` for your setup
3. **Backup Strategy**: Configure off-site backup storage
4. **Integration**: Build apps using the PostgreSQL API

## 💡 Tips

- **Observations**: Keep them focused (one concept per observation)
- **Entities**: Create entities for recurring themes
- **Search**: Use natural language queries for best results
- **Chunking**: Long observations (>800 chars) auto-split for better search

## 🆘 Getting Help

- **Issues**: https://github.com/MyronKoch/longterm-memory-macos/issues
- **Docs**: `docs/ARCHITECTURE.md`
- **Health Check**: Run `./scripts/health_check.sh`

---

**Happy memory building!** 🧠✨
