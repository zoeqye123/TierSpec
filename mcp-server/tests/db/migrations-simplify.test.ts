import { afterEach, describe, expect, it } from 'vitest';

import { Database } from '../../src/db/client.js';
import { createTestDatabase } from './test-helpers.js';

const cleanupFns: Array<() => void> = [];

afterEach(() => {
  while (cleanupFns.length > 0) {
    cleanupFns.pop()?.();
  }
});

/**
 * Creates a test database with the OLD schema (pre-migration)
 * This allows inserting items with old types (epic, business_story, technical_story)
 * and old statuses (requirement_input, requirement_review, etc.)
 */
function createOldSchemaDatabase() {
  const testDb = createTestDatabase();
  
  // Create users table
  testDb.database.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);
  
  // Create items table with OLD types and statuses (no actor_type column)
  testDb.database.exec(`
    CREATE TABLE IF NOT EXISTS items (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      parent_id TEXT REFERENCES items(id) ON DELETE RESTRICT,
      title TEXT NOT NULL,
      description TEXT,
      status TEXT NOT NULL DEFAULT 'backlog',
      previous_state TEXT,
      priority INTEGER DEFAULT 0 CHECK (priority BETWEEN 0 AND 100),
      labels TEXT DEFAULT '[]',
      blocker_item_id TEXT,
      blocker_reason TEXT,
      blocker_type TEXT,
      blocker_detected_at TEXT,
      blocker_expected_resolution TEXT,
      position REAL NOT NULL DEFAULT 0,
      story_points INTEGER CHECK (story_points IS NULL OR story_points > 0),
      complexity TEXT CHECK (complexity IN ('xs', 's', 'm', 'l', 'xl')),
      ai_generated INTEGER DEFAULT 0,
      ai_confidence REAL CHECK (ai_confidence IS NULL OR (ai_confidence >= 0 AND ai_confidence <= 1)),
      ai_reasoning TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      deleted_at TEXT,
      created_by TEXT NOT NULL REFERENCES users(id),
      updated_by TEXT REFERENCES users(id)
    );
  `);
  
  // Create audit_events table without actor_type
  testDb.database.exec(`
    CREATE TABLE IF NOT EXISTS audit_events (
      id TEXT PRIMARY KEY,
      timestamp TEXT NOT NULL DEFAULT (datetime('now')),
      actor_id TEXT NOT NULL REFERENCES users(id),
      action_type TEXT NOT NULL CHECK (action_type IN ('STATE_CHANGE', 'BLOCK', 'UNBLOCK')),
      entity_type TEXT NOT NULL CHECK (entity_type IN ('item')),
      entity_id TEXT NOT NULL,
      changes TEXT NOT NULL DEFAULT '[]',
      reason TEXT
    );
  `);
  
  // Create item_paths (closure table)
  testDb.database.exec(`
    CREATE TABLE IF NOT EXISTS item_paths (
      ancestor_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      descendant_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      depth INTEGER NOT NULL CHECK (depth >= 0),
      PRIMARY KEY (ancestor_id, descendant_id)
    );
  `);
  
  // Create item_parent_history
  testDb.database.exec(`
    CREATE TABLE IF NOT EXISTS item_parent_history (
      id TEXT PRIMARY KEY,
      item_id TEXT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
      old_parent_id TEXT REFERENCES items(id),
      new_parent_id TEXT REFERENCES items(id),
      changed_at TEXT NOT NULL DEFAULT (datetime('now')),
      changed_by TEXT NOT NULL REFERENCES users(id),
      reason TEXT
    );
  `);
  
  return testDb;
}

/**
 * Reads and executes the migration SQL file
 */
function runMigration(database: Database) {
  const fs = require('node:fs');
  const path = require('node:path');
  const migrationPath = path.join(__dirname, '../../src/db/migrations/002-simplify-hierarchy.sql');
  const migrationSql = fs.readFileSync(migrationPath, 'utf-8');
  
  // Execute the migration SQL
  database.exec(migrationSql);
}

describe('002-simplify-hierarchy migration', () => {
  describe('Type migration', () => {
    it('migrates epic to feature', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      // Insert test user
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      
      // Insert capability (root)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('cap-1', 'capability', NULL, 'Test Capability', 'user-1', 'user-1')
      `).run();
      
      // Insert epic (old type)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('epic-1', 'epic', 'cap-1', 'Test Epic', 'user-1', 'user-1')
      `).run();
      
      // Verify epic exists before migration
      const beforeMigration = testDb.database.prepare(`SELECT type FROM items WHERE id = 'epic-1'`).get() as { type: string };
      expect(beforeMigration.type).toBe('epic');
      
      // Run migration
      runMigration(testDb.database);
      
      // Verify epic migrated to feature
      const afterMigration = testDb.database.prepare(`SELECT type FROM items WHERE id = 'epic-1'`).get() as { type: string };
      expect(afterMigration.type).toBe('feature');
    });
    
    it('migrates business_story to user_story', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      // Insert test user
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      
      // Insert capability (root)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('cap-1', 'capability', NULL, 'Test Capability', 'user-1', 'user-1')
      `).run();
      
      // Insert epic (parent of business_story)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('epic-1', 'epic', 'cap-1', 'Test Epic', 'user-1', 'user-1')
      `).run();
      
      // Insert business_story (old type)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('bs-1', 'business_story', 'epic-1', 'Test Business Story', 'user-1', 'user-1')
      `).run();
      
      // Verify business_story exists before migration
      const beforeMigration = testDb.database.prepare(`SELECT type FROM items WHERE id = 'bs-1'`).get() as { type: string };
      expect(beforeMigration.type).toBe('business_story');
      
      // Run migration
      runMigration(testDb.database);
      
      // Verify business_story migrated to user_story
      const afterMigration = testDb.database.prepare(`SELECT type FROM items WHERE id = 'bs-1'`).get() as { type: string };
      expect(afterMigration.type).toBe('user_story');
    });
    
    it('migrates technical_story to user_story', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      // Insert test user
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      
      // Insert capability (root)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('cap-1', 'capability', NULL, 'Test Capability', 'user-1', 'user-1')
      `).run();
      
      // Insert epic (parent of technical_story)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('epic-1', 'epic', 'cap-1', 'Test Epic', 'user-1', 'user-1')
      `).run();
      
      // Insert technical_story (old type)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('ts-1', 'technical_story', 'epic-1', 'Test Technical Story', 'user-1', 'user-1')
      `).run();
      
      // Verify technical_story exists before migration
      const beforeMigration = testDb.database.prepare(`SELECT type FROM items WHERE id = 'ts-1'`).get() as { type: string };
      expect(beforeMigration.type).toBe('technical_story');
      
      // Run migration
      runMigration(testDb.database);
      
      // Verify technical_story migrated to user_story
      const afterMigration = testDb.database.prepare(`SELECT type FROM items WHERE id = 'ts-1'`).get() as { type: string };
      expect(afterMigration.type).toBe('user_story');
    });
    
    it('migrates hierarchy correctly (epic with children becomes feature with user_stories)', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      // Insert test user
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      
      // Insert capability (root)
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('cap-1', 'capability', NULL, 'Test Capability', 'user-1', 'user-1')
      `).run();
      
      // Insert epic with business_story and technical_story children
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('epic-1', 'epic', 'cap-1', 'Test Epic', 'user-1', 'user-1')
      `).run();
      
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('bs-1', 'business_story', 'epic-1', 'Business Story', 'user-1', 'user-1')
      `).run();
      
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('ts-1', 'technical_story', 'epic-1', 'Technical Story', 'user-1', 'user-1')
      `).run();
      
      // Run migration
      runMigration(testDb.database);
      
      // Verify all types migrated correctly
      const items = testDb.database.prepare(`
        SELECT id, type, parent_id FROM items WHERE id IN ('epic-1', 'bs-1', 'ts-1') ORDER BY id
      `).all() as Array<{ id: string; type: string; parent_id: string }>;
      
      expect(items).toHaveLength(3);
      expect(items.find(i => i.id === 'bs-1')?.type).toBe('user_story');
      expect(items.find(i => i.id === 'epic-1')?.type).toBe('feature');
      expect(items.find(i => i.id === 'ts-1')?.type).toBe('user_story');
      
      // Verify parent relationships are preserved
      expect(items.find(i => i.id === 'bs-1')?.parent_id).toBe('epic-1');
      expect(items.find(i => i.id === 'ts-1')?.parent_id).toBe('epic-1');
    });
  });
  
  describe('Status migration', () => {
    it('migrates requirement_input to todo', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'requirement_input', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('todo');
    });
    
    it('migrates requirement_review to todo', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'requirement_review', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('todo');
    });
    
    it('migrates backlog to todo', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'backlog', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('todo');
    });
    
    it('migrates ai_decomposing to todo', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'ai_decomposing', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('todo');
    });
    
    it('migrates waiting_for_test to test', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'waiting_for_test', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('test');
    });
    
    it('migrates testing to test', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'testing', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('test');
    });
    
    it('migrates acceptance to done', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'acceptance', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('done');
    });
    
    it('migrates completed to done', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'completed', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('done');
    });
    
    it('migrates published to done', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'published', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('done');
    });
    
    it('leaves in_progress unchanged', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'in_progress', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('in_progress');
    });
    
    it('leaves blocked unchanged', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'blocked', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('blocked');
    });
    
    it('leaves cancelled unchanged', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'cancelled', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('cancelled');
    });
    
    it('leaves needs_info unchanged', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, status, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'needs_info', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT status FROM items WHERE id = 'item-1'`).get() as { status: string };
      expect(result.status).toBe('needs_info');
    });
  });
  
  describe('actor_type column addition', () => {
    it('adds actor_type column to items table', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      // Verify actor_type column doesn't exist before migration
      const columnsBefore = testDb.database.pragma('table_info(items)') as Array<{ name: string }>;
      expect(columnsBefore.find(c => c.name === 'actor_type')).toBeUndefined();
      
      runMigration(testDb.database);
      
      // Verify actor_type column exists after migration
      const columnsAfter = testDb.database.pragma('table_info(items)') as Array<{ name: string }>;
      expect(columnsAfter.find(c => c.name === 'actor_type')).toBeDefined();
    });
    
    it('adds actor_type column to audit_events table', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      // Verify actor_type column doesn't exist before migration
      const columnsBefore = testDb.database.pragma('table_info(audit_events)') as Array<{ name: string }>;
      expect(columnsBefore.find(c => c.name === 'actor_type')).toBeUndefined();
      
      runMigration(testDb.database);
      
      // Verify actor_type column exists after migration
      const columnsAfter = testDb.database.pragma('table_info(audit_events)') as Array<{ name: string }>;
      expect(columnsAfter.find(c => c.name === 'actor_type')).toBeDefined();
    });
    
    it('sets default actor_type to human for existing items', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by)
        VALUES ('item-1', 'capability', NULL, 'Test Item', 'user-1', 'user-1')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT actor_type FROM items WHERE id = 'item-1'`).get() as { actor_type: string };
      expect(result.actor_type).toBe('human');
    });
    
    it('sets default actor_type to human for existing audit_events', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO audit_events (id, actor_id, action_type, entity_type, entity_id, changes)
        VALUES ('audit-1', 'user-1', 'STATE_CHANGE', 'item', 'item-1', '[]')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT actor_type FROM audit_events WHERE id = 'audit-1'`).get() as { actor_type: string };
      expect(result.actor_type).toBe('human');
    });
    
    it('actor_type column accepts valid values (human, ai, system)', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      
      runMigration(testDb.database);
      
      // Test inserting with each valid actor_type
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by, actor_type)
        VALUES ('item-1', 'capability', NULL, 'Human Item', 'user-1', 'user-1', 'human')
      `).run();
      
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by, actor_type)
        VALUES ('item-2', 'capability', NULL, 'AI Item', 'user-1', 'user-1', 'ai')
      `).run();
      
      testDb.database.prepare(`
        INSERT INTO items (id, type, parent_id, title, created_by, updated_by, actor_type)
        VALUES ('item-3', 'capability', NULL, 'System Item', 'user-1', 'user-1', 'system')
      `).run();
      
      const items = testDb.database.prepare(`
        SELECT id, actor_type FROM items WHERE id IN ('item-1', 'item-2', 'item-3') ORDER BY id
      `).all() as Array<{ id: string; actor_type: string }>;
      
      expect(items).toHaveLength(3);
      expect(items.find(i => i.id === 'item-1')?.actor_type).toBe('human');
      expect(items.find(i => i.id === 'item-2')?.actor_type).toBe('ai');
      expect(items.find(i => i.id === 'item-3')?.actor_type).toBe('system');
    });
  });
  
  describe('audit_events updates', () => {
    it('updates status values in audit_events changes JSON', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO audit_events (id, actor_id, action_type, entity_type, entity_id, changes)
        VALUES ('audit-1', 'user-1', 'STATE_CHANGE', 'item', 'item-1', '{"status":"backlog"}')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT changes FROM audit_events WHERE id = 'audit-1'`).get() as { changes: string };
      expect(result.changes).toBe('{"status":"todo"}');
    });
    
    it('updates type values in audit_events changes JSON', () => {
      const testDb = createOldSchemaDatabase();
      cleanupFns.push(() => testDb.cleanup());
      
      testDb.database.prepare(`INSERT INTO users (id, name, email) VALUES ('user-1', 'Test User', 'test@example.com')`).run();
      testDb.database.prepare(`
        INSERT INTO audit_events (id, actor_id, action_type, entity_type, entity_id, changes)
        VALUES ('audit-1', 'user-1', 'STATE_CHANGE', 'item', 'item-1', '{"type":"epic"}')
      `).run();
      
      runMigration(testDb.database);
      
      const result = testDb.database.prepare(`SELECT changes FROM audit_events WHERE id = 'audit-1'`).get() as { changes: string };
      expect(result.changes).toBe('{"type":"feature"}');
    });
  });
});
