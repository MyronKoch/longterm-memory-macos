#!/bin/bash

# Longterm Memory System - Complete Installer
# Enterprise-grade semantic memory system for LLM applications
# Version: 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SYSTEM_NAME="Longterm Memory System"
VERSION="1.0.0"
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTGRES_VERSION="17"
PGVECTOR_VERSION="0.8.0"
OLLAMA_MODEL="nomic-embed-text"
DB_NAME="longterm_memory"
DB_USER="$(whoami)"

# Logo
echo -e "${BLUE}${BOLD}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║              🧠 LONGTERM MEMORY SYSTEM v1.0                  ║
║         Enterprise Semantic Memory for LLM Apps              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}🚀 Starting ${SYSTEM_NAME} installation...${NC}"
echo "Prerequisites: macOS 12+, Homebrew, iCloud Drive, PostgreSQL 17, pgvector, fswatch, jq, Ollama"
echo ""

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check system compatibility
check_system() {
    echo -e "${BLUE}🔍 Checking system compatibility...${NC}"
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ Error: This system is designed for macOS only${NC}"
        exit 1
    fi
    
    ARCH=$(uname -m)
    echo "   ✅ macOS detected (Architecture: $ARCH)"
    
    if ! command_exists brew; then
        echo -e "${YELLOW}⚠️  Homebrew not found. Installing...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "   ✅ Homebrew found"
    fi
    
    echo ""
}

# Install PostgreSQL
install_postgresql() {
    echo -e "${BLUE}🐘 Installing PostgreSQL ${POSTGRES_VERSION}...${NC}"
    
    if brew list postgresql@${POSTGRES_VERSION} &>/dev/null; then
        echo "   ✅ PostgreSQL ${POSTGRES_VERSION} already installed"
    else
        brew install postgresql@${POSTGRES_VERSION}
    fi
    
    if brew list pgvector &>/dev/null; then
        echo "   ✅ pgvector already installed"
    else
        brew install pgvector
    fi

    if brew list fswatch &>/dev/null; then
        echo "   ✅ fswatch already installed"
    else
        brew install fswatch
    fi

    if brew list jq &>/dev/null; then
        echo "   ✅ jq already installed"
    else
        brew install jq
    fi
    
    # Start PostgreSQL
    brew services start postgresql@${POSTGRES_VERSION}
    sleep 3
    
    # Add to PATH
    if ! grep -q "postgresql@${POSTGRES_VERSION}" ~/.zshrc 2>/dev/null; then
        echo 'export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"' >> ~/.zshrc
    fi
    export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
    
    echo "   ✅ PostgreSQL ${POSTGRES_VERSION} installed and running"
    echo ""
}

# Install Ollama
install_ollama() {
    echo -e "${BLUE}🤖 Installing Ollama...${NC}"
    
    if command_exists ollama; then
        echo "   ✅ Ollama already installed"
    else
        brew install ollama
    fi
    
    # Start Ollama
    brew services start ollama
    sleep 2
    
    # Pull nomic-embed-text model
    echo "   📦 Pulling ${OLLAMA_MODEL} model (274MB)..."
    ollama pull ${OLLAMA_MODEL}
    
    echo "   ✅ Ollama installed with ${OLLAMA_MODEL}"
    echo ""
}

# Create database
create_database() {
    echo -e "${BLUE}💾 Creating database...${NC}"
    
    # Check if database exists
    if psql -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "   ✅ Database '$DB_NAME' already exists"
    else
        createdb -U "$DB_USER" "$DB_NAME"
        echo "   ✅ Database '$DB_NAME' created"
    fi
    
    # Enable extensions
    psql -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS vector;" &>/dev/null
    psql -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" &>/dev/null
    echo "   ✅ Extensions enabled (vector, uuid-ossp)"
    
    # Create tables
    if [ -f "$INSTALL_DIR/sql/02_create_tables.sql" ]; then
        psql -U "$DB_USER" -d "$DB_NAME" -f "$INSTALL_DIR/sql/02_create_tables.sql" &>/dev/null
        echo "   ✅ Tables created (entities, observations, observations_archive)"
    fi

    # Create unified view
    if [ -f "$INSTALL_DIR/sql/03_create_views.sql" ]; then
        psql -U "$DB_USER" -d "$DB_NAME" -f "$INSTALL_DIR/sql/03_create_views.sql" &>/dev/null
        echo "   ✅ Views created (all_observations)"
    fi
    
    echo ""
}

# Setup LaunchAgents
setup_launchagents() {
    echo -e "${BLUE}⏰ Setting up background services...${NC}"
    
    LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENTS_DIR"
    
    # Backup LaunchAgent
    cat > "$LAUNCH_AGENTS_DIR/com.longtermmemory.backup.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.longtermmemory.backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$INSTALL_DIR/scripts/backup_longterm_memory.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/longterm-memory-backup.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/longterm-memory-backup.error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>LONGTERM_MEMORY_DB</key>
        <string>$DB_NAME</string>
        <key>LONGTERM_MEMORY_USER</key>
        <string>$DB_USER</string>
    </dict>
</dict>
</plist>
EOF
    
    # Embeddings LaunchAgent
    cat > "$LAUNCH_AGENTS_DIR/com.longtermmemory.embeddings.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.longtermmemory.embeddings</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/python3</string>
        <string>$INSTALL_DIR/scripts/ollama_embeddings.py</string>
        <string>embed</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/longterm-memory-embeddings.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/longterm-memory-embeddings.error.log</string>
    <key>WorkingDirectory</key>
    <string>$INSTALL_DIR/scripts</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>LONGTERM_MEMORY_DB</key>
        <string>$DB_NAME</string>
        <key>LONGTERM_MEMORY_USER</key>
        <string>$DB_USER</string>
    </dict>
</dict>
</plist>
EOF
    
    # Load LaunchAgents
    launchctl load "$LAUNCH_AGENTS_DIR/com.longtermmemory.backup.plist" 2>/dev/null || true
    launchctl load "$LAUNCH_AGENTS_DIR/com.longtermmemory.embeddings.plist" 2>/dev/null || true
    
    echo "   ✅ Backup agent installed (runs daily at 3:00 AM)"
    echo "   ✅ Embeddings agent installed (runs daily at 4:00 AM)"
    echo ""
}

# Setup MCP config
setup_mcp() {
    echo -e "${BLUE}🔌 MCP Server Configuration...${NC}"
    
    CLAUDE_CONFIG="$HOME/.claude.json"
    
    echo ""
    echo -e "${YELLOW}📝 To enable MCP integration with Claude Desktop:${NC}"
    echo ""
    echo "1. Open Claude Desktop"
    echo "2. Go to Settings > Developer"
    echo "3. Edit 'claude_desktop_config.json' and add:"
    echo ""
    echo -e "${BLUE}{"
    echo "  \"mcpServers\": {"
    echo "    \"longterm-memory\": {"
    echo "      \"command\": \"uvx\"," 
    echo "      \"args\": [\"postgres-mcp\"],"
    echo "      \"env\": {"
    echo "        \"POSTGRES_CONNECTION_STRING\": \"postgresql://$DB_USER@localhost:5432/$DB_NAME\""
    echo "      }"
    echo "    }"
    echo "  }"
    echo -e "}${NC}"
    echo ""
    echo "4. Restart Claude Desktop"
    echo ""
}

# Install Python dependencies
install_python_deps() {
    echo -e "${BLUE}🐍 Installing Python dependencies...${NC}"
    
    if ! command_exists python3; then
        echo -e "${RED}❌ Python 3 not found. Please install Python 3.${NC}"
        exit 1
    fi
    
    # Install psycopg2
    pip3 install psycopg2-binary --break-system-packages --quiet 2>/dev/null || true
    
    echo "   ✅ Python dependencies installed"
    echo ""
}

# Run health check
run_health_check() {
    echo -e "${BLUE}🏥 Running health check...${NC}"
    echo ""
    
    if [ -f "$INSTALL_DIR/scripts/health_check.sh" ]; then
        export LONGTERM_MEMORY_DB="$DB_NAME"
        export LONGTERM_MEMORY_USER="$DB_USER"
        bash "$INSTALL_DIR/scripts/health_check.sh"
    fi
}

# Main installation
main() {
    echo -e "${BLUE}📋 Installation includes:${NC}"
    echo "   • PostgreSQL 17 + pgvector 0.8.0"
    echo "   • Ollama + nomic-embed-text model"
    echo "   • Database with semantic search"
    echo "   • Background automation (backups + embeddings)"
    echo "   • MCP server integration for Claude"
    echo ""
    
    read -p "Continue with installation? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Installation cancelled${NC}"
        exit 0
    fi
    
    echo ""
    
    # Run installation steps
    check_system
    install_postgresql
    install_ollama
    install_python_deps
    create_database
    setup_launchagents
    setup_mcp
    run_health_check
    
    # Final message
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║           ✨ INSTALLATION COMPLETE! ✨                       ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🎉 Longterm Memory System is ready to use!${NC}"
    echo ""
    echo -e "${BLUE}📚 Next steps:${NC}"
    echo "   1. Follow MCP setup instructions above to connect Claude Desktop"
    echo "   2. Scripts are ready in: $INSTALL_DIR/scripts/"
    echo "   3. View logs: tail -f ~/Library/Logs/longterm-memory-*.log"
    echo ""
    echo -e "${BLUE}📖 Documentation:${NC} $INSTALL_DIR/README.md"
    echo ""
}

# Check if running as installer
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
