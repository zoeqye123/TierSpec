import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { z } from 'zod';

import { Database } from './db/client.js';
import { MigrationRunner } from './db/migrate.js';
import { createHierarchyTools, registerHierarchyTools, type HierarchyToolsOptions } from './tools/hierarchy.js';
import { queryToolDefinitions, getItemTree, listItems, searchItems, registerQueryTools } from './tools/query.js';
import { ensureWorkflowSchema, blockItem, transitionState } from './tools/workflow.js';
import { blockItemInputSchema, transitionStateInputSchema } from './schemas/workflow.js';

export const SERVER_INFO = {
  name: '@tierspec/mcp-server',
  version: '0.1.0',
} as const;

export const ALL_TOOL_NAMES = [
  'create_item',
  'get_item',
  'move_item',
  'reorder_items',
  'delete_item',
  'get_item_tree',
  'search_items',
  'list_items',
  'transition_state',
  'block_item',
] as const;

const workflowToolDefinitions = {
  transition_state: {
    title: 'Transition State',
    description: 'Move an item through the workflow state machine and log the transition.',
    inputSchema: transitionStateInputSchema.extend({
      actor_id: z.string().trim().min(1, 'actor_id is required').optional(),
    }),
    annotations: {
      title: 'Transition State',
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    },
  },
  block_item: {
    title: 'Block Item',
    description: 'Mark an item as blocked and capture blocker metadata for auditability.',
    inputSchema: blockItemInputSchema.extend({
      actor_id: z.string().trim().min(1, 'actor_id is required').optional(),
    }),
    annotations: {
      title: 'Block Item',
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    },
  },
} as const;

export type TierSpecServerOptions = {
  database?: Database;
  databasePath?: string;
  actorUserId?: string;
  actorName?: string;
  actorEmail?: string;
};

export type TierSpecServerRuntime = {
  server: McpServer;
  database: Database;
  toolNames: readonly string[];
  close(): Promise<void>;
};

function formatToolResult(value: unknown) {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }],
    structuredContent: value as Record<string, unknown>,
  };
}

function ensureActorUser(database: Database, actorUserId: string, actorName: string, actorEmail: string) {
  database
    .prepare('INSERT OR IGNORE INTO users (id, name, email) VALUES (?, ?, ?)')
    .run(actorUserId, actorName, actorEmail);
}

export function initializeDatabase({
  databasePath = ':memory:',
  actorUserId = 'system',
  actorName = 'TierSpec MCP Server',
  actorEmail = `${actorUserId}@tierspec.local`,
}: Omit<TierSpecServerOptions, 'database'> = {}) {
  const database = Database.getInstance(databasePath);

  new MigrationRunner(database).up();
  ensureWorkflowSchema(database);
  ensureActorUser(database, actorUserId, actorName, actorEmail);

  return database;
}

export function registerWorkflowTools(server: McpServer, database: Database, actorUserId = 'system') {
  ensureWorkflowSchema(database);

  server.registerTool('transition_state', workflowToolDefinitions.transition_state, async (args) => {
    const item = transitionState(database, {
      ...args,
      actor_id: args.actor_id ?? actorUserId,
    });
    return formatToolResult({ item });
  });

  server.registerTool('block_item', workflowToolDefinitions.block_item, async (args) => {
    const item = blockItem(database, {
      ...args,
      actor_id: args.actor_id ?? actorUserId,
    });
    return formatToolResult({ item });
  });
}

export function registerAllTools(server: McpServer, database: Database, actorUserId = 'system') {
  registerHierarchyTools(server as Parameters<typeof registerHierarchyTools>[0], {
    database,
    actorUserId,
  } satisfies HierarchyToolsOptions);
  registerQueryTools(server, database);
  registerWorkflowTools(server, database, actorUserId);

  return ALL_TOOL_NAMES;
}

export function createTierSpecServer(options: TierSpecServerOptions = {}): TierSpecServerRuntime {
  const actorUserId = options.actorUserId ?? 'system';
  const actorName = options.actorName ?? 'TierSpec MCP Server';
  const actorEmail = options.actorEmail ?? `${actorUserId}@tierspec.local`;
  const database = options.database ?? initializeDatabase({
    databasePath: options.databasePath,
    actorUserId,
    actorName,
    actorEmail,
  });

  ensureWorkflowSchema(database);
  ensureActorUser(database, actorUserId, actorName, actorEmail);

  const server = new McpServer(SERVER_INFO, {
    capabilities: {
      tools: {},
    },
    instructions:
      'TierSpec MCP server for hierarchy management, query operations, and workflow state transitions.',
  });

  const toolNames = registerAllTools(server, database, actorUserId);
  const ownsDatabase = !options.database;

  return {
    server,
    database,
    toolNames,
    async close() {
      await server.close();
      if (ownsDatabase) {
        database.close();
      }
    },
  };
}

export {
  blockItem,
  createHierarchyTools,
  getItemTree,
  listItems,
  queryToolDefinitions,
  searchItems,
  transitionState,
  workflowToolDefinitions,
};
