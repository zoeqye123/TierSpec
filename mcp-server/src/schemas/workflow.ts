import { z } from 'zod';

import { WORKFLOW_STATES } from '../state-machine.js';

export const workflowStateSchema = z.enum(WORKFLOW_STATES);

export const transitionStateInputSchema = z.object({
  item_id: z.string().trim().min(1, 'item_id is required'),
  new_state: workflowStateSchema,
  reason: z.string().trim().optional(),
  actor_id: z.string().trim().min(1, 'actor_id is required').default('system'),
  actor_type: z.enum(['human', 'ai', 'system']).default('human'),
});

export const blockItemInputSchema = z.object({
  item_id: z.string().trim().min(1, 'item_id is required'),
  blocker_id: z.string().trim().min(1, 'blocker_id is required'),
  reason: z.string().trim().min(1, 'reason is required'),
  actor_id: z.string().trim().min(1, 'actor_id is required').default('system'),
});

export type TransitionStateInput = z.infer<typeof transitionStateInputSchema>;
export type BlockItemInput = z.infer<typeof blockItemInputSchema>;
