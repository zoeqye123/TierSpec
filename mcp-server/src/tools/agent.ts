import { randomUUID } from 'node:crypto';

import { type Database } from '../db/client.js';
import { type Item } from '../db/types.js';
import { assertValidStateTransition, type WorkflowState } from '../state-machine.js';
import {
  processSprintItemsSchema,
  updateStorySchema,
  askClarificationSchema,
  type ProcessSprintItemsInput,
  type UpdateStoryInput,
  type AskClarificationInput,
} from '../schemas/agent.js';
import type { ToolRegistrar } from '../types/tool-registrar.js';

export type AgentToolsOptions = {
  database: Database;
  actorUserId: string;
};

function formatResult(value: unknown) {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }],
    structuredContent: value,
  };
}

type ItemRow = Omit<Item, 'labels' | 'ai_generated' | 'status'> & {
  labels: string;
  ai_generated: number;
  status: string;
  previous_state: string | null;
  blocker_reason: string | null;
  blocker_type: string | null;
  blocker_detected_at: string | null;
};

function getItemOrThrow(database: Database, itemId: string): ItemRow {
  const item = database
    .prepare<unknown[], ItemRow>('SELECT * FROM items WHERE id = ? AND deleted_at IS NULL')
    .get(itemId);
  if (!item) {
    throw new Error(`Item "${itemId}" was not found.`);
  }
  return item;
}

function toItem(row: ItemRow): Item {
  const { previous_state: _previousState, blocker_reason: _blockerReason, blocker_type: _blockerType, blocker_detected_at: _blockerDetectedAt, status, ...item } = row;

  return {
    ...item,
    status: status as Item['status'],
    labels: JSON.parse(row.labels) as string[],
    ai_generated: Boolean(row.ai_generated),
  };
}

export type SprintTodoStory = Pick<Item, 'id' | 'title' | 'status' | 'type'>;

/**
 * Return todo user stories assigned to a sprint.
 */
export function processSprintItems(database: Database, input: ProcessSprintItemsInput): SprintTodoStory[] {
  const parsed = processSprintItemsSchema.parse(input);

  return database
    .prepare<unknown[], SprintTodoStory>(
      `SELECT i.id, i.title, i.status, i.type
       FROM sprint_assignments sa
       JOIN items i ON i.id = sa.item_id
       WHERE sa.sprint_id = ?
         AND sa.removed_at IS NULL
         AND i.type = 'user_story'
         AND i.status = 'todo'
         AND i.deleted_at IS NULL
       ORDER BY i.position, i.title COLLATE NOCASE, i.id`,
    )
    .all(parsed.sprint_id);
}

/**
 * Removes [AI QUESTION] markers from description text.
 * Pattern: [AI QUESTION] ... (until newline or end of string)
 */
function clearQuestionMarkers(description: string): string {
  return description.replace(/\[AI QUESTION\][^\n]*\n?/g, '');
}

/**
 * Update a story's description and optionally clear AI question markers.
 * When clear_question is true:
 * - Removes [AI QUESTION] markers from description
 * - If status is 'blocked', changes to 'todo'
 */
export function updateStory(database: Database, input: UpdateStoryInput, actorUserId = 'system'): Item {
  const parsed = updateStorySchema.parse(input);
  const existing = getItemOrThrow(database, parsed.item_id);

  let newDescription = parsed.description ?? existing.description ?? '';
  let newStatus = existing.status;

  if (parsed.clear_question) {
    newDescription = clearQuestionMarkers(newDescription);
    if (existing.status === 'blocked') {
      newStatus = 'todo';
    }
  }

  database
    .prepare(
      `UPDATE items
       SET description = @description,
           status = @status,
           updated_at = datetime('now'),
           updated_by = @updated_by
       WHERE id = @id`,
    )
    .run({
      id: parsed.item_id,
      description: newDescription,
      status: newStatus,
      updated_by: actorUserId,
    });

  return toItem(getItemOrThrow(database, parsed.item_id));
}

export type AgentItem = Omit<Item, 'status'> & {
  status: WorkflowState;
  previous_state: WorkflowState | null;
  blocker_reason: string | null;
  blocker_type: string | null;
  blocker_detected_at: string | null;
};

type AuditActionType = 'STATE_CHANGE' | 'BLOCK' | 'UNBLOCK';

type AuditChange = {
  field: string;
  old: string | null;
  new: string | null;
};

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

export function ensureAgentSchema(database: Database) {
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

function readAgentItem(database: Database, itemId: string): AgentItem {
  const item = database
    .prepare<unknown[], ItemRow>('SELECT * FROM items WHERE id = ? AND deleted_at IS NULL')
    .get(itemId);
  if (!item) {
    throw new Error(`Item "${itemId}" was not found.`);
  }
  return {
    ...toItem(item),
    status: item.status as WorkflowState,
    previous_state: item.previous_state as WorkflowState | null,
    blocker_reason: item.blocker_reason,
    blocker_type: item.blocker_type,
    blocker_detected_at: item.blocker_detected_at,
  };
}

/**
 * Ask clarification on an item.
 * Sets status to 'blocked' and appends question to description.
 */
export function askClarification(database: Database, input: AskClarificationInput): AgentItem {
  const parsed = askClarificationSchema.parse(input);
  ensureAgentSchema(database);

  const item = getItemOrThrow(database, parsed.item_id);

  // Validate state transition to blocked
  assertValidStateTransition(item.status, 'blocked', 'ai', { previousState: item.previous_state });

  const blockedAt = new Date().toISOString();
  const previousState = item.status === 'blocked' ? item.previous_state : item.status;

  // Format the question
  const questionText = `[AI QUESTION] ${parsed.question}`;

  // Append question to description
  const currentDescription = item.description ?? '';
  const newDescription = currentDescription
    ? `${currentDescription}\n\n${questionText}`
    : questionText;

  database
    .prepare(
      `UPDATE items
       SET status = 'blocked',
           previous_state = @previous_state,
           description = @description,
           blocker_reason = @blocker_reason,
           blocker_type = @blocker_type,
           blocker_detected_at = @blocker_detected_at,
           updated_at = datetime('now'),
           updated_by = @updated_by
       WHERE id = @id`,
    )
    .run({
      id: parsed.item_id,
      previous_state: previousState,
      description: newDescription,
      blocker_reason: parsed.question,
      blocker_type: 'clarification',
      blocker_detected_at: blockedAt,
      updated_by: 'ai',
    });

  insertAuditEvent(database, {
    actorId: 'ai',
    actionType: 'BLOCK',
    entityId: parsed.item_id,
    reason: `Clarification requested: ${parsed.question}`,
    changes: [
      { field: 'status', old: item.status, new: 'blocked' },
      { field: 'description', old: currentDescription || null, new: newDescription },
    ],
  });

  return readAgentItem(database, parsed.item_id);
}

export function registerAgentTools(server: ToolRegistrar, options: AgentToolsOptions) {
  const { database, actorUserId } = options;

  server.registerTool(
    'process_sprint_items',
    {
      title: 'Process Sprint Items',
      description: 'Return todo user stories assigned to a sprint for AI processing.',
      inputSchema: processSprintItemsSchema,
      annotations: {
        title: 'Process Sprint Items',
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(processSprintItems(database, args as ProcessSprintItemsInput)),
  );

  server.registerTool(
    'ask_clarification',
    {
      title: 'Ask Clarification',
      description: 'Request clarification on an item by blocking it and appending a question.',
      inputSchema: askClarificationSchema,
      annotations: {
        title: 'Ask Clarification',
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(askClarification(database, args as AskClarificationInput)),
  );

  server.registerTool(
    'update_story',
    {
      title: 'Update Story',
      description: "Update a story's description and optionally clear AI question markers.",
      inputSchema: updateStorySchema,
      annotations: {
        title: 'Update Story',
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(updateStory(database, args as UpdateStoryInput, actorUserId)),
  );
}
