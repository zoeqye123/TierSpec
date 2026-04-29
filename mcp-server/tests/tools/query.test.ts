import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ItemType } from '../../src/db/types.js';
import { getItemTree, listItems, queryToolDefinitions, searchItems } from '../../src/tools/query.js';
import { createTestDatabase, insertItem, insertUser } from '../db/test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('query tools', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb?.cleanup();
  });

  it('get_item_tree returns a subtree with depth metadata', () => {
    const capability = insertItem(testDb.database, { id: 'cap-1', type: ItemType.Capability, title: 'Platform' });
    const feature = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Authentication',
    });
    insertItem(testDb.database, {
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'Login flow',
    });
    insertItem(testDb.database, {
      id: 'test-1',
      type: ItemType.TestCase,
      parent_id: 'story-1',
      title: 'Test login',
    });
    insertItem(testDb.database, { id: 'cap-2', type: ItemType.Capability, title: 'Billing' });

    const tree = getItemTree(testDb.database, { root_id: feature.id });

    expect(queryToolDefinitions.get_item_tree.annotations.readOnlyHint).toBe(true);
    expect(tree).toMatchObject({
      id: 'feature-1',
      depth: 0,
      children: [
        {
          id: 'story-1',
          depth: 1,
          children: [{ id: 'test-1', depth: 2, children: [] }],
        },
      ],
    });
  });

  it('get_item_tree respects max_depth', () => {
    const capability = insertItem(testDb.database, { id: 'cap-1', type: ItemType.Capability, title: 'Platform' });
    const feature = insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Authentication',
    });
    insertItem(testDb.database, {
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: feature.id,
      title: 'Login flow',
    });
    insertItem(testDb.database, {
      id: 'test-1',
      type: ItemType.TestCase,
      parent_id: 'story-1',
      title: 'Test login',
    });

    const tree = getItemTree(testDb.database, { root_id: feature.id, max_depth: 1 });

    expect(tree.children).toHaveLength(1);
    expect(tree.children[0]).toMatchObject({ id: 'story-1', depth: 1, children: [] });
  });

  it('search_items supports full-text matches across title and description', () => {
    insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Authentication',
    });
    testDb.database
      .prepare('UPDATE items SET description = ?, updated_by = ? WHERE id = ?')
      .run('Single sign-on support', 'user-1', 'cap-1');

    insertItem(testDb.database, {
      id: 'cap-2',
      type: ItemType.Capability,
      title: 'Billing',
    });
    testDb.database
      .prepare('UPDATE items SET description = ?, updated_by = ? WHERE id = ?')
      .run('Invoice workflows', 'user-1', 'cap-2');

    const titleMatch = searchItems(testDb.database, { query: 'auth' });
    const descriptionMatch = searchItems(testDb.database, { query: 'sign-on' });

    expect(queryToolDefinitions.search_items.annotations.readOnlyHint).toBe(true);
    expect(titleMatch.items.map((item) => item.id)).toEqual(['cap-1']);
    expect(descriptionMatch.items.map((item) => item.id)).toEqual(['cap-1']);
  });

  it('search_items paginates results and returns totals', () => {
    for (let index = 1; index <= 5; index += 1) {
      insertItem(testDb.database, {
        id: `cap-${index}`,
        type: ItemType.Capability,
        title: `Login item ${index}`,
      });
    }

    const result = searchItems(testDb.database, { query: 'login', page: 2, limit: 2 });

    expect(result).toMatchObject({
      page: 2,
      limit: 2,
      total: 5,
      total_pages: 3,
    });
    expect(result.items.map((item) => item.id)).toEqual(['cap-3', 'cap-4']);
  });

  it('list_items filters by type', () => {
    const capability = insertItem(testDb.database, { id: 'cap-1', type: ItemType.Capability, title: 'Platform' });
    insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Authentication',
    });
    insertItem(testDb.database, {
      id: 'feature-2',
      type: ItemType.Feature,
      parent_id: capability.id,
      title: 'Billing',
    });
    insertItem(testDb.database, {
      id: 'story-1',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Login flow',
    });

    const items = listItems(testDb.database, { type: ItemType.Feature });

    expect(queryToolDefinitions.list_items.annotations.readOnlyHint).toBe(true);
    expect(items.map((item) => item.id)).toEqual(['feature-1', 'feature-2']);
  });

  it('list_items filters by status', () => {
    insertItem(testDb.database, { id: 'cap-1', type: ItemType.Capability, title: 'Platform' });
    insertItem(testDb.database, { id: 'cap-2', type: ItemType.Capability, title: 'Billing' });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('completed', 'user-1', 'cap-2');

    const items = listItems(testDb.database, { status: 'completed' });

    expect(items.map((item) => item.id)).toEqual(['cap-2']);
  });

  it('search_items accepts documented workflow statuses in filters', () => {
    insertItem(testDb.database, { id: 'cap-1', type: ItemType.Capability, title: 'Platform' });
    insertItem(testDb.database, { id: 'cap-2', type: ItemType.Capability, title: 'Billing' });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('waiting_for_test', 'user-1', 'cap-2');

    const result = searchItems(testDb.database, {
      query: 'billing',
      filters: { status: 'waiting_for_test' },
    });

    expect(result.items.map((item) => item.id)).toEqual(['cap-2']);
  });
});
