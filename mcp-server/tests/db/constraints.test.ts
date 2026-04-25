import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ItemType } from '../../src/db/types.js';
import { createTestDatabase, insertItem, insertUser } from './test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('database constraints', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb.cleanup();
  });

  it('valid_parent_type rejects invalid parent-child combinations', () => {
    const capability = insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Capability',
    });

    expect(() =>
      insertItem(testDb.database, {
        id: 'story-1',
        type: ItemType.BusinessStory,
        parent_id: capability.id,
        title: 'Story under capability',
      }),
    ).toThrow(/valid_parent_type/i);
  });

  it('check constraints reject invalid scalar values', () => {
    expect(() => {
      testDb.database
        .prepare(
          `INSERT INTO items (id, type, parent_id, title, priority, created_by, updated_by)
           VALUES ('capability-1', 'capability', NULL, 'Broken Capability', 101, 'user-1', 'user-1')`,
        )
        .run();
    }).toThrow(/CHECK constraint failed/i);
  });
});
