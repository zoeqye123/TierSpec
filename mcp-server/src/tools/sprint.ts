import { randomUUID } from 'node:crypto';

import type { Database } from '../db/client.js';
import { SprintStatus, type Sprint, type SprintAssignment } from '../db/types.js';
import {
  createSprintSchema,
  assignToSprintSchema,
  getSprintStatusSchema,
  type CreateSprintInput,
  type AssignToSprintInput,
  type GetSprintStatusInput,
} from '../schemas/sprint.js';
import type { ToolRegistrar } from '../types/tool-registrar.js';

type SprintToolsOptions = {
  database: Database;
  actorUserId: string;
};

function formatResult(value: unknown) {
  return {
    content: [{ type: 'text' as const, text: JSON.stringify(value, null, 2) }],
    structuredContent: value,
  };
}

export function createSprintTools({ database, actorUserId }: SprintToolsOptions) {
  const insertSprint = database.prepare(`
    INSERT INTO sprints (
      id, name, start_date, end_date, capacity_points, status, created_by
    ) VALUES (
      @id, @name, @start_date, @end_date, @capacity_points, @status, @created_by
    )
  `);

  const getSprintById = database.prepare<unknown[], Sprint>(`
    SELECT * FROM sprints WHERE id = ?
  `);

  const getAllSprints = database.prepare<unknown[], Sprint>(`
    SELECT * FROM sprints ORDER BY start_date DESC
  `);

  const getActiveSprints = database.prepare<unknown[], Sprint>(`
    SELECT * FROM sprints WHERE status = 'active' ORDER BY start_date
  `);

  const updateSprintStatus = database.prepare(`
    UPDATE sprints SET status = ?, updated_at = datetime('now') WHERE id = ?
  `);

  const insertSprintAssignment = database.prepare(`
    INSERT INTO sprint_assignments (
      id, item_id, sprint_id, assigned_by
    ) VALUES (@id, @item_id, @sprint_id, @assigned_by)
  `);

  const removeSprintAssignment = database.prepare(`
    UPDATE sprint_assignments 
    SET removed_at = datetime('now'), removed_by = @removed_by, removal_reason = @reason
    WHERE item_id = @item_id AND removed_at IS NULL
  `);

  const getSprintAssignments = database.prepare<unknown[], SprintAssignment>(`
    SELECT * FROM sprint_assignments WHERE sprint_id = ? AND removed_at IS NULL
  `);

  const getItemCurrentSprint = database.prepare<unknown[], { sprint_id: string; sprint_name: string }>(`
    SELECT sa.sprint_id, s.name as sprint_name
    FROM sprint_assignments sa
    JOIN sprints s ON s.id = sa.sprint_id
    WHERE sa.item_id = ? AND sa.removed_at IS NULL
    LIMIT 1
  `);

  const getSprintItems = database.prepare(`
    SELECT i.id, i.title, i.type, i.status, i.story_points
    FROM sprint_assignments sa
    JOIN items i ON i.id = sa.item_id
    WHERE sa.sprint_id = ? AND sa.removed_at IS NULL AND i.deleted_at IS NULL
    ORDER BY i.position
  `);

  const updateSprintPoints = database.prepare(`
    UPDATE sprints 
    SET committed_points = (
      SELECT COALESCE(SUM(i.story_points), 0)
      FROM sprint_assignments sa
      JOIN items i ON i.id = sa.item_id
      WHERE sa.sprint_id = ? AND sa.removed_at IS NULL AND i.deleted_at IS NULL
    ),
    completed_points = (
      SELECT COALESCE(SUM(i.story_points), 0)
      FROM sprint_assignments sa
      JOIN items i ON i.id = sa.item_id
      WHERE sa.sprint_id = ? AND sa.removed_at IS NULL AND i.deleted_at IS NULL AND i.status = 'completed'
    ),
    updated_at = datetime('now')
    WHERE id = ?
  `);

  const createSprintTx = database.transaction((input: CreateSprintInput) => {
    const parsed = createSprintSchema.parse(input);
    const id = randomUUID();
    
    insertSprint.run({
      id,
      name: parsed.name,
      start_date: parsed.start_date,
      end_date: parsed.end_date,
      capacity_points: parsed.capacity_points ?? 0,
      status: SprintStatus.Planning,
      created_by: actorUserId,
    });

    return getSprintById.get(id);
  });

  const assignToSprintTx = database.transaction((input: AssignToSprintInput) => {
    const parsed = assignToSprintSchema.parse(input);
    
    removeSprintAssignment.run({
      item_id: parsed.item_id,
      removed_by: actorUserId,
      reason: 'Reassigned to different sprint',
    });

    const assignmentId = randomUUID();
    insertSprintAssignment.run({
      id: assignmentId,
      item_id: parsed.item_id,
      sprint_id: parsed.sprint_id,
      assigned_by: actorUserId,
    });

    updateSprintPoints.run(parsed.sprint_id, parsed.sprint_id, parsed.sprint_id);

    return getSprintById.get(parsed.sprint_id);
  });

  const getSprintStatusTx = (input: GetSprintStatusInput) => {
    const parsed = getSprintStatusSchema.parse(input);
    const sprint = getSprintById.get(parsed.sprint_id);
    
    if (!sprint) {
      throw new Error(`Sprint not found: ${parsed.sprint_id}`);
    }

    const items = getSprintItems.all(parsed.sprint_id);
    
    return {
      sprint,
      items,
      progress: {
        total_items: items.length,
        total_points: sprint.committed_points,
        completed_points: sprint.completed_points,
        capacity_used_percent: sprint.capacity_points > 0 
          ? Math.round((sprint.committed_points / sprint.capacity_points) * 100) 
          : 0,
      },
    };
  };

  return {
    createSprint(input: CreateSprintInput) {
      return createSprintTx(input);
    },
    assignToSprint(input: AssignToSprintInput) {
      return assignToSprintTx(input);
    },
    getSprintStatus(input: GetSprintStatusInput) {
      return getSprintStatusTx(input);
    },
    listSprints() {
      return getAllSprints.all();
    },
    listActiveSprints() {
      return getActiveSprints.all();
    },
    startSprint(sprintId: string) {
      updateSprintStatus.run(SprintStatus.Active, sprintId);
      return getSprintById.get(sprintId);
    },
    completeSprint(sprintId: string) {
      updateSprintStatus.run(SprintStatus.Completed, sprintId);
      return getSprintById.get(sprintId);
    },
  };
}

export function registerSprintTools(server: ToolRegistrar, options: SprintToolsOptions) {
  const tools = createSprintTools(options);

  server.registerTool(
    'create_sprint',
    {
      title: 'Create Sprint',
      description: 'Create a new sprint with name, dates, and capacity.',
      inputSchema: createSprintSchema,
      annotations: {
        title: 'Create Sprint',
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.createSprint(args as CreateSprintInput)),
  );

  server.registerTool(
    'assign_to_sprint',
    {
      title: 'Assign to Sprint',
      description: 'Assign an item to a sprint.',
      inputSchema: assignToSprintSchema,
      annotations: {
        title: 'Assign to Sprint',
        readOnlyHint: false,
        destructiveHint: false,
        idempotentHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.assignToSprint(args as AssignToSprintInput)),
  );

  server.registerTool(
    'get_sprint_status',
    {
      title: 'Get Sprint Status',
      description: 'Get sprint progress with assigned items.',
      inputSchema: getSprintStatusSchema,
      annotations: {
        title: 'Get Sprint Status',
        readOnlyHint: true,
        destructiveHint: false,
        openWorldHint: false,
      },
    },
    async (args) => formatResult(tools.getSprintStatus(args as GetSprintStatusInput)),
  );

  return tools;
}

export type { SprintToolsOptions };
