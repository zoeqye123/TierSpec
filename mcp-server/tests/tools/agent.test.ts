import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ItemType } from '../../src/db/types.js';
import { processSprintItems } from '../../src/tools/agent.js';
import { createTestDatabase, insertItem, insertUser } from '../db/test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

describe('processSprintItems', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);

    insertItem(testDb.database, {
      id: 'cap-1',
      type: ItemType.Capability,
      title: 'Platform',
    });
    insertItem(testDb.database, {
      id: 'feature-1',
      type: ItemType.Feature,
      parent_id: 'cap-1',
      title: 'Auth',
    });

    testDb.database
      .prepare(
        `INSERT INTO sprints (id, name, start_date, end_date, capacity_points, status, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .run('sprint-1', 'Sprint 1', '2026-04-01', '2026-04-14', 20, 'planning', 'user-1');

    testDb.database
      .prepare(
        `INSERT INTO sprints (id, name, start_date, end_date, capacity_points, status, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .run('sprint-2', 'Sprint 2', '2026-04-15', '2026-04-28', 20, 'planning', 'user-1');
  });

  afterEach(() => {
    testDb?.cleanup();
  });

  it('returns todo user stories assigned to the given sprint', () => {
    insertItem(testDb.database, {
      id: 'story-todo-1',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Login flow',
    });
    insertItem(testDb.database, {
      id: 'story-todo-2',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Signup flow',
    });
    insertItem(testDb.database, {
      id: 'story-in-progress',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Profile flow',
    });

    testDb.database.prepare('UPDATE items SET status = ? WHERE id = ?').run('in_progress', 'story-in-progress');

    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by) VALUES (?, ?, ?, ?)')
      .run('sa-1', 'story-todo-1', 'sprint-1', 'user-1');
    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by) VALUES (?, ?, ?, ?)')
      .run('sa-2', 'story-todo-2', 'sprint-1', 'user-1');
    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by) VALUES (?, ?, ?, ?)')
      .run('sa-3', 'story-in-progress', 'sprint-1', 'user-1');

    const result = processSprintItems(testDb.database, { sprint_id: 'sprint-1' });

    expect(result).toEqual([
      { id: 'story-todo-1', title: 'Login flow', status: 'todo', type: 'user_story' },
      { id: 'story-todo-2', title: 'Signup flow', status: 'todo', type: 'user_story' },
    ]);
  });

  it('excludes removed/deleted assignments and non-user-story items', () => {
    insertItem(testDb.database, {
      id: 'story-active',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Active story',
    });
    insertItem(testDb.database, {
      id: 'story-removed',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Removed story',
    });
    insertItem(testDb.database, {
      id: 'story-deleted',
      type: ItemType.UserStory,
      parent_id: 'feature-1',
      title: 'Deleted story',
    });
    insertItem(testDb.database, {
      id: 'test-case-1',
      type: ItemType.TestCase,
      parent_id: 'story-active',
      title: 'Test story behavior',
    });

    testDb.database.prepare('UPDATE items SET deleted_at = datetime(\'now\') WHERE id = ?').run('story-deleted');

    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by, assigned_at) VALUES (?, ?, ?, ?, ?)')
      .run('sa-4', 'story-active', 'sprint-1', 'user-1', '2026-04-01T10:00:00');
    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by, assigned_at) VALUES (?, ?, ?, ?, ?)')
      .run('sa-5', 'story-removed', 'sprint-1', 'user-1', '2026-04-01T10:01:00');
    testDb.database
      .prepare('UPDATE sprint_assignments SET removed_at = datetime(\'now\') WHERE id = ?')
      .run('sa-5');
    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by, assigned_at) VALUES (?, ?, ?, ?, ?)')
      .run('sa-6', 'story-deleted', 'sprint-1', 'user-1', '2026-04-01T10:02:00');
    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by, assigned_at) VALUES (?, ?, ?, ?, ?)')
      .run('sa-7', 'test-case-1', 'sprint-1', 'user-1', '2026-04-01T10:03:00');
    testDb.database
      .prepare('INSERT INTO sprint_assignments (id, item_id, sprint_id, assigned_by, assigned_at) VALUES (?, ?, ?, ?, ?)')
      .run('sa-8', 'story-active', 'sprint-2', 'user-1', '2026-04-15T10:00:00');

    const result = processSprintItems(testDb.database, { sprint_id: 'sprint-1' });

    expect(result).toEqual([{ id: 'story-active', title: 'Active story', status: 'todo', type: 'user_story' }]);
  });
});
