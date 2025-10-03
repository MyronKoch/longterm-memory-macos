-- ============================================================================
-- Migration: Add Observation Metadata Columns
-- ============================================================================
-- Adds semantic categorization columns to observations and observations_archive
-- Created: 2024-11-25
-- Safe to run multiple times (idempotent)

-- ============================================================================
-- FORWARD MIGRATION
-- ============================================================================

-- Add columns to observations table
ALTER TABLE observations
  ADD COLUMN IF NOT EXISTS observation_type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS importance FLOAT CHECK (importance >= 0 AND importance <= 1),
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS tags TEXT[];

-- Add columns to observations_archive table
ALTER TABLE observations_archive
  ADD COLUMN IF NOT EXISTS observation_type VARCHAR(50),
  ADD COLUMN IF NOT EXISTS importance FLOAT CHECK (importance >= 0 AND importance <= 1),
  ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS tags TEXT[];

-- Create indexes for performance on observations
CREATE INDEX IF NOT EXISTS idx_observations_type 
  ON observations(observation_type) 
  WHERE observation_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_observations_importance 
  ON observations(importance DESC NULLS LAST) 
  WHERE importance IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_observations_metadata 
  ON observations USING GIN(metadata);

CREATE INDEX IF NOT EXISTS idx_observations_tags 
  ON observations USING GIN(tags);

-- Create indexes for performance on observations_archive
CREATE INDEX IF NOT EXISTS idx_observations_archive_type 
  ON observations_archive(observation_type) 
  WHERE observation_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_observations_archive_importance 
  ON observations_archive(importance DESC NULLS LAST) 
  WHERE importance IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_observations_archive_metadata 
  ON observations_archive USING GIN(metadata);

CREATE INDEX IF NOT EXISTS idx_observations_archive_tags 
  ON observations_archive USING GIN(tags);

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

-- Insert observation with new metadata:
-- INSERT INTO observations (entity_id, observation_text, observation_index, observation_type, importance, metadata, tags)
-- VALUES (
--   (SELECT id FROM entities WHERE name = 'Your Entity'),
--   'Completed major project milestone',
--   (SELECT COALESCE(MAX(observation_index), 0) + 1 FROM observations WHERE entity_id = ...),
--   'milestone',
--   0.95,
--   '{"project": "MyProject", "category": "development"}'::jsonb,
--   ARRAY['project', 'milestone', 'achievement']
-- );

-- Query by type:
-- SELECT * FROM observations WHERE observation_type = 'insight';

-- Query by importance:
-- SELECT * FROM observations WHERE importance > 0.8 ORDER BY importance DESC;

-- Query by metadata:
-- SELECT * FROM observations WHERE metadata @> '{"project": "MyronAI"}'::jsonb;

-- Query by tags:
-- SELECT * FROM observations WHERE 'consciousness' = ANY(tags);

-- Combined query:
-- SELECT observation_text, observation_type, importance, tags
-- FROM observations
-- WHERE observation_type = 'insight'
--   AND importance > 0.7
--   AND metadata @> '{"category": "development"}'::jsonb
-- ORDER BY importance DESC, created_at DESC
-- LIMIT 10;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- ============================================================================

-- To rollback this migration, run the following:
--
-- -- Drop indexes first
-- DROP INDEX IF EXISTS idx_observations_type;
-- DROP INDEX IF EXISTS idx_observations_importance;
-- DROP INDEX IF EXISTS idx_observations_metadata;
-- DROP INDEX IF EXISTS idx_observations_tags;
-- DROP INDEX IF EXISTS idx_observations_archive_type;
-- DROP INDEX IF EXISTS idx_observations_archive_importance;
-- DROP INDEX IF EXISTS idx_observations_archive_metadata;
-- DROP INDEX IF EXISTS idx_observations_archive_tags;
--
-- -- Drop columns
-- ALTER TABLE observations
--   DROP COLUMN IF EXISTS observation_type,
--   DROP COLUMN IF EXISTS importance,
--   DROP COLUMN IF EXISTS metadata,
--   DROP COLUMN IF EXISTS tags;
--
-- ALTER TABLE observations_archive
--   DROP COLUMN IF EXISTS observation_type,
--   DROP COLUMN IF EXISTS importance,
--   DROP COLUMN IF EXISTS metadata,
--   DROP COLUMN IF EXISTS tags;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Verify columns were added:
-- SELECT column_name, data_type, is_nullable 
-- FROM information_schema.columns 
-- WHERE table_name = 'observations' 
--   AND column_name IN ('observation_type', 'importance', 'metadata', 'tags');

-- Verify indexes were created:
-- SELECT indexname, indexdef 
-- FROM pg_indexes 
-- WHERE tablename = 'observations' 
--   AND indexname LIKE 'idx_observations_%type%'
--      OR indexname LIKE 'idx_observations_%importance%'
--      OR indexname LIKE 'idx_observations_%metadata%'
--      OR indexname LIKE 'idx_observations_%tags%';
