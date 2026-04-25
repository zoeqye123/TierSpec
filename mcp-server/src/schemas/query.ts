import { z } from 'zod';

import { ItemStatus, ItemType } from '../db/types.js';

export const itemFilterSchemaShape = {
  parent_id: z.string().min(1).optional(),
  type: z.nativeEnum(ItemType).optional(),
  status: z.nativeEnum(ItemStatus).optional(),
};

export const itemFilterSchema = z.object(itemFilterSchemaShape);

export const getItemTreeSchemaShape = {
  root_id: z.string().min(1),
  max_depth: z.number().int().min(1).max(10).optional(),
};

export const getItemTreeSchema = z.object(getItemTreeSchemaShape);

export const searchItemsSchemaShape = {
  query: z.string().trim().min(1),
  filters: itemFilterSchema.optional(),
  page: z.number().int().min(1).optional(),
  limit: z.number().int().min(1).max(100).optional(),
};

export const searchItemsSchema = z.object(searchItemsSchemaShape);

export const listItemsSchemaShape = {
  parent_id: z.string().min(1).optional(),
  type: z.nativeEnum(ItemType).optional(),
  status: z.nativeEnum(ItemStatus).optional(),
};

export const listItemsSchema = z.object(listItemsSchemaShape);

export type ItemFilters = z.infer<typeof itemFilterSchema>;
export type GetItemTreeInput = z.infer<typeof getItemTreeSchema>;
export type SearchItemsInput = z.infer<typeof searchItemsSchema>;
export type ListItemsInput = z.infer<typeof listItemsSchema>;
