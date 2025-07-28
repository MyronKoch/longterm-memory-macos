-- Longterm Memory System - Database Creation
-- Creates the main database and required extensions

-- NOTE: You can name the database anything you want. Common options:
--   - longterm_memory (default)
--   - claude_memory (legacy option)
-- Make sure to update your MCP connection string to match!

-- Create database (run as postgres superuser)
CREATE DATABASE longterm_memory
    WITH
    OWNER = CURRENT_USER
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0;

-- Connect to the new database
\c longterm_memory

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Verify extensions
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'uuid-ossp');
