import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ItemType } from '../../src/db/types.js';
import { createTestDatabase, insertItem, insertUser } from './test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('closure table maintenance', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb?.cleanup();
  });

  it('closure trigger fires on insert', () => {
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

    const paths = testDb.database
      .prepare(
        `SELECT ancestor_id, descendant_id, depth
         FROM item_paths
         WHERE descendant_id = ?
         ORDER BY depth, ancestor_id`,
      )
      .all(feature.id) as Array<{ ancestor_id: string; descendant_id: string; depth: number }>;

    expect(paths).toEqual([
      { ancestor_id: feature.id, descendant_id: feature.id, depth: 0 },
      { ancestor_id: capability.id, descendant_id: feature.id, depth: 1 },
    ]);
  });

  it('circular reference detection aborts reparenting', () => {
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

    expect(() => {
      testDb.database
        .prepare('UPDATE items SET parent_id = ?, updated_by = ? WHERE id = ?')
        .run(userStory.id, 'user-1', capability.id);
    }).toThrow(/circular reference/i);
  });

  it('reparenting updates closure table', () => {
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

    testDb.database
      .prepare('UPDATE items SET parent_id = ?, updated_by = ? WHERE id = ?')
      .run(capabilityB.id, 'user-1', feature.id);

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
});
