/**
 * guards.ts - SQL guard predicates for the `query`, `mutate` and `sql` tools.
 *
 * EXTRACTED FROM index.ts 2026-08-31 so they can be TESTED. They were previously
 * private to a 440-line module with no test surface, which is how three bypasses
 * lived here undetected - each one a regex that reads correctly and is wrong.
 *
 * THESE ARE A DENY-LIST, NOT A BOUNDARY. The boundary is the database ROLE: the
 * MCP connection should reach this data as the least-privilege `ltm_mcp` role from
 * sql/06_create_mcp_role.sql, precisely because guards in application code are one
 * clever statement away from
 * being wrong. Three holes were found here in ten minutes by someone not trying
 * hard. Assume a fourth. Treat this file as blast-radius reduction, never as a
 * gate you can lean on.
 *
 * THE THREE BYPASSES (found 2026-08-31 during a security audit of this repo;
 * all three confirmed EXECUTABLE against PostgreSQL 17 on a
 * throwaway database, not merely matched against a regex):
 *
 *   BYPASS 1 - COMMENTS WELD TOKENS.  `DROP/**''/TABLE t` stripped to "DROPTABLE t",
 *     which /\bdrop\b/ does not match. Postgres executes it and the table is gone.
 *     Root cause was one character of asymmetry: string literals were replaced by a
 *     two-character placeholder (so neighbours stayed apart) while comments were
 *     removed ENTIRELY (so neighbours fused). Fix: comments emit a space.
 *
 *   BYPASS 2 - `UPDATE ONLY t SET ...` slipped the unqualified-write check, because
 *     \S+ consumed "only" and then required `set` where the table name stood.
 *     Confirmed: overwrote every row with no WHERE. Fix: optional (only\s+) group.
 *
 *   BYPASS 3 - A DECOY `WHERE` ANYWHERE unlocked a bare DELETE:
 *     `WITH x AS (SELECT 1 WHERE true) DELETE FROM observations` passed, because the
 *     check asked whether a WHERE existed ANYWHERE in the statement rather than
 *     whether one was attached to the write. Fix: only look AFTER the write token.
 *     GENERALISE THIS ONE: anywhere a guard asks "is X present in this string" when
 *     it means "is X attached to Y", the same hole exists - and the next instance
 *     will not look like a WHERE clause.
 *
 * Order is load-bearing: every predicate runs on normalizeSql() output, never raw
 * input. A guard applied to raw SQL has a comment-shaped bypass by construction.
 */

/**
 * Strip comments and string/identifier literals, replacing each literal with a placeholder.
 *
 * The old guards ran a comment-stripping regex and then indexOf(';') over the raw text, which
 * is not SQL-aware: a semicolon INSIDE a string literal counted as a statement separator, so a
 * single valid INSERT whose text contained ';' was rejected as "multi-statement", which breaks
 * any observation whose text happens to contain a semicolon. Scanning with literal state
 * fixes that class.
 */
export function stripLiteralsAndComments(sql: string): string {
  let out = '';
  let i = 0;
  while (i < sql.length) {
    const c = sql[i];
    const next = sql[i + 1];
    if (c === '-' && next === '-') {                    // line comment
      while (i < sql.length && sql[i] !== '\n') i++;
      out += ' ';   // SPACE, not nothing: see BYPASS 1 below
      continue;
    }
    if (c === '/' && next === '*') {                    // block comment
      i += 2;
      while (i < sql.length && !(sql[i] === '*' && sql[i + 1] === '/')) i++;
      i += 2;
      out += ' ';   // SPACE, not nothing: see BYPASS 1 below
      continue;
    }
    if (c === "'" || c === '"') {                       // string / quoted identifier
      const quote = c;
      i++;
      while (i < sql.length) {
        if (sql[i] === quote) {
          if (sql[i + 1] === quote) { i += 2; continue; } // escaped doubled quote
          i++;
          break;
        }
        i++;
      }
      out += quote === "'" ? "''" : '""';                // placeholder, no inner content
      continue;
    }
    if (c === '$') {                                     // dollar-quoted body: $tag$ ... $tag$
      const m = /^\$[A-Za-z_0-9]*\$/.exec(sql.slice(i));
      if (m) {
        const tag = m[0];
        const end = sql.indexOf(tag, i + tag.length);
        i = end === -1 ? sql.length : end + tag.length;
        out += "''";
        continue;
      }
    }
    out += c;
    i++;
  }
  return out;
}

export function hasMultipleStatements(sql: string): boolean {
  const stripped = stripLiteralsAndComments(sql).trim();
  const semiPos = stripped.indexOf(';');
  return semiPos >= 0 && stripped.slice(semiPos + 1).trim().length > 0;
}

export function normalizeSql(sql: string): string {
  return stripLiteralsAndComments(sql).replace(/\s+/g, ' ').trim().toLowerCase();
}

/**
 * True for statements that write rows, including a data-modifying CTE - the
 * "WITH e AS (INSERT .. RETURNING id) INSERT INTO .. SELECT .. FROM e" shape.
 *
 * The old check was `normalized.startsWith(op)`, which rejected every CTE because it leads
 * with `with`. That mattered: attributing an observation to an entity in ONE atomic statement
 * requires exactly this shape, so the guard was forcing writers into two round-trips (upsert
 * the entity, then insert) with no transaction around them. Found by running it, not by
 * reading the guard.
 */
export function isRowWritingStatement(normalized: string): boolean {
  if (/^(insert|update|delete)\b/.test(normalized)) return true;
  // A CTE only qualifies if it actually writes somewhere - a read-only WITH belongs in `query`.
  return /^with\b/.test(normalized) && /\b(insert\s+into|update\s+\S+\s+set|delete\s+from)\b/.test(normalized);
}

/** Destructive DDL the `sql` tool refuses. Deny-list; see the file header. */
const BLOCKED_DDL = [/\bdrop\b/, /\btruncate\b/, /\balter\s+role\b/, /\balter\s+user\b/, /\bgrant\b/, /\brevoke\b/, /\bcopy\b/];

export function isDDLBlocked(sql: string): boolean {
  return BLOCKED_DDL.some((re) => re.test(normalizeSql(sql)));
}

/**
 * A row-writing statement with no WHERE ATTACHED TO IT.
 * `(only\s+)?` is BYPASS 2; slicing after the match is BYPASS 3.
 */
const WRITE_TOKEN = /\b(delete\s+from|update\s+(only\s+)?\S+\s+set)\b/;

export function isUnqualifiedWrite(sql: string): boolean {
  const normalized = normalizeSql(sql);
  const m = WRITE_TOKEN.exec(normalized);
  if (!m) return false;
  return !/\bwhere\b/.test(normalized.slice(m.index + m[0].length));
}
