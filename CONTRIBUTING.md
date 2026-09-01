# Contributing

## Run the checks locally

Run the TypeScript checks from the MCP package:

```bash
cd pg-memory-mcp
bun install
bunx tsc --noEmit
bun test
```

The jobs in [`.github/workflows/ci.yml`](.github/workflows/ci.yml) are the reference for CI behavior. They run the SQL guard regression suite, apply the schema to PostgreSQL 17 with pgvector, verify the least-privilege role and foreign keys, check the installer, and reject stale documentation.

Check shell syntax without executing the scripts:

```bash
bash -n install.sh
bash -n scripts/*.sh
```

Apply the SQL to a disposable scratch database, never to a database containing memories:

```bash
createdb longterm_memory_scratch
psql -v ON_ERROR_STOP=1 -d longterm_memory_scratch -c 'CREATE EXTENSION IF NOT EXISTS vector;'
psql -v ON_ERROR_STOP=1 -d longterm_memory_scratch -f sql/02_create_tables.sql
psql -v ON_ERROR_STOP=1 -d longterm_memory_scratch -f sql/03_create_views.sql
psql -v ON_ERROR_STOP=1 -d longterm_memory_scratch -f sql/04_extended_tables.sql
psql -v ON_ERROR_STOP=1 -d longterm_memory_scratch -f sql/06_create_mcp_role.sql
```

## Verification discipline

- **Verify by execution, not by reading.** A guard that reads correctly can still be wrong.

- **Verify the instrument before believing a zero.** An empty grep result is a claim about absence, so first confirm the same search finds something you know is present.

- **Re-derive important numbers.** A number that is real, plausible, and wrong is the hardest failure to catch because it passes every review that does not independently derive it.

- **Check that you measured the right artifact.** When two copies of a file exist, "which one did I just measure" is a bigger risk than "is the measurement correct," and it has no natural warning signal.

- **Run a regression test against the broken version too.** A test that only ever runs green cannot show whether the bug is fixed or the test is blind.

- **Beware tests that certify themselves.** A test for `ON DELETE RESTRICT` that deletes a parent and merely expects an error can pass when the target constraint is absent. PostgreSQL stops at the first violated constraint, so any other `RESTRICT` relationship on that parent can satisfy the check. Asserting the constraint name is not sufficient either: when another referencing row exists, PostgreSQL can emit a byte-identical error with or without the target constraint. The load-bearing half of the test is choosing a parent with no other referencing rows.
