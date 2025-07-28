-- Longterm Memory System - Core Tables
-- Creates entities, observations, and archive tables

-- Entities table - stores unique entities (people, projects, concepts, etc.)
CREATE TABLE IF NOT EXISTS entities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    entity_type VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_type VARCHAR(50) DEFAULT 'imported',
    observation_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create index on entity name for faster lookups
CREATE INDEX IF NOT EXISTS idx_entities_name ON entities(name);
CREATE INDEX IF NOT EXISTS idx_entities_type ON entities(entity_type);

-- Observations table - stores individual observations with embeddings
CREATE TABLE IF NOT EXISTS observations (
    id SERIAL PRIMARY KEY,
    entity_id INTEGER REFERENCES entities(id) ON DELETE CASCADE,
    observation_text TEXT NOT NULL,
    observation_index INTEGER NOT NULL,
    observation_type VARCHAR(100) DEFAULT 'note',
    importance FLOAT DEFAULT 0.5,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_type VARCHAR(50) DEFAULT 'imported',
    embedding vector(768)  -- nomic-embed-text uses 768 dimensions
);

-- Create indexes for observations
CREATE INDEX IF NOT EXISTS idx_observations_entity_id ON observations(entity_id);
CREATE INDEX IF NOT EXISTS idx_observations_created_at ON observations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_observations_source_type ON observations(source_type);
CREATE INDEX IF NOT EXISTS idx_observations_type ON observations(observation_type);
CREATE INDEX IF NOT EXISTS idx_observations_importance ON observations(importance DESC);
CREATE INDEX IF NOT EXISTS idx_observations_metadata_url ON observations ((lower(metadata->>'url')));
CREATE INDEX IF NOT EXISTS idx_observations_tags ON observations USING GIN (tags);

-- Vector similarity search index (HNSW for fast cosine similarity)
CREATE INDEX IF NOT EXISTS observations_embedding_idx 
ON observations USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- Observations archive table - stores chunked or archived observations
CREATE TABLE IF NOT EXISTS observations_archive (
    id INTEGER NOT NULL,
    entity_id INTEGER,
    observation_text TEXT NOT NULL,
    observation_index INTEGER NOT NULL,
    observation_type VARCHAR(100) DEFAULT 'note',
    importance FLOAT DEFAULT 0.5,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_type VARCHAR(50) DEFAULT 'imported',
    embedding vector(768),
    archived_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for archive
CREATE INDEX IF NOT EXISTS idx_observations_archive_entity_id ON observations_archive(entity_id);
CREATE INDEX IF NOT EXISTS idx_observations_archive_archived_at ON observations_archive(archived_at DESC);

-- Vector similarity search index for archive
CREATE INDEX IF NOT EXISTS observations_archive_embedding_idx 
ON observations_archive USING ivfflat (embedding vector_cosine_ops) 
WITH (lists = 100);

-- Function to auto-increment observation_index
CREATE OR REPLACE FUNCTION set_observation_index()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.observation_index IS NULL THEN
        SELECT COALESCE(MAX(observation_index), 0) + 1 
        INTO NEW.observation_index
        FROM observations 
        WHERE entity_id = NEW.entity_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-set observation_index
CREATE TRIGGER auto_set_observation_index
    BEFORE INSERT ON observations
    FOR EACH ROW
    EXECUTE FUNCTION set_observation_index();

-- Grant permissions (adjust username as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_username;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO your_username;
