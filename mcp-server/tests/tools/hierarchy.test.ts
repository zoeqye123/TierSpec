import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { createHierarchyTools } from '../../src/tools/hierarchy.js';
import { Complexity, ItemType, ItemStatus } from '../../src/db/types.js';
import { createTestDatabase, insertItem, insertUser } from '../db/test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('hierarchy CRUD tools', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb?.cleanup();
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
        type: ItemType.UserStory,
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
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'User Story',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const item = tools.getItem({ id: capability.id });

    expect(item.id).toBe(capability.id);
    expect(item.children).toHaveLength(1);
    expect(item.children[0]?.id).toBe(feature.id);
    expect(item.children[0]?.children[0]?.title).toBe('User Story');
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
    const userStory = insertItem(testDb.database, {
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'User Story',
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

    const userStoryPaths = testDb.database
      .prepare(
        `SELECT ancestor_id, descendant_id, depth
         FROM item_paths
         WHERE descendant_id = ?
         ORDER BY depth, ancestor_id`,
      )
      .all(userStory.id) as Array<{ ancestor_id: string; descendant_id: string; depth: number }>;

    expect(moved.parent_id).toBe(capabilityB.id);
    expect(featurePaths).toEqual([
      { ancestor_id: feature.id, descendant_id: feature.id, depth: 0 },
      { ancestor_id: capabilityB.id, descendant_id: feature.id, depth: 1 },
    ]);
    expect(userStoryPaths).toEqual([
      { ancestor_id: userStory.id, descendant_id: userStory.id, depth: 0 },
      { ancestor_id: feature.id, descendant_id: userStory.id, depth: 1 },
      { ancestor_id: capabilityB.id, descendant_id: userStory.id, depth: 2 },
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

  it('delete_item without cascade rejects items that still have active descendants', () => {
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
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'User Story',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    expect(() => tools.deleteItem({ item_id: feature.id })).toThrow(/cascade_children=true/i);

    const tree = tools.getItem({ id: capability.id });
    expect(tree.children.map((item) => item.id)).toEqual([feature.id]);
    expect(tree.children[0]?.children.map((item) => item.id)).toEqual(['story-1']);
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
    const userStory = insertItem(testDb.database, {
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'User Story',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    tools.deleteItem({ item_id: feature.id, cascade_children: true });

    const deletedRows = testDb.database
      .prepare('SELECT id, deleted_at FROM items WHERE id IN (?, ?) ORDER BY id')
      .all(userStory.id, feature.id) as Array<{ id: string; deleted_at: string | null }>;

    expect(deletedRows).toEqual([
      { id: 'feature-1', deleted_at: expect.any(String) },
      { id: 'story-1', deleted_at: expect.any(String) },
    ]);
  });

  it('update_item updates title and description', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Original Title',
      description: 'Original description',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const updated = tools.updateItem({
      item_id: capability.id,
      title: 'Updated Title',
      description: 'Updated description',
    });

    expect(updated.title).toBe('Updated Title');
    expect(updated.description).toBe('Updated description');
  });

  it('update_item updates status and priority', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
      status: ItemStatus.Todo,
      priority: 0,
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const updated = tools.updateItem({
      item_id: capability.id,
      status: ItemStatus.InProgress,
      priority: 50,
    });

    expect(updated.status).toBe(ItemStatus.InProgress);
    expect(updated.priority).toBe(50);
  });

  it('update_item updates story_points and complexity', () => {
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
    const userStory = insertItem(testDb.database, {
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'User Story',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const updated = tools.updateItem({
      item_id: userStory.id,
      story_points: 13,
      complexity: Complexity.L,
    });

    expect(updated.story_points).toBe(13);
    expect(updated.complexity).toBe(Complexity.L);
  });

  it('update_item updates labels', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const updated = tools.updateItem({
      item_id: capability.id,
      labels: ['backend', 'api', 'priority'],
    });

    expect(updated.labels).toEqual(['backend', 'api', 'priority']);
  });

  it('update_item can clear nullable fields', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
      description: 'Has description',
      story_points: 5,
    });

    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    const updated = tools.updateItem({
      item_id: capability.id,
      description: null,
      story_points: null,
    });

    expect(updated.description).toBeNull();
    expect(updated.story_points).toBeNull();
  });

  it('update_item throws for non-existent item', () => {
    const tools = createHierarchyTools({
      database: testDb.database,
      actorUserId: 'user-1',
    });

    expect(() =>
      tools.updateItem({
        item_id: 'non-existent',
        title: 'New Title',
      }),
    ).toThrow(/not found/i);
  });
});
