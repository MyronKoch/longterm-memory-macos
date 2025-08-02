#!/bin/bash

# Longterm Memory System - Health Check
# Verifies all components are working correctly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
DB_HOST="${LONGTERM_MEMORY_HOST:-localhost}"
DB_PORT="${LONGTERM_MEMORY_PORT:-5432}"

echo -e "${BLUE}🏥 Longterm Memory System - Health Check${NC}"
echo ""

# Check PostgreSQL
echo -n "📊 PostgreSQL service: "
if brew services list | grep -q "postgresql@17.*started"; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
    echo "   Run: brew services start postgresql@17"
    exit 1
fi

# Check database connection
echo -n "🔌 Database connection: "
if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &>/dev/null; then
    echo -e "${GREEN}✅ Connected${NC}"
else
    echo -e "${RED}❌ Cannot connect${NC}"
    echo "   Check database credentials"
    exit 1
fi

# Check pgvector extension
echo -n "🧮 pgvector extension: "
PGVECTOR_CHECK=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'vector');" 2>/dev/null)
if [[ "$PGVECTOR_CHECK" == *"t"* ]]; then
    echo -e "${GREEN}✅ Installed${NC}"
else
    echo -e "${RED}❌ Not installed${NC}"
    echo "   Run: CREATE EXTENSION vector;"
    exit 1
fi

# Check tables exist
echo -n "📋 Core tables: "
TABLES_CHECK=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('entities', 'observations', 'observations_archive');" 2>/dev/null | tr -d ' ')
if [ "$TABLES_CHECK" -eq 3 ]; then
    echo -e "${GREEN}✅ All present${NC}"
else
    echo -e "${RED}❌ Missing tables (found $TABLES_CHECK/3)${NC}"
    echo "   Run: psql -f sql/02_create_tables.sql"
    exit 1
fi

# Check Ollama
echo -n "🤖 Ollama service: "
if curl -s http://localhost:11434/api/tags &>/dev/null; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${YELLOW}⚠️  Not running${NC}"
    echo "   Run: brew services start ollama"
fi

# Check nomic-embed-text model
echo -n "📦 nomic-embed-text model: "
if curl -s http://localhost:11434/api/tags | grep -q "nomic-embed-text"; then
    echo -e "${GREEN}✅ Installed${NC}"
else
    echo -e "${YELLOW}⚠️  Not installed${NC}"
    echo "   Run: ollama pull nomic-embed-text"
fi

# Check LaunchAgents
echo -n "⏰ Backup LaunchAgent: "
if [ -f "$HOME/Library/LaunchAgents/com.longtermmemory.backup.plist" ]; then
    if launchctl list | grep -q "com.longtermmemory.backup"; then
        echo -e "${GREEN}✅ Loaded${NC}"
    else
        echo -e "${YELLOW}⚠️  Not loaded${NC}"
        echo "   Run: launchctl load ~/Library/LaunchAgents/com.longtermmemory.backup.plist"
    fi
else
    echo -e "${YELLOW}⚠️  Not installed${NC}"
fi

echo -n "⏰ Embeddings LaunchAgent: "
if [ -f "$HOME/Library/LaunchAgents/com.longtermmemory.embeddings.plist" ]; then
    if launchctl list | grep -q "com.longtermmemory.embeddings"; then
        echo -e "${GREEN}✅ Loaded${NC}"
    else
        echo -e "${YELLOW}⚠️  Not loaded${NC}"
        echo "   Run: launchctl load ~/Library/LaunchAgents/com.longtermmemory.embeddings.plist"
    fi
else
    echo -e "${YELLOW}⚠️  Not installed${NC}"
fi

# Database statistics
echo ""
echo -e "${BLUE}📊 Database Statistics:${NC}"

ENTITY_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM entities;" 2>/dev/null | tr -d ' ')
OBS_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM observations;" 2>/dev/null | tr -d ' ')
EMBEDDED_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM observations WHERE embedding IS NOT NULL;" 2>/dev/null | tr -d ' ')
ARCHIVED_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM observations_archive;" 2>/dev/null | tr -d ' ')

echo "   Entities: $ENTITY_COUNT"
echo "   Observations: $OBS_COUNT"
echo "   With embeddings: $EMBEDDED_COUNT"
echo "   Archived: $ARCHIVED_COUNT"

# Embedding coverage
if [ "$OBS_COUNT" -gt 0 ]; then
    COVERAGE=$((EMBEDDED_COUNT * 100 / OBS_COUNT))
    echo "   Embedding coverage: ${COVERAGE}%"
fi

echo ""
echo -e "${GREEN}✅ Health check complete!${NC}"
