# Longterm Memory Dashboard v2.0

A full-featured local web dashboard for browsing, searching, and visualizing your semantic memory system.

## 🖥️ Overview

**Main Dashboard**: `http://localhost:5555`
**Knowledge Graph**: `http://localhost:5555/graph`

## ✨ Features

### Dashboard (`/`)
- 📊 **Statistics Overview**: Observations, entities, embeddings, coverage percentage
- 🔍 **Dual Search Modes**:
  - **Text Search**: Full-text search across observations and URLs
  - **Semantic Search**: AI-powered similarity search using Ollama embeddings
- 📅 **Timeline View**: Visual bar chart of activity over time (day/week/month)
- 💡 **Insights Panel**: Automated pattern discovery:
  - Tag correlations (what topics appear together)
  - Activity patterns (by day of week)
  - Entity connections (strongest relationships)
- ⌨️ **Command Palette** (Cmd+K): Keyboard-first navigation
- 🏷️ **Filtering**: By type, importance, entity, tag, archive status
- 📋 **Detail Panel**: Full observation content with metadata
- 🌙 **Themes**: Light, Dark, and System auto-detect
- 📄 **Full Pagination**: First/last/prev/next with clickable page numbers

### Knowledge Graph (`/graph`)
- 🕸️ **3D Interactive**: Three.js-powered force-directed graph
- 🔎 **Local View**: Click any node to see N-hop neighborhood (1-4 adjustable)
- 🛤️ **Path Finding**: Discover shortest path between two nodes
- 🔍 **Search**: Fuzzy search to find and focus nodes
- ⏱️ **Time Animation**: Watch your knowledge grow with playback controls
- 📊 **Statistics Panel**: Node/link counts, density metrics
- 🎨 **Visual Customization**: Minimum observations filter, color coding

## 🚀 Quick Start

```bash
cd dashboard
pip3 install flask flask-cors psycopg2-binary
python3 app.py
```

Then open: **http://localhost:5555**

## 📋 Requirements

- Python 3.8+
- Flask, flask-cors
- psycopg2-binary
- PostgreSQL with `longterm_memory` database
- Ollama with nomic-embed-text (for semantic search)

## 🔌 API Endpoints

### Core
| Endpoint | Description |
|----------|-------------|
| `GET /` | Main dashboard |
| `GET /graph` | Knowledge graph visualization |
| `GET /api/stats` | Dashboard statistics |
| `GET /api/observations` | Paginated observations with filtering |
| `GET /api/entities` | Entity listing |
| `GET /api/tags` | Tags with counts |

### Search
| Endpoint | Description |
|----------|-------------|
| `GET /api/observations?search=<query>` | Text search (observations + URLs) |
| `POST /api/observations/semantic` | Semantic similarity search |

### Timeline & Insights
| Endpoint | Description |
|----------|-------------|
| `GET /api/timeline?granularity=<day|week|month>` | Timeline data |
| `GET /api/insights` | Pattern analysis |

### Knowledge Graph
| Endpoint | Description |
|----------|-------------|
| `GET /api/graph?min_obs=<n>` | Full graph data |
| `GET /api/graph/local/<id>?hops=<n>` | Local neighborhood |
| `GET /api/graph/path?from=<id>&to=<id>` | Shortest path |
| `GET /api/graph/timeline` | Time-based graph |

### Browser Extension Support
| Endpoint | Description |
|----------|-------------|
| `GET /api/memories/domain/<domain>` | Memories by domain |
| `POST /api/quick-note` | Quick note capture |

## ⚙️ Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LONGTERM_MEMORY_DB` | `longterm_memory` | Database name |
| `LONGTERM_MEMORY_USER` | Current user | Database user |
| `LONGTERM_MEMORY_HOST` | `localhost` | Database host |
| `LONGTERM_MEMORY_PORT` | `5432` | Database port |

## 🎹 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+K` | Open command palette |
| `/` | Focus search (in graph) |
| `Escape` | Close panels/modals |

## 📁 File Structure

```
dashboard/
├── app.py              # Flask application
├── requirements.txt    # Python dependencies
├── static/
│   ├── index.html      # Main dashboard (Vue.js)
│   └── graph.html      # Knowledge graph (Three.js)
└── templates/          # (unused, Vue handles rendering)
```

## 🔧 Configuration

The dashboard auto-detects your database configuration. For custom setups:

```bash
export LONGTERM_MEMORY_DB=my_memory_db
export LONGTERM_MEMORY_USER=myuser
python3 app.py
```

## 🐛 Troubleshooting

### Dashboard won't start
```bash
# Check dependencies
pip3 install flask flask-cors psycopg2-binary

# Check PostgreSQL is running
psql -d longterm_memory -c "SELECT 1"
```

### Semantic search not working
```bash
# Verify Ollama is running
ollama list

# Check embeddings exist
psql -d longterm_memory -c "SELECT COUNT(*) FROM observations WHERE embedding IS NOT NULL"
```

### Graph is empty
- Check you have observations with embeddings
- Try lowering the "Min Observations" filter
- Verify entities exist in the database

## 📄 License

MIT - Part of the Longterm Memory System
