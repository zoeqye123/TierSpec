import { z } from 'zod';

import { ItemType } from '../db/types.js';

const itemTypeValues = Object.values(ItemType) as [ItemType, ...ItemType[]];

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

export type CreateItemInput = z.infer<typeof createItemSchema>;
export type GetItemInput = z.infer<typeof getItemSchema>;
export type MoveItemInput = z.infer<typeof moveItemSchema>;
export type ReorderItemsInput = z.infer<typeof reorderItemsSchema>;
export type DeleteItemInput = z.infer<typeof deleteItemSchema>;
