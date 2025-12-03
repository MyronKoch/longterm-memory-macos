# Proposal: Session Handoff System

**Date:** December 3, 2025
**Author:** PAI (via Claude Code session)
**Status:** Awaiting Review

---

## Problem Statement

When working across multiple Macs (M1 and M3), there's no structured way to hand off active work context between machines. Currently:

- Code syncs via GitHub
- Memory/observations sync via iCloud + sleepwatcher
- But **active session context** (what was I working on? what's next? any gotchas?) is lost

Users must either:
1. Remember what they were doing
2. Manually write notes somewhere
3. Start fresh and lose context

## Proposed Solution

Add a **Session Handoff System** to longterm-memory with:

1. **Dedicated `session_handoffs` table** for active/pending handoffs
2. **Automatic archival** to observations when resolved
3. **CLI commands** for creating, picking up, and resolving handoffs
4. **PAI hook integration** for prompting handoffs at session end

---

## Database Schema

### New Table: `session_handoffs`

```sql
CREATE TABLE session_handoffs (
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
CREATE INDEX idx_handoffs_status ON session_handoffs(status) WHERE status != 'resolved';

-- Index for machine-specific queries
CREATE INDEX idx_handoffs_machine ON session_handoffs(source_machine);
```

### Dedicated Entity for Handoffs

First, create a dedicated entity to hold all handoff archives:

```sql
-- Create the Session-Handoffs entity (run once during setup)
INSERT INTO entities (name, entity_type, source_type, metadata)
VALUES (
    'Session-Handoffs',
    'system',
    'system',
    '{"description": "Archived session handoffs between machines"}'::jsonb
)
ON CONFLICT (name) DO NOTHING;
```

### Archive Function

When a handoff is resolved, copy it to observations for permanent memory:

```sql
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

CREATE TRIGGER trigger_archive_handoff
AFTER UPDATE ON session_handoffs
FOR EACH ROW
EXECUTE FUNCTION archive_resolved_handoff();
```

---

## Handoff Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                        LIFECYCLE                                 │
└─────────────────────────────────────────────────────────────────┘

1. CREATE (on Mac #1 at end of session)
   ┌─────────────────────────────────────┐
   │  status: "pending"                  │
   │  source_machine: "M3-MacBook"       │
   │  summary: "Added graph filtering"   │
   │  next_steps: ["Test", "Commit"]     │
   │  picked_up_at: NULL                 │
   └─────────────────────────────────────┘
                    │
                    ▼ (syncs via iCloud)

2. PICK UP (on Mac #2 at start of session)
   ┌─────────────────────────────────────┐
   │  status: "picked_up"                │
   │  picked_up_at: NOW()                │
   │  picked_up_by: "M1-iMac"            │
   └─────────────────────────────────────┘
                    │
                    ▼ (work continues)

3. RESOLVE (when work is complete)
   ┌─────────────────────────────────────┐
   │  status: "resolved"                 │
   │  resolved_at: NOW()                 │
   │  resolution_notes: "Merged to main" │
   └─────────────────────────────────────┘
                    │
                    ▼ (trigger fires)

4. ARCHIVE (automatic via trigger)
   → Copied to observations table
   → Tagged with 'session-handoff', 'archived'
   → Searchable in semantic memory forever
```

---

## CLI Interface

### Script: `scripts/handoff.sh`

```bash
#!/bin/bash
# Session Handoff CLI

DB_NAME="${LONGTERM_MEMORY_DB:-longterm_memory}"
DB_USER="${LONGTERM_MEMORY_USER:-$(whoami)}"
HOSTNAME=$(hostname -s)
SYNC_SCRIPT="$(dirname "$0")/sync_databases.sh"

case "$1" in
    create)
        # handoff create "summary" --project "name" --branch "branch" --next "step1" --next "step2"
        # Creates a new pending handoff
        ;;

    list|ls)
        # handoff list [--all]
        # Shows pending/picked_up handoffs (or all with --all)
        ;;

    check)
        # handoff check
        # Quick view of pending handoffs for this machine to pick up
        ;;

    pickup)
        # handoff pickup <id>
        # Claims a handoff for the current machine
        ;;

    resolve)
        # handoff resolve <id> ["resolution notes"]
        # Marks handoff as resolved, triggers archive
        ;;

    show)
        # handoff show <id>
        # Shows full details of a handoff
        ;;
esac
```

### Example Usage

**End of session on Mac #1:**
```bash
$ handoff create "Added graph filtering and fixed logo sizes" \
    --project "longterm-memory-macos" \
    --branch "feature/graph-improvements" \
    --files "graph.html,semantic_*.html" \
    --next "Test changes on Mac #2" \
    --next "Commit and push" \
    --gotcha "Restart dashboard after CSS changes"

✅ Handoff #47 created
🔄 Syncing to iCloud...
✅ Ready for pickup on another machine
```

**Start of session on Mac #2:**
```bash
$ handoff check

📋 Pending Handoffs:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#47 | longterm-memory-macos (feature/graph-improvements)
    | From: M3-MacBook @ 2025-12-03 01:30 PST
    | "Added graph filtering and fixed logo sizes"
    |
    | Next Steps:
    |   1. Test changes on Mac #2
    |   2. Commit and push
    |
    | ⚠️  Gotcha: Restart dashboard after CSS changes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$ handoff pickup 47
✅ Picked up handoff #47
```

**When work is complete:**
```bash
$ handoff resolve 47 "Tested, committed, and merged to main"

✅ Handoff #47 resolved
📦 Archived to observations for permanent memory
```

---

## PAI Integration (Optional Enhancement)

### SessionEnd Hook

Add to PAI's hook system to prompt for handoff creation:

```bash
# .claude/hooks/session-end.sh
# Prompts user to create handoff if there are uncommitted changes

if git status --porcelain | grep -q .; then
    echo "📋 You have uncommitted changes. Create a handoff?"
    echo "   Run: handoff create \"your summary here\""
fi
```

### SessionStart Enhancement

Update SessionStart to check for pending handoffs:

```bash
# Check for pending handoffs at session start
PENDING=$(psql -U $USER -d longterm_memory -t -c \
    "SELECT COUNT(*) FROM session_handoffs WHERE status = 'pending'")

if [ "$PENDING" -gt 0 ]; then
    echo "📋 You have $PENDING pending handoff(s). Run 'handoff check' to view."
fi
```

---

## Implementation Plan

### Phase 1: Database (5 min)
- [ ] Create `session_handoffs` table
- [ ] Create archive trigger function
- [ ] Test trigger fires correctly

### Phase 2: CLI Script (15 min)
- [ ] Create `scripts/handoff.sh`
- [ ] Implement: create, list, check, pickup, resolve, show
- [ ] Add sync trigger after create/resolve

### Phase 3: Integration (10 min)
- [ ] Add `handoff` alias to shell
- [ ] Update README with handoff documentation
- [ ] Test full workflow Mac #1 → Mac #2

### Phase 4: PAI Hooks (Optional, later)
- [ ] SessionEnd prompt for handoff
- [ ] SessionStart notification of pending handoffs

---

## Questions for Review

1. **Schema:** Is the proposed schema sufficient? Any columns to add/remove?
2. **Archive format:** Is the observation format for archived handoffs good?
3. **CLI interface:** Does the command structure make sense?
4. **Sync:** Should handoff create/resolve automatically trigger sync, or leave that manual?
5. **Cleanup:** Should resolved handoffs be deleted from the table, or kept for a period?

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `sql/session_handoffs.sql` | Create | Table and trigger definitions |
| `scripts/handoff.sh` | Create | CLI interface |
| `README.md` | Modify | Add handoff documentation |
| `docs/SESSION_HANDOFFS.md` | Create | Detailed usage guide |

---

**Awaiting approval before implementation.**
