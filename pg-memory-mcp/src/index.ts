#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import pg from "pg";
import { z } from "zod";

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
    // Validate it's a SELECT
    const trimmed = sql.trim().toLowerCase();
    if (!trimmed.startsWith("select") && !trimmed.startsWith("with")) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "query tool only accepts SELECT or WITH statements. Use 'mutate' for INSERT/UPDATE/DELETE or 'sql' for other operations.",
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
    const trimmed = sql.trim().toLowerCase();
    const allowed = ["insert", "update", "delete"];
    const isAllowed = allowed.some((op) => trimmed.startsWith(op));

    if (!isAllowed) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({
              error: "mutate tool only accepts INSERT, UPDATE, or DELETE. Use 'query' for SELECT or 'sql' for other operations.",
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
  "Execute arbitrary SQL. Use for CREATE, ALTER, DROP, transactions, or complex operations. Use with caution.",
  {
    sql: z.string().describe("SQL statement to execute"),
    params: paramsSchema,
  },
  async ({ sql, params }) => {
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
