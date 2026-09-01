-- Longterm Memory System - Least-Privilege MCP Role
-- This role is the security boundary for AI-generated database access.
-- Application-level SQL guards are deny-lists and mitigations, never boundaries;
-- clever text cannot talk a PostgreSQL role out of its grants.
-- DELETE is deliberately withheld because a memory store should never silently destroy content.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ltm_mcp') THEN
        -- Replace this placeholder before running, or set the password afterward as shown below.
        CREATE ROLE ltm_mcp LOGIN PASSWORD 'REPLACE_WITH_A_STRONG_PASSWORD';
    END IF;
END
$$;

-- To set or replace the password interactively, run: \password ltm_mcp
-- Alternatively: ALTER ROLE ltm_mcp PASSWORD 'your-strong-password';

ALTER ROLE ltm_mcp NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOINHERIT;

-- :"DBNAME" is the database psql is CONNECTED to, so this file works whatever you named it
-- (the installer honours LONGTERM_MEMORY_DB). Hardcoding a name here would silently grant
-- CONNECT on a DIFFERENT database that happened to share it. Run with: psql -d <yourdb> -f this
REVOKE ALL PRIVILEGES ON DATABASE :"DBNAME" FROM ltm_mcp;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM ltm_mcp;
REVOKE ALL PRIVILEGES ON entities, observations, observations_archive, all_observations FROM ltm_mcp;
REVOKE ALL PRIVILEGES ON SEQUENCE entities_id_seq, observations_id_seq FROM ltm_mcp;

GRANT CONNECT ON DATABASE :"DBNAME" TO ltm_mcp;
GRANT USAGE ON SCHEMA public TO ltm_mcp;
GRANT SELECT, INSERT, UPDATE ON entities, observations, observations_archive TO ltm_mcp;
GRANT SELECT ON all_observations TO ltm_mcp;
GRANT USAGE, SELECT ON SEQUENCE entities_id_seq, observations_id_seq TO ltm_mcp;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM ltm_mcp;

-- Verify that DELETE is unavailable (the second command targets no rows and should fail with "permission denied"):
-- psql "postgresql://ltm_mcp@localhost:5432/$LONGTERM_MEMORY_DB" -c "SELECT has_table_privilege('ltm_mcp', 'public.observations', 'DELETE');"
-- psql "postgresql://ltm_mcp@localhost:5432/$LONGTERM_MEMORY_DB" -v ON_ERROR_STOP=1 -c "BEGIN; DELETE FROM observations WHERE false; ROLLBACK;"
