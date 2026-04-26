import { z } from 'zod';

export const createSprintSchema = z.object({
  name: z.string().trim().min(1).max(255),
  start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  end_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format'),
  capacity_points: z.number().int().min(0).optional(),
});

export const assignToSprintSchema = z.object({
  item_id: z.string().trim().min(1),
  sprint_id: z.string().trim().min(1),
});

export const getSprintStatusSchema = z.object({
  sprint_id: z.string().trim().min(1),
});

export type CreateSprintInput = z.infer<typeof createSprintSchema>;
export type AssignToSprintInput = z.infer<typeof assignToSprintSchema>;
export type GetSprintStatusInput = z.infer<typeof getSprintStatusSchema>;
