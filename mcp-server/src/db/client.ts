import BetterSqlite3, { type Database as SqliteDatabase, type Statement } from 'better-sqlite3';

export class Database {
  private static readonly instances = new Map<string, Database>();

  static getInstance(filename = ':memory:') {
    if (filename === ':memory:') {
      return new Database(filename, false);
    }

    const existing = this.instances.get(filename);
    if (existing) {
      existing.referenceCount += 1;
      return existing;
    }

    const database = new Database(filename, true);
    this.instances.set(filename, database);
    return database;
  }

  private readonly connection: SqliteDatabase;
  private readonly cached: boolean;
  private readonly filename: string;
  private referenceCount = 1;

  private constructor(filename: string, cached: boolean) {
    this.filename = filename;
    this.cached = cached;
    this.connection = new BetterSqlite3(filename);
    this.connection.pragma('foreign_keys = ON');
  }

  prepare<BindParameters extends unknown[] | Record<string, unknown> = unknown[], Result = unknown>(sql: string) {
    return this.connection.prepare(sql) as Statement<BindParameters, Result>;
  }

  exec(sql: string) {
    this.connection.exec(sql);
  }

  transaction<F extends (...args: never[]) => unknown>(fn: F) {
    return this.connection.transaction(fn);
  }

  pragma(statement: string) {
    return this.connection.pragma(statement);
  }

  close() {
    if (this.cached && this.referenceCount > 1) {
      this.referenceCount -= 1;
      return;
    }

    if (this.connection.open) {
      this.connection.close();
    }

    if (this.cached) {
      Database.instances.delete(this.filename);
      this.referenceCount = 0;
    }
  }
}
