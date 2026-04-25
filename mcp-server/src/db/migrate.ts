import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { Database } from './client.js';

const currentDirectory = dirname(fileURLToPath(import.meta.url));
const bundledSchemaPath = resolve(currentDirectory, 'schema.sql');
const sourceSchemaPath = resolve(currentDirectory, '../../src/db/schema.sql');
const defaultSchemaPath = existsSync(bundledSchemaPath) ? bundledSchemaPath : sourceSchemaPath;

type SqliteObject = {
  name: string;
  type: 'table' | 'trigger' | 'view';
};

const DROP_TYPE_PRIORITY: Record<SqliteObject['type'], number> = {
  view: 0,
  trigger: 1,
  table: 2,
};

function quoteIdentifier(identifier: string) {
  return `"${identifier.replaceAll('"', '""')}"`;
}

export class MigrationRunner {
  private readonly schemaPath: string;

  constructor(private readonly database: Database, schemaPath = defaultSchemaPath) {
    this.schemaPath = schemaPath;
  }

  up() {
    const schema = readFileSync(this.schemaPath, 'utf8');
    this.database.exec(schema);
  }

  down() {
    const objects = this.database
      .prepare<unknown[], SqliteObject>(
        `SELECT name, type
         FROM sqlite_master
         WHERE type IN ('view', 'trigger', 'table')
           AND name NOT LIKE 'sqlite_%'`,
      )
      .all()
      .sort((left, right) => {
        const typeDifference = DROP_TYPE_PRIORITY[left.type] - DROP_TYPE_PRIORITY[right.type];
        return typeDifference !== 0 ? typeDifference : left.name.localeCompare(right.name);
      });

    if (objects.length === 0) {
      return;
    }

    const dropStatements = objects
      .map(({ name, type }) => `DROP ${type.toUpperCase()} IF EXISTS ${quoteIdentifier(name)};`)
      .join('\n');

    this.database.exec('PRAGMA foreign_keys = OFF;');
    try {
      this.database.exec(dropStatements);
    } finally {
      this.database.exec('PRAGMA foreign_keys = ON;');
    }
  }

  reset() {
    this.down();
    this.up();
  }
}
