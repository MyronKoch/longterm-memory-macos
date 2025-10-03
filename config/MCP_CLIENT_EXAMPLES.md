# MCP Client Configuration Examples

This document shows how to configure the Longterm Memory System for different MCP-compatible clients.

---

## 📱 Claude Desktop (macOS)

**Config Location**: `~/Library/Application Support/Claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": [
        "postgres-mcp"
      ],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

---

## 💻 Claude Code (CLI)

**Config Location**: `~/.claude.json`

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": [
        "postgres-mcp"
      ],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

**Alternative: Project-specific config**
Create `.claude/config.json` in your project directory:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

---

## 🔧 Cline (VS Code Extension)

**Config Location**: VS Code Settings → Extensions → Cline → MCP Settings

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

**Or via VS Code settings.json**:
```json
{
  "cline.mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

---

## 🐳 Docker-based Clients

For containerized environments, mount the iCloud sync directory:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--network=host",
        "-v", "/Users/YOUR_USERNAME/Library/Mobile Documents/com~apple~CloudDocs/ClaudeMemory:/mnt/sync:ro",
        "postgres-mcp-image"
      ],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@host.docker.internal:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

**Note**: Use `host.docker.internal` to access host PostgreSQL from container.

---

## 🌐 Cursor IDE

**Config Location**: Cursor Settings → Features → Model Context Protocol

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

---

## 🤖 Continue.dev

**Config Location**: `~/.continue/config.json`

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

---


## 🌟 Google Gemini CLI

**Config Location**: `~/.gemini/settings.json`

Add to the `mcpServers` section:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      },
      "disabled": false,
      "alwaysAllow": []
    }
  }
}
```

**Verification**:
```bash
gemini mcp list
```

---
## 🛠️ Generic MCP Client

For any MCP-compatible client that supports standard configuration:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": ["postgres-mcp"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "postgresql://YOUR_USERNAME@localhost:5432/longterm_memory",
        "SYSTEM_CONTEXT": "PostgreSQL memory for user-specific data. Query at conversation start for context. Use for: project continuity, personal info, technical history. NOT for: general knowledge, current events, documentation."
      }
    }
  }
}
```

---

## 🔐 Authentication Options

### Option 1: Password in Connection String
```
postgresql://username:password@localhost:5432/longterm_memory
```

### Option 2: .pgpass File (Recommended)
Create `~/.pgpass` with:
```
localhost:5432:longterm_memory:YOUR_USERNAME:YOUR_PASSWORD
```
Then:
```bash
chmod 600 ~/.pgpass
```

Use connection string without password:
```
postgresql://YOUR_USERNAME@localhost:5432/longterm_memory
```

### Option 3: Environment Variables
```bash
export PGUSER=YOUR_USERNAME
export PGPASSWORD=YOUR_PASSWORD
export PGDATABASE=longterm_memory
```

Use simplified connection string:
```
postgresql://localhost:5432/longterm_memory
```

---

## 🔄 Multi-Machine Sync Configuration

All clients can share the same database via iCloud sync:

1. **Primary Mac**: Run PostgreSQL + sync scripts
2. **Secondary Mac**: Run PostgreSQL + sync scripts
3. **Other Clients**: Point to either Mac's database via network

**Network access example**:
```json
{
  "env": {
    "POSTGRES_CONNECTION_STRING": "postgresql://user@primary-mac.local:5432/longterm_memory"
  }
}
```

---

## 🎯 Environment Variable Overrides

All configs support these environment variables:

```bash
# Override database name
export LONGTERM_MEMORY_DB=custom_db_name

# Override user
export LONGTERM_MEMORY_USER=custom_user

# Override host (for network access)
export LONGTERM_MEMORY_HOST=remote-mac.local

# Override port
export LONGTERM_MEMORY_PORT=5433
```

Then use simplified connection string:
```json
{
  "env": {
    "POSTGRES_CONNECTION_STRING": "postgresql://${LONGTERM_MEMORY_USER}@${LONGTERM_MEMORY_HOST}:${LONGTERM_MEMORY_PORT}/${LONGTERM_MEMORY_DB}"
  }
}
```

---

## 📝 Notes

- Replace `YOUR_USERNAME` with your actual username
- For security, use `.pgpass` instead of passwords in config files
- `SYSTEM_CONTEXT` is optional but recommended for Claude Desktop
- Docker users: Ensure PostgreSQL is accessible from containers
- Network access: Configure PostgreSQL to accept remote connections

## 🔗 Related Documentation

- [Main README](../README.md) - Installation and setup
- [CLAUDE.md](../CLAUDE.md) - Development guide
- [Architecture Documentation](../docs/ARCHITECTURE.md) - System design
