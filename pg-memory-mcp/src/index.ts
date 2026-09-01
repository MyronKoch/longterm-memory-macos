#!/usr/bin/env node

// These guards are a deny-list intended to reduce blast radius.
// The real security boundary is the least-privilege database role created by
// sql/06_create_mcp_role.sql. Three bypasses were found in these guards in
// ten minutes - assume a fourth.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import pg from "pg";
import { z } from "zod";
import {
  hasMultipleStatements,
  isDDLBlocked,
  isRowWritingStatement,
  isUnqualifiedWrite,
  normalizeSql,
} from "./guards.js";

const { Pool } = pg;

// Connection string from environment or CLI arg
const connectionString = process.env.DATABASE_URL || process.argv[2];

if (!connectionString) {
  console.error("Usage: pg-memory-mcp <connection-string>");
  console.error("  or set DATABASE_URL environment variable");
  process.exit(1);
}

const pool = new Pool({ connectionString });

// Create the MCP server
const server = new McpServer({
  name: "pg-memory-mcp",
  version: "1.0.0",
});

// Shared schema for params
const paramsSchema = z.array(z.unknown()).optional().describe("Query parameters ($1, $2, etc.)");

// Tool 1: query - SELECT operations
server.tool(
  "query",
  "Execute a SELECT query. Returns rows as JSON. Use for reading data and vector similarity searches.",
  {
    sql: z.string().describe("SELECT query to execute"),
    params: paramsSchema,
  },
  async ({ sql, params }) => {
    if (hasMultipleStatements(sql)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "Multi-statement queries are not allowed.",
            }),
          },
        ],
      };
    }

    const normalized = normalizeSql(sql);

    if (isRowWritingStatement(normalized)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "query is read-only. Use 'mutate' for INSERT/UPDATE/DELETE, including data-modifying CTEs.",
            }),
          },
        ],
      };
    }

    if (!/^(select|with)\b/.test(normalized)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "query only accepts SELECT or WITH statements. Use 'sql' for other operations.",
            }),
          },
        ],
      };
    }

    try {
      const result = await pool.query(sql, (params as unknown[]) || []);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              rowCount: result.rowCount,
              rows: result.rows,
            }),
          },
        ],
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: JSON.stringify({ error: String(error) }) }],
      };
    }
  }
);

// Tool 2: mutate - INSERT/UPDATE/DELETE operations
server.tool(
  "mutate",
  "Execute INSERT, UPDATE, or DELETE operations. Returns affected row count and any RETURNING data.",
  {
    sql: z.string().describe("INSERT, UPDATE, or DELETE query"),
    params: paramsSchema,
  },
  async ({ sql, params }) => {
    if (hasMultipleStatements(sql)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "Multi-statement queries are not allowed.",
            }),
          },
        ],
      };
    }

    const normalized = normalizeSql(sql);

    if (!isRowWritingStatement(normalized)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "mutate only accepts INSERT, UPDATE, DELETE, or a data-modifying WITH (a CTE that writes). Use 'query' for SELECT or 'sql' for schema operations.",
            }),
          },
        ],
      };
    }

    if (isUnqualifiedWrite(sql)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "DELETE/UPDATE without a WHERE clause is blocked (it would affect every row). Add a WHERE clause, or use psql directly for an intentional full-table operation.",
            }),
          },
        ],
      };
    }

    try {
      const result = await pool.query(sql, (params as unknown[]) || []);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              rowCount: result.rowCount,
              rows: result.rows,
            }),
          },
        ],
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: JSON.stringify({ error: String(error) }) }],
      };
    }
  }
);

// Tool 3: sql - Raw SQL for anything else
server.tool(
  "sql",
  "Execute a single SQL statement for permitted schema and complex operations. Destructive DDL such as DROP, TRUNCATE, and ALTER ROLE is blocked.",
  {
    sql: z.string().describe("SQL statement to execute"),
    params: paramsSchema,
  },
  async ({ sql, params }) => {
    if (isDDLBlocked(sql)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "Destructive DDL is blocked. Use psql directly for DROP/TRUNCATE/ALTER ROLE operations.",
            }),
          },
        ],
      };
    }

    if (hasMultipleStatements(sql)) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "Multi-statement queries are not allowed.",
            }),
          },
        ],
      };
    }

    try {
      const result = await pool.query(sql, (params as unknown[]) || []);
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              command: result.command,
              rowCount: result.rowCount,
              rows: result.rows,
            }),
          },
        ],
      };
    } catch (error) {
      return {
        content: [{ type: "text", text: JSON.stringify({ error: String(error) }) }],
      };
    }
  }
);

// Graceful shutdown
process.on("SIGINT", async () => {
  await pool.end();
  process.exit(0);
});

process.on("SIGTERM", async () => {
  await pool.end();
  process.exit(0);
});

// Start the server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("pg-memory-mcp server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
