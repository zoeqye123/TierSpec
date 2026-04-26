import { afterEach, describe, expect, it } from 'vitest';

import { Database } from '../../src/db/client.js';
import { createTestDatabase } from './test-helpers.js';

const cleanupFns: Array<() => void> = [];

afterEach(() => {
  while (cleanupFns.length > 0) {
    cleanupFns.pop()?.();
  }
});

describe('MigrationRunner', () => {
  it('migration up creates all tables', () => {
    const testDb = createTestDatabase();
    cleanupFns.push(() => testDb.cleanup());

    testDb.migrations.up();

    const tables = testDb.database
      .prepare(
        `SELECT name
         FROM sqlite_master
         WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
         ORDER BY name`,
      )
      .all() as Array<{ name: string }>;

    expect(tables.map((table) => table.name)).toEqual([
      'audit_events',
      'item_parent_history',
      'item_paths',
      'items',
      'sprint_assignments',
      'sprints',
      'users',
    ]);
  });

  it('migration down drops all tables', () => {
    const testDb = createTestDatabase();
    cleanupFns.push(() => testDb.cleanup());

    testDb.migrations.up();
    testDb.migrations.down();

    const tables = testDb.database
      .prepare(
        `SELECT name
         FROM sqlite_master
         WHERE type = 'table' AND name NOT LIKE 'sqlite_%'`,
      )
      .all();

    expect(tables).toEqual([]);
  });

  it('reset rebuilds schema from a populated database', () => {
    const testDb = createTestDatabase();
    cleanupFns.push(() => testDb.cleanup());

    testDb.migrations.up();
    testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
    testDb.migrations.reset();
    testDb.migrations.reset();

    const tables = testDb.database
      .prepare(
        `SELECT name
         FROM sqlite_master
         WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
         ORDER BY name`,
      )
      .all() as Array<{ name: string }>;

    const users = testDb.database.prepare('SELECT COUNT(*) AS count FROM users').get() as { count: number };

    expect(tables.map((table) => table.name)).toEqual([
      'audit_events',
      'item_parent_history',
      'item_paths',
      'items',
      'sprint_assignments',
      'sprints',
      'users',
    ]);
    expect(users.count).toBe(0);
  });

  it('reset works after inserting related rows with foreign keys', () => {
    const testDb = createTestDatabase();
    cleanupFns.push(() => testDb.cleanup());

    testDb.migrations.up();
    testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
    testDb.database
      .prepare(
        `INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
         VALUES ('cap-1', 'capability', NULL, 'Capability', 'user-1', 'user-1')`,
      )
      .run();

    expect(() => testDb.migrations.reset()).not.toThrow();

    const tables = testDb.database
      .prepare(
        `SELECT name
         FROM sqlite_master
         WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
         ORDER BY name`,
      )
      .all() as Array<{ name: string }>;

    expect(tables.map((table) => table.name)).toEqual([
      'audit_events',
      'item_parent_history',
      'item_paths',
      'items',
      'sprint_assignments',
      'sprints',
      'users',
    ]);
  });

  it('migration up includes workflow columns on items', () => {
    const testDb = createTestDatabase();
    cleanupFns.push(() => testDb.cleanup());

    testDb.migrations.up();

    const columns = testDb.database
      .prepare('PRAGMA table_info(items)')
      .all() as Array<{ name: string }>;

    expect(columns.map((column) => column.name)).toEqual(
      expect.arrayContaining([
        'previous_state',
        'blocker_item_id',
        'blocker_reason',
        'blocker_type',
        'blocker_detected_at',
        'blocker_expected_resolution',
      ]),
    );
  });

  it('returns isolated in-memory connections and reuses file-backed ones safely', () => {
    const memoryDatabaseA = Database.getInstance();
    const memoryDatabaseB = Database.getInstance();
    cleanupFns.push(() => memoryDatabaseA.close());
    cleanupFns.push(() => memoryDatabaseB.close());

    memoryDatabaseA.exec('CREATE TABLE sample (id INTEGER PRIMARY KEY);');

    expect(() => memoryDatabaseB.prepare('SELECT * FROM sample').all()).toThrow();

    const testDb = createTestDatabase();
    cleanupFns.push(() => testDb.cleanup());

    const sharedA = Database.getInstance(testDb.filePath);
    const sharedB = Database.getInstance(testDb.filePath);
    cleanupFns.push(() => sharedA.close());
    cleanupFns.push(() => sharedB.close());

    sharedA.exec('CREATE TABLE shared_sample (id INTEGER PRIMARY KEY);');
    sharedA.close();

    expect(sharedB.prepare('SELECT * FROM shared_sample').all()).toEqual([]);
  });
});
