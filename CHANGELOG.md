# Changelog

All notable changes to the Longterm Memory System will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-11-25

### Added - Web Dashboard
- **Full-featured Flask dashboard** at `http://localhost:5555`
- **Browse view** with observation cards showing type, importance, tags, dates
- **Semantic search** - AI-powered similarity search using Ollama embeddings
- **Text search** - Full-text search across observations and metadata URLs
- **Timeline view** - Visual bar chart of memory activity over time
- **Insights panel** - Automated pattern discovery (tag correlations, activity patterns, entity connections)
- **Command palette** (Cmd+K) - Keyboard-first navigation and quick actions
- **Light/Dark/System theme** support with persistent preference
- **Full pagination** with first/last/prev/next and clickable page numbers
- **Filter system** - By type, importance, entity, tag, and archive inclusion
- **Detail panel** - Click any observation to see full content and metadata

### Added - Knowledge Graph
- **3D interactive graph** at `http://localhost:5555/graph` using Three.js + 3D Force Graph
- **Local graph view** - Click any node to see N-hop neighborhood (adjustable 1-4 hops)
- **Path finding** - Select two nodes to discover shortest connection path
- **Search in graph** - Fuzzy search to find and focus on specific nodes
- **Time animation** - Watch your knowledge graph grow over time with playback controls
- **Graph clustering** - Partial implementation with color-coded communities
- **Auto-fit camera** - Graph automatically fits to screen on load

### Added - Browser Extension v2.0
- **Enhanced context menu** with clear branding:
  - 🧠 Longterm Memory Database (parent menu)
  - Save Selection (quick save)
  - Save Selection + Context (includes surrounding paragraph)
  - Save Entire Page
  - Open Dashboard
- **Memory badge** - Floating badge shows count of memories from current domain
- **Memory panel** - Click badge to see all your memories from that site
- **Auto-suggestions** - After 10 visits to a page, suggests saving to memory
- **Settings toggles** in popup:
  - Show memory badge on pages (on/off)
  - Auto-suggest frequent pages (on/off)
- **In-page toast notifications** instead of Chrome notifications
- **Smart category detection** from URL patterns

### Added - API Endpoints
- `/api/stats` - Dashboard statistics
- `/api/observations` - Paginated observations with filtering
- `/api/observations/semantic` - Semantic similarity search
- `/api/entities` - Entity listing
- `/api/tags` - Tag listing with counts
- `/api/timeline` - Aggregated timeline data
- `/api/insights` - Pattern analysis results
- `/api/graph` - Knowledge graph nodes and links
- `/api/graph/local/<id>` - Local neighborhood graph
- `/api/graph/path` - Shortest path between nodes
- `/api/graph/timeline` - Time-based graph data
- `/api/memories/domain/<domain>` - Memories by domain
- `/api/quick-note` - Quick note capture

### Changed
- **Metadata schema** - Standardized with url, domain, title, category, tags, importance, captured_at
- **Search** now checks both observation_text AND metadata URL field
- **Dashboard URL parameter** - Opens with pre-filled search from extension links

### Removed
- Quick Capture floating widget (redundant with extension popup and context menu)
- Highlight-to-save tooltip (replaced with enhanced context menu)

### Fixed
- Timeline date labels no longer overlap bars
- Dark mode text legibility across all dashboard elements
- Toggle switches render correctly with green=on indicator
- Memory badge doesn't show on the dashboard itself

---

## [1.1.0] - 2025-11-09

### Added
- **Unified VIEW System**: `all_observations` view combines active and archived observations
- Hot/cold storage architecture for optimal performance
- Extended tables: `projects`, `sessions`, `insights`, `project_milestones`, `project_updates`
- SQL file `04_extended_tables.sql` for optional advanced tables
- Comprehensive database schema documentation

### Changed
- **MCP Configuration**: Updated to use `postgres-mcp` with `--access-mode unrestricted`
- Added `SYSTEM_CONTEXT` environment variable for MCP server guidance
- Updated README with manual database setup instructions

### Improved
- Hot/cold storage pattern: active observations for fast queries, archive for history
- VIEW-based architecture allows querying both storage tiers seamlessly
- Better documentation of archive strategy and data organization

---

## [1.0.0] - 2025-11-08

### Added
- Initial release of Longterm Memory System
- PostgreSQL 17 + pgvector 0.8.0 integration
- Semantic search with Ollama + nomic-embed-text (768 dimensions)
- Automatic text chunking for observations >800 characters
- Daily automated backups (7-day retention)
- Daily automated embedding generation
- MCP server integration for Claude Desktop
- Health check script for system verification
- Complete one-command installer
- Cross-platform database schema
- LaunchAgent automation for macOS
- Comprehensive documentation

### Features
- **Entities**: Store and organize unique entities (people, projects, concepts)
- **Observations**: Track detailed observations with automatic indexing
- **Semantic Search**: Vector similarity search with cosine distance
- **Auto-chunking**: Intelligently splits long text at topic boundaries
- **Archiving**: Automatic archiving of chunked/old observations
- **Backup System**: Automated daily backups in custom and SQL formats
- **Embedding Pipeline**: Automatic embedding generation for new observations
- **Background Services**: LaunchAgent-based automation for hands-free operation

---

## [2.2.1] - 2025-12-12

### Fixed
- **macOS Tahoe TCC bypass**: iCloud sync now uses Finder via osascript instead of direct `cp`
  - Resolves "Operation not permitted" errors when launchd runs sync_databases.sh
  - On first run, macOS will prompt for Finder automation permission - click Allow
  - Tested working on both M1 and M3 Macs via launchd

### Notes
- If you still encounter TCC issues, you can optionally move the script to `~/.local/bin/` (outside Documents)
- The plist files remain configured for the default Documents location

---

## [Unreleased]

### Planned
- Edge labels for knowledge graph
- Docker container support
- Linux/Windows compatibility
- Mobile-responsive dashboard
- Export/import functionality
