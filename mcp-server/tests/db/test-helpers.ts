import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

import { Database } from '../../src/db/client.js';
import { MigrationRunner } from '../../src/db/migrate.js';
import { ItemType } from '../../src/db/types.js';

export function createTestDatabase() {
  const directory = mkdtempSync(join(tmpdir(), 'tierspec-db-'));
  const filePath = join(directory, 'test.sqlite');
  const database = Database.getInstance(filePath);
  const migrations = new MigrationRunner(database);

  return {
    directory,
    filePath,
    database,
    migrations,
    cleanup() {
      database.close();
      rmSync(directory, { recursive: true, force: true });
    },
  };
}

export function insertUser(database: Database, overrides: Partial<{ id: string; name: string; email: string }> = {}) {
  const user = {
    id: overrides.id ?? 'user-1',
    name: overrides.name ?? 'Test User',
    email: overrides.email ?? 'test@example.com',
  };

  database
    .prepare('INSERT INTO users (id, name, email) VALUES (?, ?, ?)')
    .run(user.id, user.name, user.email);

  return user;
}

export function insertItem(
  database: Database,
  overrides: Partial<{
    id: string;
    type: ItemType;
    parent_id: string | null;
    title: string;
    created_by: string;
    updated_by: string | null;
  }> = {},
) {
  const item = {
    id: overrides.id ?? `item-${Math.random().toString(16).slice(2)}`,
    type: overrides.type ?? ItemType.Capability,
    parent_id: overrides.parent_id ?? null,
    title: overrides.title ?? 'Untitled',
    created_by: overrides.created_by ?? 'user-1',
    updated_by: overrides.updated_by ?? overrides.created_by ?? 'user-1',
  };

  database
    .prepare(
      `INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
       VALUES (@id, @type, @parent_id, @title, @created_by, @updated_by)`,
    )
    .run(item);

  return item;
}
