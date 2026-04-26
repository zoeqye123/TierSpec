import { z } from 'zod';

import { Complexity, ItemType, ItemStatus } from '../db/types.js';

const itemTypeValues = Object.values(ItemType) as [ItemType, ...ItemType[]];
const complexityValues = Object.values(Complexity) as [Complexity, ...Complexity[]];
const statusValues = Object.values(ItemStatus) as [ItemStatus, ...ItemStatus[]];

export const createItemSchema = z.object({
  type: z.enum(itemTypeValues),
  title: z.string().trim().min(1).max(255),
  parent_id: z.string().trim().min(1).optional(),
  description: z.string().trim().min(1).max(10_000).optional(),
});

export const getItemSchema = z.object({
  id: z.string().trim().min(1),
});

export const moveItemSchema = z.object({
  item_id: z.string().trim().min(1),
  new_parent_id: z.string().trim().min(1).nullable(),
});

export const reorderItemPositionSchema = z.object({
  item_id: z.string().trim().min(1),
  position: z.number().finite(),
});

export const reorderItemsSchema = z.object({
  parent_id: z.string().trim().min(1).nullable(),
  item_positions: z.array(reorderItemPositionSchema).min(1),
});

export const deleteItemSchema = z.object({
  item_id: z.string().trim().min(1),
  cascade_children: z.boolean().optional().default(false),
});

export const updateItemSchema = z.object({
  item_id: z.string().trim().min(1),
  title: z.string().trim().min(1).max(255).optional(),
  description: z.string().trim().max(10_000).nullable().optional(),
  status: z.enum(statusValues).optional(),
  priority: z.number().int().min(0).max(100).optional(),
  story_points: z.number().int().positive().nullable().optional(),
  complexity: z.enum(complexityValues).nullable().optional(),
  labels: z.array(z.string().trim().min(1).max(50)).optional(),
});

export type CreateItemInput = z.infer<typeof createItemSchema>;
export type GetItemInput = z.infer<typeof getItemSchema>;
export type MoveItemInput = z.infer<typeof moveItemSchema>;
export type ReorderItemsInput = z.infer<typeof reorderItemsSchema>;
export type DeleteItemInput = z.infer<typeof deleteItemSchema>;
export type UpdateItemInput = z.infer<typeof updateItemSchema>;
