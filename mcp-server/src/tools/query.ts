import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';

import type { Database } from '../db/client.js';
import type { Item } from '../db/types.js';
import { getItemTreeSchema, getItemTreeSchemaShape, listItemsSchema, listItemsSchemaShape, searchItemsSchema, searchItemsSchemaShape, type GetItemTreeInput, type ItemFilters, type ListItemsInput, type SearchItemsInput } from '../schemas/query.js';

type ItemRow = Omit<Item, 'labels' | 'ai_generated'> & {
  labels: string;
  ai_generated: number;
};

type ItemTreeRow = ItemRow & { depth: number };

export type ItemTreeNode = Item & {
  depth: number;
  children: ItemTreeNode[];
};

export type SearchItemsResult = {
  items: Item[];
  page: number;
  limit: number;
  total: number;
  total_pages: number;
};

const readOnlyAnnotations = {
  readOnlyHint: true,
  destructiveHint: false,
  idempotentHint: true,
  openWorldHint: false,
} as const;

export const queryToolDefinitions = {
  get_item_tree: {
    description: 'Get a hierarchical subtree for an item',
    inputSchema: getItemTreeSchemaShape,
    annotations: readOnlyAnnotations,
  },
  search_items: {
    description: 'Search items by title or description with pagination',
    inputSchema: searchItemsSchemaShape,
    annotations: readOnlyAnnotations,
  },
  list_items: {
    description: 'List items filtered by parent, type, or status',
    inputSchema: listItemsSchemaShape,
    annotations: readOnlyAnnotations,
  },
} as const;

function mapItem(row: ItemRow): Item {
  return {
    ...row,
    labels: JSON.parse(row.labels) as string[],
    ai_generated: Boolean(row.ai_generated),
  };
}

function escapeLike(value: string) {
  return value.replace(/([%_\\])/g, '\\$1');
}

function buildFilterClauses(filters: ItemFilters | undefined, values: unknown[]) {
  const clauses = ['items.deleted_at IS NULL'];

  if (filters?.parent_id !== undefined) {
    clauses.push('items.parent_id = ?');
    values.push(filters.parent_id);
  }

  if (filters?.type !== undefined) {
    clauses.push('items.type = ?');
    values.push(filters.type);
  }

  if (filters?.status !== undefined) {
    clauses.push('items.status = ?');
    values.push(filters.status);
  }

  return clauses;
}

export function getItemTree(database: Database, input: GetItemTreeInput): ItemTreeNode {
  const { root_id, max_depth = 5 } = getItemTreeSchema.parse(input);
  const rows = database
    .prepare<unknown[], ItemTreeRow>(
      `SELECT items.*, item_paths.depth
       FROM item_paths
       JOIN items ON items.id = item_paths.descendant_id
       WHERE item_paths.ancestor_id = ?
         AND item_paths.depth <= ?
         AND items.deleted_at IS NULL
       ORDER BY item_paths.depth, items.position, items.title COLLATE NOCASE, items.id`,
    )
    .all(root_id, max_depth);

  if (rows.length === 0) {
    throw new Error(`Item not found: ${root_id}`);
  }

  const nodes = new Map<string, ItemTreeNode>();

  for (const row of rows) {
    nodes.set(row.id, {
      ...mapItem(row),
      depth: row.depth,
      children: [],
    });
  }

  for (const row of rows) {
    if (row.depth === 0) {
      continue;
    }

    const node = nodes.get(row.id);
    const parent = row.parent_id ? nodes.get(row.parent_id) : undefined;
    if (node && parent) {
      parent.children.push(node);
    }
  }

  const root = nodes.get(root_id);
  if (!root) {
    throw new Error(`Item not found: ${root_id}`);
  }

  return root;
}

export function searchItems(database: Database, input: SearchItemsInput): SearchItemsResult {
  const { query, filters, page = 1, limit = 20 } = searchItemsSchema.parse(input);
  const filterValues: unknown[] = [];
  const clauses = buildFilterClauses(filters, filterValues);
  clauses.push('(items.title LIKE ? ESCAPE \'\\\' OR COALESCE(items.description, \'\') LIKE ? ESCAPE \'\\\')');

  const searchPattern = `%${escapeLike(query)}%`;
  const whereClause = clauses.join(' AND ');
  const total = (database
    .prepare<unknown[], { total: number }>(
      `SELECT COUNT(*) AS total
       FROM items
       WHERE ${whereClause}`,
    )
    .get(...filterValues, searchPattern, searchPattern)?.total ?? 0) as number;

  const offset = (page - 1) * limit;
  const items = database
    .prepare<unknown[], ItemRow>(
      `SELECT items.*
       FROM items
       WHERE ${whereClause}
       ORDER BY items.title COLLATE NOCASE, items.id
       LIMIT ? OFFSET ?`,
    )
    .all(...filterValues, searchPattern, searchPattern, limit, offset)
    .map(mapItem);

  return {
    items,
    page,
    limit,
    total,
    total_pages: total === 0 ? 0 : Math.ceil(total / limit),
  };
}

export function listItems(database: Database, input: ListItemsInput = {}): Item[] {
  const filters = listItemsSchema.parse(input);
  const values: unknown[] = [];
  const clauses = buildFilterClauses(filters, values);

  return database
    .prepare<unknown[], ItemRow>(
      `SELECT items.*
       FROM items
       WHERE ${clauses.join(' AND ')}
       ORDER BY items.position, items.title COLLATE NOCASE, items.id`,
    )
    .all(...values)
    .map(mapItem);
}

export function registerQueryTools(server: McpServer, database: Database) {
  server.registerTool('get_item_tree', queryToolDefinitions.get_item_tree, async (args) => {
    const tree = getItemTree(database, args);
    return {
      content: [{ type: 'text', text: JSON.stringify(tree, null, 2) }],
      structuredContent: { tree },
    };
  });

  server.registerTool('search_items', queryToolDefinitions.search_items, async (args) => {
    const result = searchItems(database, args);
    return {
      content: [{ type: 'text', text: JSON.stringify(result, null, 2) }],
      structuredContent: {
        items: result.items,
        page: result.page,
        limit: result.limit,
        total: result.total,
        total_pages: result.total_pages,
      },
    };
  });

  server.registerTool('list_items', queryToolDefinitions.list_items, async (args) => {
    const items = listItems(database, args);
    return {
      content: [{ type: 'text', text: JSON.stringify(items, null, 2) }],
      structuredContent: { items },
    };
  });
}
