# MCP Config Sprawl: A Cautionary Tale

*How I ended up with the same MCP server defined in 5 different places, pointing to 3 different databases, using 2 different packages, with 2 different names.*

## The Discovery

I asked Claude Code a simple question: "What is the claude-memory MCP server?"

The answer should have been straightforward. Instead, it kicked off a forensic investigation that revealed a mess of configuration files scattered across my system like digital shrapnel.

## The Problem: Where Does MCP Config Actually Live?

Here's what I discovered on my Mac:

### For Claude Code (CLI)
- **`~/.mcp.json`** - The global config. This is the one that matters.
- **`~/.claude/settings.local.json`** - Enables/disables servers defined elsewhere
- **Project-level `.mcp.json`** - Per-project overrides (only loads when running from that directory)

### For Claude Desktop (App)
- **`~/Library/Application Support/Claude/claude_desktop_config.json`** - The only one that matters.

### What I Actually Had
- `~/.mcp.json` - Global Claude Code config
- `~/Library/Application Support/Claude/claude_desktop_config.json` - Claude Desktop config
- `~/Library/Application Support/Claude/.configsForJSONs/*.json` - 14 backup/experimental configs (none actually used)
- `~/Library/Application Support/Claude/.configsForJSONs/archive/*.json` - More backups
- Project-level `.mcp.json` files in various repos
- `~/.claude/settings.local.json` - Enabling servers by name

## The Real Problem: Drift

My configs had drifted apart:

| Location | Server Name | Package | Database |
|----------|-------------|---------|----------|
| `~/.mcp.json` | `claude-memory` | `@henkey/postgres-mcp-server` | `claude_memory` |
| Claude Desktop | `longterm-memory` | `postgres-mcp` | `longterm_memory` |
| Repo config | `longterm-memory` | `postgres-mcp` | `longterm_memory` |

Same conceptual purpose. Three different implementations. Two different names. No wonder things were confusing.

## How This Happens

1. **Iterative experimentation** - You try one package, then switch to another, forget to update everywhere
2. **Copy-paste inheritance** - New configs get copied from old ones, accumulating cruft
3. **Tool evolution** - Claude Code and Claude Desktop evolved separately, each with their own config locations
4. **No single source of truth** - Nothing tells you "hey, you have conflicting configs"
5. **Backups that aren't backups** - Saving `config.backup.json` next to `config.json` in case you break something

## The Two-File Reality

After all this, here's what you actually need:

**For Claude Code:**
```
~/.mcp.json
```

**For Claude Desktop:**
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

That's it. Two files. Everything else is noise.

## The Enablement Layer (Claude Code Only)

Claude Code has an additional concept: `~/.claude/settings.local.json` contains an `enabledMcpjsonServers` array that acts as a whitelist. Servers defined in `~/.mcp.json` won't load unless they're also listed here.

```json
{
  "enabledMcpjsonServers": [
    "desktop-commander",
    "longterm-memory",
    "filesystem"
  ]
}
```

This is actually useful - you can define many servers but only enable the ones you need. But it's another place where names have to match exactly.

## Project-Level Overrides

Both Claude Code and Claude Desktop support project-level `.mcp.json` files. These are useful for:
- Project-specific servers (like a local dev database)
- Sharing configs with team members via git
- Temporarily overriding global settings

But they add another layer of "which config is actually being used?"

## Lessons Learned

### 1. Audit Your Configs Regularly
Run this to find all MCP configs on your system:
```bash
find ~ -name "*mcp*.json" -o -name "claude_desktop_config.json" 2>/dev/null | grep -v node_modules
```

### 2. Use Consistent Naming
Pick a name and stick with it everywhere. Don't let `claude-memory` and `longterm-memory` coexist referring to the same thing.

### 3. Delete What You Don't Use
Those backup configs in `.configsForJSONs/archive/`? Delete them. If you need version history, use git.

### 4. Document Your Canonical Configs
Keep a note somewhere: "My MCP config lives at X. Don't edit Y."

### 5. Check the Connection String
When debugging MCP issues, verify:
- The server name matches everywhere
- The package/command is what you expect
- The connection string points to the right database
- Credentials are current

## The Fix

For my setup, I:
1. Updated `~/.mcp.json` to use `longterm-memory` (matching Claude Desktop)
2. Updated `~/.claude/settings.local.json` to enable `longterm-memory` instead of `claude-memory`
3. Made a mental note to clean up the 14 unused config files in `.configsForJSONs/`

## What MCP Tooling Could Do Better

1. **Config validation** - Warn when the same server name is defined differently in multiple places
2. **Config discovery** - A command like `mcp config list` showing all loaded configs and their sources
3. **Single source of truth** - One config format that both Claude Code and Claude Desktop read
4. **Deprecation warnings** - "Hey, you have configs in old locations that aren't being used"

## Conclusion

MCP is powerful, but its configuration story is a maze. Until tooling improves, the best defense is discipline: know where your configs live, keep them in sync, and ruthlessly delete anything that isn't actively used.

The next time something isn't working, before you debug the server itself, ask: "Which config is actually being loaded right now?"

---

*Written after spending 30 minutes tracking down why `claude-memory` and `longterm-memory` both existed and neither worked quite right.*
