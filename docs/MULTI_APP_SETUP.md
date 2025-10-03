# Multi-App Setup Guide

This guide covers setting up the Longterm Memory system with different MCP-compatible applications.

## Overview

Each app needs two things:
1. **MCP Server Config** — Connection to the PostgreSQL database
2. **System Prompt** — Instructions for how the AI should use the memory

| App | MCP Config Location | System Prompt Location |
|-----|---------------------|------------------------|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | Settings → Custom System Prompt |
| Claude Code | `~/.claude/settings.json` (global) or `.claude/settings.json` (project) | `CLAUDE.md` in project root |
| Cursor | `.cursor/mcp.json` in project root | `.cursorrules` in project root |

---

## Claude Desktop

### MCP Config

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": [
        "postgres-mcp",
        "--access-mode", "unrestricted",
        "postgresql://USERNAME:PASSWORD@localhost:5432/longterm_memory"
      ]
    }
  }
}
```

### System Prompt

1. Open Claude Desktop
2. Go to **Settings** (gear icon)
3. Find **Custom System Prompt**
4. Paste contents of `SYSTEM_PROMPT.md`
5. Restart Claude Desktop

---

## Claude Code

### MCP Config (Global)

Create or edit `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx",
      "args": [
        "postgres-mcp",
        "--access-mode", "unrestricted",
        "postgresql://USERNAME:PASSWORD@localhost:5432/longterm_memory"
      ]
    }
  }
}
```

### MCP Config (Per-Project)

Create `.claude/settings.json` in your project root with the same content.

### System Prompt

Create `CLAUDE.md` in your project root:

```markdown
# Project Instructions

[Paste contents of SYSTEM_PROMPT.md here]
```

Claude Code automatically reads `CLAUDE.md` at conversation start.

---

## Cursor

### MCP Config

Create `.cursor/mcp.json` in your project root:

```json
{
  "mcpServers": {
    "longterm-memory": {
      "command": "uvx", 
      "args": [
        "postgres-mcp",
        "--access-mode", "unrestricted",
        "postgresql://USERNAME:PASSWORD@localhost:5432/longterm_memory"
      ]
    }
  }
}
```

### System Prompt

Create `.cursorrules` in your project root:

```markdown
[Paste contents of SYSTEM_PROMPT.md here]
```

Cursor automatically reads `.cursorrules` for every conversation in that project.

---

## Database Credentials

### Option 1: Same User (Simple)

Use the same PostgreSQL credentials across all apps. All observations will have the same `source_type`.

### Option 2: Separate Users (Auditable)

Create separate PostgreSQL users to track which app wrote what:

```sql
-- Create users
CREATE USER claude_desktop WITH PASSWORD 'your_password';
CREATE USER claude_code WITH PASSWORD 'your_password';
CREATE USER cursor_ai WITH PASSWORD 'your_password';

-- Grant permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO claude_desktop, claude_code, cursor_ai;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO claude_desktop, claude_code, cursor_ai;
```

Then use different credentials in each app's config.

---

## Global vs Per-Project

### Global Setup
- Memory available in every conversation
- Good for personal context that spans all projects
- Configure in user-level config files

### Per-Project Setup  
- Memory only available in specific project directories
- Good for project-specific context
- Configure in project-level config files (`.claude/`, `.cursor/`)
- Can combine with global setup

### Recommended Approach

Use **global** for the memory system itself (you want context everywhere), but keep the system prompt **per-project** so you can customize behavior for different workflows.

---

## Verifying Setup

### Test MCP Connection

In any app, ask:
```
Can you query the longterm-memory database? Try: SELECT COUNT(*) FROM observations;
```

### Test System Prompt

Start a new conversation. The AI should say "Checking context..." and query for recent activity.

---

## Troubleshooting

### "MCP server not found"
- Check file paths and JSON syntax
- Ensure `uvx` is installed: `pip install uvx`
- Restart the application

### "Connection refused"
- Verify PostgreSQL is running: `pg_isready`
- Check credentials and database name
- Ensure user has permissions

### "No context retrieved"
- Verify entity exists: `SELECT * FROM entities WHERE name = '[YOUR_NAME]';`
- Check for recent observations: `SELECT * FROM observations ORDER BY created_at DESC LIMIT 5;`

### System prompt not working
- Claude Desktop: Restart after changing settings
- Claude Code: Ensure `CLAUDE.md` is in project root
- Cursor: Ensure `.cursorrules` is in project root

---

## Dashboard Access

Regardless of which app you use, the dashboard is always available at:

```
http://localhost:5555
```

Start it with:
```bash
cd /path/to/longterm-memory-macos/dashboard
python3 app.py
```
