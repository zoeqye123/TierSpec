import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { type Database } from '../../src/db/client.js';
import { ItemType } from '../../src/db/types.js';
import { blockItem, transitionState } from '../../src/tools/workflow.js';
import { createTestDatabase, insertItem, insertUser } from '../db/test-helpers.js';

let testDb: ReturnType<typeof createTestDatabase>;

function getItem(database: Database, id: string) {
  return database.prepare('SELECT * FROM items WHERE id = ?').get(id) as Record<string, unknown>;
}

describe('workflow tools', () => {
  beforeEach(() => {
    testDb = createTestDatabase();
    testDb.migrations.up();
    insertUser(testDb.database);
  });

  afterEach(() => {
    testDb?.cleanup();
  });

  it('transition_state logs state changes to the audit trail', () => {
    const item = insertItem(testDb.database, {
      id: 'item-review',
      type: ItemType.Capability,
      title: 'Review Ready Capability',
    });

    // Start from todo, transition to in_progress
    const updated = transitionState(testDb.database, {
      item_id: item.id,
      new_state: 'in_progress',
      reason: 'Starting work',
      actor_id: 'user-1',
    });

    const auditEvent = testDb.database
      .prepare(
        `SELECT action_type, entity_type, entity_id, reason, changes
         FROM audit_events
         WHERE entity_id = ?`,
      )
      .get(item.id) as { action_type: string; entity_type: string; entity_id: string; reason: string | null; changes: string };

    expect(updated.status).toBe('in_progress');
    expect(auditEvent).toMatchObject({
      action_type: 'STATE_CHANGE',
      entity_type: 'item',
      entity_id: item.id,
      reason: 'Starting work',
    });
    expect(JSON.parse(auditEvent.changes)).toEqual([{ field: 'status', old: 'todo', new: 'in_progress' }]);
  });

  it('block_item sets the item status to blocked and stores blocker metadata', () => {
    const item = insertItem(testDb.database, {
      id: 'item-blocked',
      type: ItemType.Capability,
      title: 'Blocked capability',
    });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('in_progress', 'user-1', item.id);

    const blocked = blockItem(testDb.database, {
      item_id: item.id,
      blocker_id: 'dep-123',
      reason: 'Waiting on upstream dependency',
      actor_id: 'user-1',
    });

    const persisted = getItem(testDb.database, item.id);

    expect(blocked.status).toBe('blocked');
    expect(blocked.previous_state).toBe('in_progress');
    expect(blocked.blocker_item_id).toBe('dep-123');
    expect(blocked.blocker_reason).toBe('Waiting on upstream dependency');
    expect(persisted.status).toBe('blocked');
    expect(persisted.previous_state).toBe('in_progress');
    expect(persisted.blocker_item_id).toBe('dep-123');
    expect(persisted.blocker_reason).toBe('Waiting on upstream dependency');
    expect(persisted.blocker_detected_at).toEqual(expect.any(String));
  });

  it('block_item requires blocker_id and reason', () => {
    const item = insertItem(testDb.database, {
      id: 'item-invalid-block',
      type: ItemType.Capability,
      title: 'Invalid blocked capability',
    });

    expect(() =>
      blockItem(testDb.database, {
        item_id: item.id,
        blocker_id: '',
        reason: 'Waiting on answer',
        actor_id: 'user-1',
      }),
    ).toThrow(/blocker_id is required/i);

    expect(() =>
      blockItem(testDb.database, {
        item_id: item.id,
        blocker_id: 'dep-123',
        reason: '   ',
        actor_id: 'user-1',
      }),
    ).toThrow(/reason is required/i);
  });

  it('transition_state allows the documented forward and recovery transitions', () => {
    const item = insertItem(testDb.database, {
      id: 'item-flow',
      type: ItemType.Capability,
      title: 'Workflow item',
    });

    // todo -> in_progress
    expect(
      transitionState(testDb.database, {
        item_id: item.id,
        new_state: 'in_progress',
        actor_id: 'user-1',
      }).status,
    ).toBe('in_progress');

    // in_progress -> test
    expect(
      transitionState(testDb.database, {
        item_id: item.id,
        new_state: 'test',
        actor_id: 'user-1',
      }).status,
    ).toBe('test');

    // test -> done (human only)
    expect(
      transitionState(testDb.database, {
        item_id: item.id,
        new_state: 'done',
        actor_id: 'user-1',
        actor_type: 'human',
      }).status,
    ).toBe('done');
  });

  it('transition_state allows cancelling from any workflow state', () => {
    const item = insertItem(testDb.database, {
      id: 'item-cancel',
      type: ItemType.Capability,
      title: 'Cancelable item',
    });

    // Set to in_progress first
    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('in_progress', 'user-1', item.id);

    const updated = transitionState(testDb.database, {
      item_id: item.id,
      new_state: 'cancelled',
      actor_id: 'user-1',
    });

    expect(updated.status).toBe('cancelled');
  });

  it('unblocking clears all blocker metadata', () => {
    const item = insertItem(testDb.database, {
      id: 'item-unblock',
      type: ItemType.Capability,
      title: 'Unblock item',
    });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('in_progress', 'user-1', item.id);

    blockItem(testDb.database, {
      item_id: item.id,
      blocker_id: 'dep-123',
      reason: 'Waiting on dependency',
      actor_id: 'user-1',
    });

    const unblocked = transitionState(testDb.database, {
      item_id: item.id,
      new_state: 'in_progress',
      actor_id: 'user-1',
    });

    expect(unblocked.status).toBe('in_progress');
    expect(unblocked.previous_state).toBeNull();
    expect(unblocked.blocker_item_id).toBeNull();
    expect(unblocked.blocker_reason).toBeNull();
    expect(unblocked.blocker_type).toBeNull();
    expect(unblocked.blocker_detected_at).toBeNull();
    expect(unblocked.blocker_expected_resolution).toBeNull();
  });

  it('transition_state rejects AI actor transitioning to done', () => {
    const item = insertItem(testDb.database, {
      id: 'item-ai-done',
      type: ItemType.Capability,
      title: 'AI cannot mark done',
    });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('test', 'user-1', item.id);

    expect(() =>
      transitionState(testDb.database, {
        item_id: item.id,
        new_state: 'done',
        actor_id: 'ai-agent-1',
        actor_type: 'ai',
      }),
    ).toThrow(/Only human actors can transition to "done"/);
  });

  it('transition_state allows human actor to transition to done', () => {
    const item = insertItem(testDb.database, {
      id: 'item-human-done',
      type: ItemType.Capability,
      title: 'Human can mark done',
    });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('test', 'user-1', item.id);

    const updated = transitionState(testDb.database, {
      item_id: item.id,
      new_state: 'done',
      actor_id: 'user-1',
      actor_type: 'human',
    });

    expect(updated.status).toBe('done');
  });

  it('transition_state defaults actor_type to human', () => {
    const item = insertItem(testDb.database, {
      id: 'item-default-actor',
      type: ItemType.Capability,
      title: 'Default actor type',
    });

    testDb.database.prepare('UPDATE items SET status = ?, updated_by = ? WHERE id = ?').run('test', 'user-1', item.id);

    // Without actor_type, should default to 'human' and succeed
    const updated = transitionState(testDb.database, {
      item_id: item.id,
      new_state: 'done',
      actor_id: 'user-1',
    });

    expect(updated.status).toBe('done');
  });
});
