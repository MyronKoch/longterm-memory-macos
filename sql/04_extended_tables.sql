-- ============================================================================
-- Longterm Memory System - Extended Tables (Optional)
-- ============================================================================
-- Additional tables for advanced use cases like projects, sessions, and insights
-- These tables evolved from real-world usage patterns
-- Created: 2025-11-09

-- Projects table - track software projects and their status
CREATE TABLE IF NOT EXISTS projects (
    project_id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'planning',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    github_path TEXT,
    created_date DATE
);

CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_updated_at ON projects(updated_at);

-- Sessions table - track conversation contexts
CREATE TABLE IF NOT EXISTS sessions (
    session_id SERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    context TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_created_at ON sessions(created_at);
CREATE INDEX IF NOT EXISTS idx_sessions_updated_at ON sessions(updated_at);

-- Insights table - store key discoveries and learnings
CREATE TABLE IF NOT EXISTS insights (
    insight_id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES sessions(session_id),
    insight_text TEXT NOT NULL,
    insight_type VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_insights_created_at ON insights(created_at);
CREATE INDEX IF NOT EXISTS idx_insights_type ON insights(insight_type);
CREATE INDEX IF NOT EXISTS idx_insights_text ON insights USING gin(to_tsvector('english', insight_text));

-- Project updates table - track project progress
CREATE TABLE IF NOT EXISTS project_updates (
    update_id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(project_id) ON DELETE CASCADE,
    update_text TEXT NOT NULL,
    update_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_project_updates_project_id ON project_updates(project_id);
CREATE INDEX IF NOT EXISTS idx_project_updates_created_at ON project_updates(created_at DESC);

-- Project milestones table - track major achievements
CREATE TABLE IF NOT EXISTS project_milestones (
    milestone_id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES projects(project_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    achieved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_project_milestones_project_id ON project_milestones(project_id);
CREATE INDEX IF NOT EXISTS idx_project_milestones_achieved_at ON project_milestones(achieved_at DESC);

-- Session contexts table - store rich session metadata
CREATE TABLE IF NOT EXISTS session_contexts (
    context_id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES sessions(session_id) ON DELETE CASCADE,
    context_key VARCHAR(100) NOT NULL,
    context_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_session_contexts_session_id ON session_contexts(session_id);
CREATE INDEX IF NOT EXISTS idx_session_contexts_key ON session_contexts(context_key);

-- Function to auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for projects table
DROP TRIGGER IF EXISTS update_projects_updated_at ON projects;
CREATE TRIGGER update_projects_updated_at
    BEFORE UPDATE ON projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Trigger for sessions table
DROP TRIGGER IF EXISTS update_sessions_updated_at ON sessions;
CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Grant permissions (adjust as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_username;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_username;
