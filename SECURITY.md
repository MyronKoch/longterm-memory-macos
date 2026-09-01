# Security model

## The boundary is the database role

The security boundary is PostgreSQL's authorization model. [`sql/06_create_mcp_role.sql`](sql/06_create_mcp_role.sql) creates `ltm_mcp` with `SELECT`, `INSERT`, and `UPDATE` access to the memory tables. It deliberately grants no `DELETE`, `TRUNCATE`, or DDL privileges.

A database role cannot be talked out of its grants by clever text. Configure the MCP connection to use `ltm_mcp`, not the database owner or another privileged role.

You can verify the boundary yourself. This command must print `f`:

```bash
psql -tAc "SELECT has_table_privilege('ltm_mcp','public.observations','DELETE');"  # must be f
```

Tests performed while acting as `ltm_mcp` produced this behavior:

```text
SELECT / INSERT / UPDATE  -> succeed
DELETE                    -> permission denied for table observations
TRUNCATE                  -> permission denied for table observations
DROP TABLE                -> must be owner of table observations
CREATE TABLE              -> permission denied for schema public
```

Run equivalent checks against your own database after applying the role file. Role grants are the control to rely on even if every application-side guard fails.

## Deletes are refused, on purpose

All four foreign keys in the schema use `ON DELETE RESTRICT`. A parent row cannot be deleted while a child still refers to it.

Before this was fixed, a real test produced the following transcript:

```text
1 entity + 5 observations
DELETE FROM entities WHERE name='...';
-> "DELETE 1"
observations: 5 -> 0
```

The complete feedback for destroying five memories was the string `DELETE 1`. `RESTRICT` prevents that silent cascade and makes detaching child rows a deliberate act.

## The SQL guards are defence in depth, not a boundary

The MCP tools also apply SQL guards. These guards are a DENY-LIST. They block destructive DDL, statement stacking, and unqualified `DELETE` or `UPDATE` statements.

Three bypasses were found in these guards in about ten minutes by someone not trying very hard. Assume a fourth exists.

The comment and literal stripper is hand-rolled and is not a SQL parser. The guards reduce the chance and blast radius of an accidental destructive statement, but they are not proof against a determined adversary who knows they exist. This is why the MCP connection must use `ltm_mcp` rather than relying on regexes.

## A lesson worth stealing

Suppose a production database has a `note_fragments` table with 8 rows attached to one notebook, but that table's DDL is absent from the repository. If its foreign key uses a destructive delete action, the risk is invisible to a schema reader twice over: the reader cannot see the table, and cannot see what deleting its parent does.

For PostgreSQL systems, read foreign-key delete rules back from the running database instead of trusting that schema files are complete:

```sql
SELECT conrelid::regclass, conname, confdeltype FROM pg_constraint WHERE contype='f';
```

## Reporting a problem

Please open a GitHub issue with a clear description and reproduction steps. If public disclosure would put users or data at risk, share only enough in the issue to request a private follow-up.
