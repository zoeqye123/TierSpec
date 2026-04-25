import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { createHierarchyTools } from '../../src/tools/hierarchy.js';
import { ItemType } from '../../src/db/types.js';
import { createTestDatabase, insertItem, insertUser } from '../db/test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('hierarchy CRUD tools', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb.cleanup();
  });

  it('create_item creates item with valid type', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const created = tools.createItem({
      type: ItemType.Feature,
      title: 'Feature',
      parent_id: capability.id,
      description: 'Created from tool',
    });

    expect(created.type).toBe(ItemType.Feature);
    expect(created.parent_id).toBe(capability.id);
    expect(created.description).toBe('Created from tool');
    expect(created.position).toBe(0);
  });

  it('create_item rejects invalid parent type', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    expect(() =>
      tools.createItem({
        type: ItemType.BusinessStory,
        title: 'Story',
        parent_id: capability.id,
      }),
    ).toThrow(/parent type/i);
  });

  it('get_item returns item with children', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });
    const feature = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Feature',
    });
    insertItem(testDb.database, {
      id: 'epic-1',
      type: ItemType.Epic,
      parent_id: feature.id,
      title: 'Epic',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const item = tools.getItem({ id: capability.id });

    expect(item.id).toBe(capability.id);
    expect(item.children).toHaveLength(1);
    expect(item.children[0]?.id).toBe(feature.id);
    expect(item.children[0]?.children[0]?.title).toBe('Epic');
  });

  it('move_item updates parent and closure table', () => {
    const capabilityA = insertItem(testDb.database, {
      id: 'cap-a',
      type: ItemType.Capability,
      title: 'Capability A',
    });
    const capabilityB = insertItem(testDb.database, {
      id: 'cap-b',
      type: ItemType.Capability,
      title: 'Capability B',
    });
    const feature = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capabilityA.id,
      title: 'Feature',
    });
    const epic = insertItem(testDb.database, {
      id: 'epic-1',
      type: ItemType.Epic,
      parent_id: feature.id,
      title: 'Epic',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const moved = tools.moveItem({
      item_id: feature.id,
      new_parent_id: capabilityB.id,
    });

    const featurePaths = testDb.database
      .prepare(
        `SELECT ancestor_id, descendant_id, depth
         FROM item_paths
         WHERE descendant_id = ?
         ORDER BY depth, ancestor_id`,
      )
      .all(feature.id) as Array<{ ancestor_id: string; descendant_id: string; depth: number }>;

    const epicPaths = testDb.database
      .prepare(
        `SELECT ancestor_id, descendant_id, depth
         FROM item_paths
         WHERE descendant_id = ?
         ORDER BY depth, ancestor_id`,
      )
      .all(epic.id) as Array<{ ancestor_id: string; descendant_id: string; depth: number }>;

    expect(moved.parent_id).toBe(capabilityB.id);
    expect(featurePaths).toEqual([
      { ancestor_id: feature.id, descendant_id: feature.id, depth: 0 },
      { ancestor_id: capabilityB.id, descendant_id: feature.id, depth: 1 },
    ]);
    expect(epicPaths).toEqual([
      { ancestor_id: epic.id, descendant_id: epic.id, depth: 0 },
      { ancestor_id: feature.id, descendant_id: epic.id, depth: 1 },
      { ancestor_id: capabilityB.id, descendant_id: epic.id, depth: 2 },
    ]);
  });

  it('reorder_items updates positions', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });
    const first = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'First',
    });
    const second = insertItem(testDb.database, {
      id: 'feature-2',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Second',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const reordered = tools.reorderItems({
      parent_id: capability.id,
      item_positions: [
        { item_id: second.id, position: 1 },
        { item_id: first.id, position: 2 },
      ],
    });

    const positions = testDb.database
      .prepare('SELECT id, position FROM items WHERE id IN (?, ?) ORDER BY position ASC')
      .all(first.id, second.id) as Array<{ id: string; position: number }>;

    expect(reordered.map((item) => [item.id, item.position])).toEqual([
      [second.id, 1],
      [first.id, 2],
    ]);
    expect(positions).toEqual([
      { id: second.id, position: 1 },
      { id: first.id, position: 2 },
    ]);
  });

  it('delete_item soft deletes item', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });
    const feature = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Feature',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    tools.deleteItem({ item_id: feature.id });

    const deleted = testDb.database
      .prepare('SELECT deleted_at FROM items WHERE id = ?')
      .get(feature.id) as { deleted_at: string | null };

    expect(deleted.deleted_at).toBeTruthy();
  });

  it('delete_item cascade deletes children', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });
    const feature = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Feature',
    });
    const epic = insertItem(testDb.database, {
      id: 'epic-1',
      type: ItemType.Epic,
      parent_id: feature.id,
      title: 'Epic',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    tools.deleteItem({ item_id: feature.id, cascade_children: true });

    const deletedRows = testDb.database
      .prepare('SELECT id, deleted_at FROM items WHERE id IN (?, ?) ORDER BY id')
      .all(epic.id, feature.id) as Array<{ id: string; deleted_at: string | null }>;

    expect(deletedRows).toEqual([
      { id: 'epic-1', deleted_at: expect.any(String) },
      { id: 'feature-1', deleted_at: expect.any(String) },
    ]);
  });
});
