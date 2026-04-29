import { z } from 'zod';

export const processSprintItemsSchema = z.object({
  sprint_id: z.string().trim().min(1, 'sprint_id is required'),
});

export const askClarificationSchema = z.object({
  item_id: z.string().trim().min(1, 'item_id is required'),
  question: z.string().trim().min(1, 'question is required'),
});

export const updateStorySchema = z.object({
  item_id: z.string().trim().min(1, 'item_id is required'),
  description: z.string().trim().optional(),
  clear_question: z.boolean().optional(),
});

export type ProcessSprintItemsInput = z.infer<typeof processSprintItemsSchema>;
export type AskClarificationInput = z.infer<typeof askClarificationSchema>;
export type UpdateStoryInput = z.infer<typeof updateStorySchema>;