import { randomUUID } from 'node:crypto';

import { ZodError } from 'zod';

import { type Database } from '../db/client.js';
import { type Item } from '../db/types.js';
import { assertValidStateTransition, type WorkflowState } from '../state-machine.js';
import { blockItemInputSchema, transitionStateInputSchema, type BlockItemInput, type TransitionStateInput } from '../schemas/workflow.js';

type ItemRow = Omit<Item, 'status' | 'labels'> & {
  status: string;
  labels: string;
  previous_state: string | null;
  blocker_item_id: string | null;
  blocker_reason: string | null;
  blocker_type: string | null;
  blocker_detected_at: string | null;
  blocker_expected_resolution: string | null;
};

export type WorkflowItem = Omit<Item, 'status'> & {
  status: WorkflowState;
  previous_state: WorkflowState | null;
  blocker_item_id: string | null;
  blocker_reason: string | null;
  blocker_type: string | null;
  blocker_detected_at: string | null;
  blocker_expected_resolution: string | null;
};

type AuditActionType = 'STATE_CHANGE' | 'BLOCK' | 'UNBLOCK';

type AuditChange = {
  field: string;
  old: string | null;
  new: string | null;
};

function coerceValidationError(error: unknown): never {
  if (error instanceof ZodError) {
    throw new Error(error.issues[0]?.message ?? 'Invalid workflow input.');
  }

  throw error;
}

function getItemOrThrow(database: Database, itemId: string) {
  const item = database.prepare<unknown[], ItemRow>('SELECT * FROM items WHERE id = ?').get(itemId);
  if (!item) {
    throw new Error(`Item "${itemId}" was not found.`);
  }
  return item;
}

function mapItem(row: ItemRow): WorkflowItem {
  return {
    ...row,
    labels: JSON.parse(row.labels ?? '[]') as string[],
    status: row.status as WorkflowState,
    previous_state: row.previous_state as WorkflowState | null,
  };
}

function ensureItemWorkflowColumns(database: Database) {
  const columns = new Set(
    (database.prepare('PRAGMA table_info(items)').all() as Array<{ name: string }>).map((column) => column.name),
  );

  const requiredColumns: Record<string, string> = {
    previous_state: 'TEXT',
    blocker_item_id: 'TEXT',
    blocker_reason: 'TEXT',
    blocker_type: 'TEXT',
    blocker_detected_at: 'TEXT',
    blocker_expected_resolution: 'TEXT',
  };

  for (const [column, definition] of Object.entries(requiredColumns)) {
    if (!columns.has(column)) {
      database.exec(`ALTER TABLE items ADD COLUMN ${column} ${definition};`);
    }
  }
}

function ensureAuditTrailTable(database: Database) {
  database.exec(`
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

    CREATE INDEX IF NOT EXISTS idx_audit_events_entity ON audit_events(entity_type, entity_id);
    CREATE INDEX IF NOT EXISTS idx_audit_events_timestamp ON audit_events(timestamp);
  `);
}

export function ensureWorkflowSchema(database: Database) {
  ensureItemWorkflowColumns(database);
  ensureAuditTrailTable(database);
}

function insertAuditEvent(
  database: Database,
  params: {
    actorId: string;
    actionType: AuditActionType;
    entityId: string;
    reason?: string;
    changes: AuditChange[];
  },
) {
  database
    .prepare(
      `INSERT INTO audit_events (id, actor_id, action_type, entity_type, entity_id, changes, reason)
       VALUES (@id, @actor_id, @action_type, 'item', @entity_id, @changes, @reason)`,
    )
    .run({
      id: randomUUID(),
      actor_id: params.actorId,
      action_type: params.actionType,
      entity_id: params.entityId,
      changes: JSON.stringify(params.changes),
      reason: params.reason ?? null,
    });
}

function readUpdatedItem(database: Database, itemId: string) {
  return mapItem(getItemOrThrow(database, itemId));
}

export function transitionState(database: Database, input: TransitionStateInput): WorkflowItem {
  try {
    const parsed = transitionStateInputSchema.parse(input);
    ensureWorkflowSchema(database);

    const item = getItemOrThrow(database, parsed.item_id);

    if (parsed.new_state === 'blocked') {
      throw new Error('Use block_item to move an item into blocked state so blocker metadata is captured.');
    }

    assertValidStateTransition(item.status, parsed.new_state, { previousState: item.previous_state });

    const isUnblock = item.status === 'blocked' && parsed.new_state === item.previous_state;

    database
      .prepare(
        `UPDATE items
         SET status = @status,
             previous_state = @previous_state,
             blocker_item_id = @blocker_item_id,
             blocker_reason = @blocker_reason,
             blocker_type = @blocker_type,
              blocker_detected_at = @blocker_detected_at,
             blocker_expected_resolution = @blocker_expected_resolution,
              updated_by = @updated_by
         WHERE id = @id`,
      )
      .run({
        id: parsed.item_id,
        status: parsed.new_state,
        previous_state: isUnblock ? null : item.previous_state,
        blocker_item_id: isUnblock ? null : item.blocker_item_id,
        blocker_reason: isUnblock ? null : item.blocker_reason,
        blocker_type: isUnblock ? null : item.blocker_type,
        blocker_detected_at: isUnblock ? null : item.blocker_detected_at,
        blocker_expected_resolution: isUnblock ? null : item.blocker_expected_resolution,
        updated_by: parsed.actor_id,
      });

    insertAuditEvent(database, {
      actorId: parsed.actor_id,
      actionType: isUnblock ? 'UNBLOCK' : 'STATE_CHANGE',
      entityId: parsed.item_id,
      reason: parsed.reason,
      changes: [{ field: 'status', old: item.status, new: parsed.new_state }],
    });

    return readUpdatedItem(database, parsed.item_id);
  } catch (error) {
    coerceValidationError(error);
  }
}

export function blockItem(database: Database, input: BlockItemInput): WorkflowItem {
  try {
    const parsed = blockItemInputSchema.parse(input);
    ensureWorkflowSchema(database);

    const item = getItemOrThrow(database, parsed.item_id);
    assertValidStateTransition(item.status, 'blocked', { previousState: item.previous_state });

    const blockedAt = new Date().toISOString();
    const previousState = item.status === 'blocked' ? item.previous_state : item.status;

    database
      .prepare(
        `UPDATE items
         SET status = 'blocked',
             previous_state = @previous_state,
             blocker_item_id = @blocker_item_id,
             blocker_reason = @blocker_reason,
             blocker_type = @blocker_type,
              blocker_detected_at = @blocker_detected_at,
             blocker_expected_resolution = @blocker_expected_resolution,
              updated_by = @updated_by
         WHERE id = @id`,
      )
      .run({
        id: parsed.item_id,
        previous_state: previousState,
        blocker_item_id: parsed.blocker_id,
        blocker_reason: parsed.reason,
        blocker_type: 'dependency',
        blocker_detected_at: blockedAt,
        blocker_expected_resolution: null,
        updated_by: parsed.actor_id,
      });

    insertAuditEvent(database, {
      actorId: parsed.actor_id,
      actionType: 'BLOCK',
      entityId: parsed.item_id,
      reason: parsed.reason,
      changes: [
        { field: 'status', old: item.status, new: 'blocked' },
        { field: 'blocker_item_id', old: item.blocker_item_id, new: parsed.blocker_id },
        { field: 'blocker_reason', old: item.blocker_reason, new: parsed.reason },
      ],
    });

    return readUpdatedItem(database, parsed.item_id);
  } catch (error) {
    coerceValidationError(error);
  }
}
