-- Session Handoffs System
-- Enables context handoffs between machines (M1 ↔ M3)
-- Created: 2025-12-03

-- ============================================
-- ENTITY FOR ARCHIVED HANDOFFS
-- ============================================

-- Insert only if not exists (no unique constraint on name)
INSERT INTO entities (name, entity_type, source_type, metadata)
SELECT 'Session-Handoffs', 'system', 'system', '{"description": "Archived session handoffs between machines"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM entities WHERE name = 'Session-Handoffs');

-- ============================================
-- SESSION HANDOFFS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS session_handoffs (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    source_machine VARCHAR(50) NOT NULL,

    -- What was being worked on
    project VARCHAR(255),
    branch VARCHAR(255),
    files_modified TEXT[],
    working_directory TEXT,

    -- Current state
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'picked_up', 'resolved')),
    summary TEXT NOT NULL,

    -- Context
    decisions_made TEXT,
    blockers TEXT,
    gotchas TEXT,

    -- Next steps
    next_steps TEXT[],

    -- Pickup tracking
    picked_up_at TIMESTAMP WITH TIME ZONE,
    picked_up_by VARCHAR(50),

    -- Resolution
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT
);

-- Index for quick "show me pending handoffs" queries
CREATE INDEX IF NOT EXISTS idx_handoffs_status ON session_handoffs(status) WHERE status != 'resolved';

-- Index for machine-specific queries
CREATE INDEX IF NOT EXISTS idx_handoffs_machine ON session_handoffs(source_machine);

-- ============================================
-- ARCHIVE TRIGGER FUNCTION
-- ============================================

CREATE OR REPLACE FUNCTION archive_resolved_handoff()
RETURNS TRIGGER AS $$
DECLARE
    handoff_entity_id INTEGER;
BEGIN
    IF NEW.status = 'resolved' AND OLD.status != 'resolved' THEN
        -- Get the Session-Handoffs entity ID
        SELECT id INTO handoff_entity_id
        FROM entities
        WHERE name = 'Session-Handoffs';

        -- Insert into observations (observation_index auto-set by trigger)
        INSERT INTO observations (
            entity_id,
            observation_text,
            source_type,
            observation_type,
            tags,
            metadata
        )
        VALUES (
            handoff_entity_id,
            format(
                'Session Handoff [%s → %s]: %s | Project: %s | Branch: %s | Next: %s | Resolution: %s',
                OLD.source_machine,
                COALESCE(NEW.picked_up_by, 'unknown'),
                NEW.summary,
                COALESCE(NEW.project, 'unspecified'),
                COALESCE(NEW.branch, 'unspecified'),
                array_to_string(NEW.next_steps, ', '),
                COALESCE(NEW.resolution_notes, 'completed')
            ),
            'system',
            'session-handoff',
            ARRAY['session-handoff', 'archived', COALESCE(NEW.project, 'general')],
            jsonb_build_object(
                'handoff_id', NEW.id,
                'source_machine', NEW.source_machine,
                'picked_up_by', NEW.picked_up_by,
                'project', NEW.project,
                'branch', NEW.branch,
                'created_at', NEW.created_at,
                'resolved_at', NEW.resolved_at,
                'files_modified', NEW.files_modified
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists, then create
DROP TRIGGER IF EXISTS trigger_archive_handoff ON session_handoffs;

CREATE TRIGGER trigger_archive_handoff
AFTER UPDATE ON session_handoffs
FOR EACH ROW
EXECUTE FUNCTION archive_resolved_handoff();

-- ============================================
-- VERIFICATION
-- ============================================

-- Verify table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'session_handoffs') THEN
        RAISE NOTICE 'session_handoffs table created successfully';
    END IF;
END $$;
