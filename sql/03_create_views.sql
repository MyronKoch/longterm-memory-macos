-- ============================================================================
-- Longterm Memory System - Views
-- ============================================================================
-- Creates unified views for querying active and archived observations
-- Created: 2025-11-09

-- Drop view if exists (for idempotency)
DROP VIEW IF EXISTS all_observations;

-- Create unified view combining active and archived observations
-- This provides a single interface to query both hot (active) and cold (archive) storage
-- without performance penalty on daily operations
CREATE VIEW all_observations AS
  SELECT
    id,
    entity_id,
    observation_text,
    observation_index,
    created_at,
    source_type,
    embedding,
    'active' as storage_location
  FROM observations
  UNION ALL
  SELECT
    id,
    entity_id,
    observation_text,
    observation_index,
    created_at,
    source_type,
    embedding,
    'archive' as storage_location
  FROM observations_archive;

-- Grant appropriate permissions
-- GRANT SELECT ON all_observations TO PUBLIC;

-- Usage examples:
--
-- Query all observations (active + archive):
--   SELECT * FROM all_observations;
--
-- Query only active observations (for performance):
--   SELECT * FROM all_observations WHERE storage_location = 'active';
--
-- Query only archived observations:
--   SELECT * FROM all_observations WHERE storage_location = 'archive';
--
-- Count by storage location:
--   SELECT storage_location, COUNT(*) FROM all_observations GROUP BY storage_location;
--
-- Search across both with date range:
--   SELECT * FROM all_observations
--   WHERE observation_text ILIKE '%keyword%'
--   AND created_at >= '2025-01-01';
