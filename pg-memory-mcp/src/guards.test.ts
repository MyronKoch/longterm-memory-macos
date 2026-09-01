/**
 * guard-bypass-regression.test.ts — locks the three SQL-guard bypasses found 2026-08-31.
 * Run: bun test guard-bypass-regression.test.ts
 *
 * Each bypass was confirmed EXECUTABLE against PostgreSQL 17 on a throwaway database
 * before being fixed, so these are not hypotheses about regex behaviour:
 *   B1  DROP/**\/TABLE victim;            -> "DROP TABLE", to_regclass NULL, table gone
 *   B2  UPDATE ONLY obs SET importance=0; -> "UPDATE 2", both rows overwritten, no WHERE
 *   B3  decoy WHERE in a leading CTE      -> bare DELETE FROM observations permitted
 *
 * These guards are a DENY-LIST: defence-in-depth, never a boundary. The boundary is the
 * database role. Three holes were found here in ten minutes by someone not trying very
 * hard; assume a fourth. Keep the role least-privilege regardless of what this file says.
 *
 * Import the four functions from wherever they live in your tree.
 */
import { describe, it, expect } from 'bun:test';
import { normalizeSql, hasMultipleStatements, isDDLBlocked, isUnqualifiedWrite } from './guards.js';

const rejectsDDL   = (sql: string) => isDDLBlocked(normalizeSql(sql));
const rejectsWrite = (sql: string) => isUnqualifiedWrite(normalizeSql(sql));

describe('B1 — comments must SEPARATE tokens, not weld them', () => {
  // Root cause: literals were replaced by a 2-char '' but comments emitted nothing, so
  // DROP and TABLE fused into "droptable" and every \b in the blocked list stopped matching.
  it('blocks comment-welded DROP', () => {
    expect(normalizeSql('DROP/**/TABLE entities')).toBe('drop table entities');
    expect(rejectsDDL('DROP/**/TABLE entities')).toBe(true);
  });
  it('blocks comment-welded TRUNCATE', () => {
    expect(rejectsDDL('TRUNCATE/**/TABLE observations')).toBe(true);
  });
  it('blocks whitespace-obfuscated DROP', () => {
    expect(rejectsDDL('drop\n\ttable entities')).toBe(true);
  });
});

describe('B2 — UPDATE ONLY is still an unqualified write', () => {
  it('catches UPDATE ONLY without a WHERE', () => {
    expect(rejectsWrite('UPDATE ONLY observations SET importance=0')).toBe(true);
  });
  it('still permits UPDATE ONLY with a WHERE', () => {
    expect(rejectsWrite('UPDATE ONLY observations SET importance=0 WHERE id=1')).toBe(false);
  });
});

describe('B3 — the WHERE must be ATTACHED to the write, not merely present', () => {
  // The parent of the startsWith bug: the write token is located correctly, then the
  // decision is made from context not attached to it. Any guard asking "is X present in
  // this string" when it means "is X attached to Y" has this hole. The next instance
  // will not look like a WHERE clause.
  it('catches a bare DELETE hidden behind a decoy WHERE in a leading CTE', () => {
    expect(rejectsWrite('WITH x AS (SELECT 1 WHERE true) DELETE FROM observations')).toBe(true);
  });
  it('still permits a genuinely qualified CTE delete', () => {
    expect(rejectsWrite('WITH x AS (DELETE FROM observations WHERE id=1 RETURNING *) SELECT * FROM x')).toBe(false);
  });
});

describe('bare writes stay blocked', () => {
  it('blocks DELETE with no WHERE', () => expect(rejectsWrite('DELETE FROM observations')).toBe(true));
  it('blocks UPDATE with no WHERE', () => expect(rejectsWrite('UPDATE observations SET importance=0')).toBe(true));
});

describe('statement stacking stays blocked', () => {
  it('rejects a stacked DROP', () => expect(hasMultipleStatements('SELECT 1; DROP TABLE entities;')).toBe(true));
  it('permits a lone trailing semicolon', () => expect(hasMultipleStatements('SELECT 1;')).toBe(false));
});

describe('REGRESSIONS — these must keep working', () => {
  // A guard that blocks legitimate queries gets disabled, which is its own vulnerability.
  it('permits a qualified DELETE', () => expect(rejectsWrite('DELETE FROM observations WHERE id=1')).toBe(false));
  it('permits a qualified UPDATE', () => expect(rejectsWrite('UPDATE observations SET importance=0.9 WHERE id=1')).toBe(false));
  it('permits a plain SELECT', () => expect(rejectsDDL('SELECT * FROM observations WHERE id=1')).toBe(false));
  it('does not fire on a keyword inside a string literal', () => {
    expect(rejectsDDL("SELECT 'drop table entities' AS t")).toBe(false);
  });
  it('does not fire on a keyword inside a line comment', () => {
    expect(rejectsDDL('SELECT 1 -- ; DROP TABLE x')).toBe(false);
  });
  it('does not fire on a keyword inside a dollar-quoted body', () => {
    expect(rejectsDDL('SELECT $$ ; DROP TABLE x $$ AS t')).toBe(false);
  });
  it('does not fire on a column named dropped_at', () => {
    expect(rejectsDDL('SELECT dropped_at FROM t WHERE id=1')).toBe(false);
  });
  // Stripping helps here: a decoy WHERE inside a comment is removed BEFORE the test,
  // so these correctly stay blocked rather than being waved through.
  it('is not fooled by a decoy WHERE in a trailing comment', () => {
    expect(rejectsWrite('DELETE FROM observations -- where')).toBe(true);
    expect(rejectsWrite('DELETE FROM observations /* WHERE id=1 */')).toBe(true);
  });
});
