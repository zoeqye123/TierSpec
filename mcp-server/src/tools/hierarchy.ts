import { randomUUID } from 'node:crypto';

import type { Database } from '../db/client.js';
import { Complexity, ItemStatus, ItemType, isValidParentType, type Item } from '../db/types.js';
import {
  createItemSchema,
  deleteItemSchema,
  getItemSchema,
  moveItemSchema,
  reorderItemsSchema,
  updateItemSchema,
  type CreateItemInput,
  type DeleteItemInput,
  type GetItemInput,
  type MoveItemInput,
  type ReorderItemsInput,
  type UpdateItemInput,
} from '../schemas/hierarchy.js';
import type { ToolRegistrar } from '../types/tool-registrar.js';

type ItemRow = Omit<Item, 'labels' | 'ai_generated'> & {
  labels: string;
  ai_generated: number;
};

type ActiveItemRow = Pick<Item, 'id' | 'type' | 'parent_id' | 'position'>;

type ItemTree = Item & {
  children: ItemTree[];
};

type HierarchyToolsOptions = {
  database: Database;
  actorUserId: string;
};

const baseSelect = `
  SELECT
    id,
    type,
    parent_id,
    title,
    description,
    status,
    priority,
    labels,
    position,
    story_points,
    complexity,
    ai_generated,
    ai_confidence,
    ai_reasoning,
    created_at,
    updated_at,
    deleted_at,
    created_by,
    updated_by
  FROM items
`;

function toItem(row: ItemRow): Item {
  return {
    ...row,
    type: row.type as ItemType,
    status: row.status as ItemStatus,
    complexity: row.complexity as Complexity | null,
    labels: JSON.parse(row.labels) as string[],
    ai_generated: Boolean(row.ai_generated),
  };
}

function formatResult(value: unknown) {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }],
    structuredContent: value,
  };
}

function missingItemMessage(id: string) {
  return `Item not found: ${id}`;
}

export function createHierarchyTools({ database, actorUserId }: HierarchyToolsOptions) {
  const getItemRowById = database.prepare<unknown[], ItemRow>(`${baseSelect} WHERE id = ? AND deleted_at IS NULL`);
  const getAnyItemRowById = database.prepare<unknown[], ItemRow>(`${baseSelect} WHERE id = ?`);
  const getChildrenRows = database.prepare<unknown[], ItemRow>(`${baseSelect} WHERE parent_id = ? AND deleted_at IS NULL ORDER BY position ASC, created_at ASC`);
  const getRootChildrenRows = database.prepare<unknown[], ItemRow>(`${baseSelect} WHERE parent_id IS NULL AND deleted_at IS NULL ORDER BY position ASC, created_at ASC`);
  const getDescendantRows = database.prepare<unknown[], ItemRow>(`
    SELECT i.*
    FROM items i
    JOIN item_paths ip ON ip.descendant_id = i.id
    WHERE ip.ancestor_id = ?
      AND i.deleted_at IS NULL
    ORDER BY ip.depth ASC, i.position ASC, i.created_at ASC
  `);
  const getActiveItemSummary = database.prepare<unknown[], ActiveItemRow>(`
    SELECT id, type, parent_id, position
    FROM items
    WHERE id = ? AND deleted_at IS NULL
  `);
  const getMaxSiblingPosition = database.prepare<unknown[], { max_position: number | null }>(`
    SELECT MAX(position) AS max_position
    FROM items
    WHERE deleted_at IS NULL
      AND ((? IS NULL AND parent_id IS NULL) OR parent_id = ?)
  `);
  const insertItem = database.prepare(`
    INSERT INTO items (
      id,
      type,
      parent_id,
      title,
      description,
      status,
      priority,
      labels,
      position,
      ai_generated,
      created_by,
      updated_by
    ) VALUES (
      @id,
      @type,
      @parent_id,
      @title,
      @description,
      @status,
      @priority,
      @labels,
      @position,
      @ai_generated,
      @created_by,
      @updated_by
    )
  `);
  const updateParent = database.prepare(`UPDATE items SET parent_id = ?, updated_by = ? WHERE id = ? AND deleted_at IS NULL`);
  const updatePosition = database.prepare(`UPDATE items SET position = ?, updated_by = ? WHERE id = ? AND deleted_at IS NULL`);
  const updateItemFields = database.prepare(`
    UPDATE items
    SET
      title = COALESCE(@title, title),
      description = COALESCE(@description, description),
      status = COALESCE(@status, status),
      priority = COALESCE(@priority, priority),
      story_points = COALESCE(@story_points, story_points),
      complexity = COALESCE(@complexity, complexity),
      labels = COALESCE(@labels, labels),
      updated_by = @updated_by,
      updated_at = datetime('now')
    WHERE id = @id AND deleted_at IS NULL
  `);
  const softDeleteById = database.prepare(`
    UPDATE items
    SET deleted_at = datetime('now'), updated_by = ?
    WHERE id = ? AND deleted_at IS NULL
  `);
  const softDeleteSubtree = database.prepare(`
    UPDATE items
    SET deleted_at = datetime('now'), updated_by = ?
    WHERE id IN (
      SELECT descendant_id
      FROM item_paths
      WHERE ancestor_id = ?
    )
      AND deleted_at IS NULL
  `);
  const getSubtreeIds = database.prepare<unknown[], { id: string }>(`
    SELECT descendant_id AS id
    FROM item_paths
    WHERE ancestor_id = ?
    ORDER BY depth ASC
  `);
  const getActiveDescendantCount = database.prepare<unknown[], { count: number }>(`
    SELECT COUNT(*) AS count
    FROM item_paths ip
    JOIN items i ON i.id = ip.descendant_id
    WHERE ip.ancestor_id = ?
      AND ip.depth > 0
      AND i.deleted_at IS NULL
  `);
  const isDescendant = database.prepare<unknown[], { has_match: 1 }>(`
    SELECT 1 AS has_match
    FROM item_paths
    WHERE ancestor_id = ? AND descendant_id = ?
  `);

  function requireActiveItem(id: string) {
    const row = getItemRowById.get(id);
    if (!row) {
      throw new Error(missingItemMessage(id));
    }
    return toItem(row);
  }

  function requireActiveParent(id: string | null) {
    if (id === null) {
      return null;
    }

    return requireActiveItem(id);
  }

  function validateParentRelationship(childType: ItemType, parent: Item | null) {
    if (!isValidParentType(childType, parent?.type ?? null)) {
      throw new Error(`Invalid parent type for ${childType}`);
    }
  }

  function getNextPosition(parentId: string | null) {
    const row = getMaxSiblingPosition.get(parentId, parentId);
    return (row?.max_position ?? -1) + 1;
  }

  function buildTree(rootId: string): ItemTree {
    const rows = getDescendantRows.all(rootId).map(toItem);
    if (rows.length === 0) {
      throw new Error(missingItemMessage(rootId));
    }

    const nodes = new Map<string, ItemTree>();
    let root: ItemTree | undefined;

    for (const item of rows) {
      const node: ItemTree = { ...item, children: [] };
      nodes.set(item.id, node);

      if (item.id === rootId) {
        root = node;
      } else if (item.parent_id) {
        const parent = nodes.get(item.parent_id);
        parent?.children.push(node);
      }
    }

    if (!root) {
      throw new Error(missingItemMessage(rootId));
    }

    return root;
  }

  const createItemTx = database.transaction((input: CreateItemInput) => {
    const parsed = createItemSchema.parse(input);
    const parent = requireActiveParent(parsed.parent_id ?? null);
    validateParentRelationship(parsed.type, parent);

    const id = randomUUID();
    insertItem.run({
      id,
      type: parsed.type,
      parent_id: parsed.parent_id ?? null,
      title: parsed.title,
      description: parsed.description ?? null,
      status: ItemStatus.Todo,
      priority: 0,
      labels: '[]',
      position: getNextPosition(parsed.parent_id ?? null),
      ai_generated: 0,
      created_by: actorUserId,
      updated_by: actorUserId,
    });

    return requireActiveItem(id);
  });

  const moveItemTx = database.transaction((input: MoveItemInput) => {
    const parsed = moveItemSchema.parse(input);
    const item = requireActiveItem(parsed.item_id);
    const parent = requireActiveParent(parsed.new_parent_id);

    if (parsed.new_parent_id === item.id) {
      throw new Error('Cannot move an item under itself');
    }

    if (parsed.new_parent_id !== null && isDescendant.get(item.id, parsed.new_parent_id)) {
      throw new Error('Cannot move an item under one of its descendants');
    }

    validateParentRelationship(item.type, parent);
    updateParent.run(parsed.new_parent_id, actorUserId, item.id);

    return requireActiveItem(item.id);
  });

  const reorderItemsTx = database.transaction((input: ReorderItemsInput) => {
    const parsed = reorderItemsSchema.parse(input);
    const seen = new Set<string>();

    for (const entry of parsed.item_positions) {
      if (seen.has(entry.item_id)) {
        throw new Error(`Duplicate item id in reorder request: ${entry.item_id}`);
      }
      seen.add(entry.item_id);

      const item = getActiveItemSummary.get(entry.item_id);
      if (!item) {
        throw new Error(missingItemMessage(entry.item_id));
      }

      if (item.parent_id !== parsed.parent_id) {
        throw new Error(`Item ${entry.item_id} does not belong to the requested parent`);
      }

      updatePosition.run(entry.position, actorUserId, entry.item_id);
    }

    const rows = parsed.parent_id === null
      ? getRootChildrenRows.all()
      : getChildrenRows.all(parsed.parent_id);

    return rows.map(toItem).filter((item) => seen.has(item.id));
  });

  const deleteItemTx = database.transaction((input: DeleteItemInput) => {
    const parsed = deleteItemSchema.parse(input);
    const existing = getAnyItemRowById.get(parsed.item_id);
    if (!existing) {
      throw new Error(missingItemMessage(parsed.item_id));
    }

    if (parsed.cascade_children) {
      softDeleteSubtree.run(actorUserId, parsed.item_id);
      return;
    }

    const activeDescendants = getActiveDescendantCount.get(parsed.item_id)?.count ?? 0;
    if (activeDescendants > 0) {
      throw new Error('Cannot delete item without cascade while active descendants exist. Use cascade_children=true.');
    }

    softDeleteById.run(actorUserId, parsed.item_id);
  });

  const updateItemTx = database.transaction((input: UpdateItemInput) => {
    const parsed = updateItemSchema.parse(input);
    const existing = requireActiveItem(parsed.item_id);

    updateItemFields.run({
      id: parsed.item_id,
      title: parsed.title ?? null,
      description: parsed.description ?? null,
      status: parsed.status ?? null,
      priority: parsed.priority ?? null,
      story_points: parsed.story_points ?? null,
      complexity: parsed.complexity ?? null,
      labels: parsed.labels ? JSON.stringify(parsed.labels) : null,
      updated_by: actorUserId,
    });

    return requireActiveItem(parsed.item_id);
  });

  return {
    createItem(input: CreateItemInput) {
      return createItemTx(input);
    },
    getItem(input: GetItemInput) {
      const parsed = getItemSchema.parse(input);
      return buildTree(parsed.id);
    },
    moveItem(input: MoveItemInput) {
      return moveItemTx(input);
    },
    reorderItems(input: ReorderItemsInput) {
      return reorderItemsTx(input);
    },
    deleteItem(input: DeleteItemInput) {
      deleteItemTx(input);
    },
    updateItem(input: UpdateItemInput) {
      return updateItemTx(input);
    },
  };
}

export function registerHierarchyTools(server: ToolRegistrar, options: HierarchyToolsOptions) {
  const tools = createHierarchyTools(options);

  server.registerTool(
    'create_item',
    {
      title: 'Create Item',
      description: 'Create a new item in the hierarchy',
      inputSchema: createItemSchema,
    },
    async (args) => formatResult(tools.createItem(args as CreateItemInput)),
  );

  server.registerTool(
    'get_item',
    {
      title: 'Get Item',
      description: 'Fetch an item and its active child hierarchy.',
      inputSchema: getItemSchema,
      annotations: {
        title: 'Get Item',
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.getItem(args as GetItemInput)),
  );

  server.registerTool(
    'move_item',
    {
      title: 'Move Item',
      description: 'Move an item to a new parent while preserving hierarchy integrity.',
      inputSchema: moveItemSchema,
      annotations: {
        title: 'Move Item',
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.moveItem(args as MoveItemInput)),
  );

  server.registerTool(
    'reorder_items',
    {
      title: 'Reorder Items',
      description: 'Update sibling positions for items under the same parent.',
      inputSchema: reorderItemsSchema,
      annotations: {
        title: 'Reorder Items',
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.reorderItems(args as ReorderItemsInput)),
  );

  server.registerTool(
    'delete_item',
    {
      title: 'Delete Item',
      description: 'Soft delete an item, optionally cascading to descendants.',
      inputSchema: deleteItemSchema,
      annotations: {
        title: 'Delete Item',
        readOnlyHint: false,
        destructiveHint: true,
        idempotentHint: true,
        openWorldHint: false,
      },
    },
    async (args) => formatResult((tools.deleteItem(args as DeleteItemInput), { success: true })),
  );

  server.registerTool(
    'update_item',
    {
      title: 'Update Item',
      description: 'Update item fields: title, description, status, priority, story_points, complexity, labels.',
      inputSchema: updateItemSchema,
      annotations: {
        title: 'Update Item',
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.updateItem(args as UpdateItemInput)),
  );

  return tools;
}

export type { ItemTree, HierarchyToolsOptions };
