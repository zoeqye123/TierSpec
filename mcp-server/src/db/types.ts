/**
 * TierSpec Database Types
 * TypeScript interfaces matching the SQLite schema
 */

/** Item type hierarchy - defines valid parent-child relationships */
export enum ItemType {
  Capability = 'capability',
  Feature = 'feature',
  Epic = 'epic',
  BusinessStory = 'business_story',
  TechnicalStory = 'technical_story',
  TestCase = 'test_case',
}

/** Item status workflow states */
export enum ItemStatus {
  Backlog = 'backlog',
  Ready = 'ready',
  InProgress = 'in_progress',
  Blocked = 'blocked',
  Review = 'review',
  Done = 'done',
  Archived = 'archived',
}

/** Complexity estimation levels */
export enum Complexity {
  XS = 'xs',
  S = 's',
  M = 'm',
  L = 'l',
  XL = 'xl',
}

/** Core item entity */
export interface Item {
  id: string;
  type: ItemType;
  parent_id: string | null;
  title: string;
  description: string | null;
  status: ItemStatus;
  priority: number;
  labels: string[];
  position: number;
  story_points: number | null;
  complexity: Complexity | null;
  ai_generated: boolean;
  ai_confidence: number | null;
  ai_reasoning: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  created_by: string;
  updated_by: string | null;
}

/** Closure table entry for hierarchical queries */
export interface ItemPath {
  ancestor_id: string;
  descendant_id: string;
  depth: number;
}

/** Parent change audit trail */
export interface ItemParentHistory {
  id: string;
  item_id: string;
  old_parent_id: string | null;
  new_parent_id: string | null;
  changed_at: string;
  changed_by: string;
  reason: string | null;
}

/** User entity */
export interface User {
  id: string;
  name: string;
  email: string;
  created_at: string;
  updated_at: string;
}

/** Type guard for valid item types */
export function isValidItemType(type: string): type is ItemType {
  return Object.values(ItemType).includes(type as ItemType);
}

/** Type guard for valid item status */
export function isValidItemStatus(status: string): status is ItemStatus {
  return Object.values(ItemStatus).includes(status as ItemStatus);
}

/** Type guard for valid complexity */
export function isValidComplexity(complexity: string): complexity is Complexity {
  return Object.values(Complexity).includes(complexity as Complexity);
}

/** Valid parent type rules - maps child type to valid parent types */
export const VALID_PARENT_TYPES: Record<ItemType, ItemType[] | null> = {
  [ItemType.Capability]: null, // Capabilities have no parent (root level)
  [ItemType.Feature]: [ItemType.Capability],
  [ItemType.Epic]: [ItemType.Feature],
  [ItemType.BusinessStory]: [ItemType.Epic],
  [ItemType.TechnicalStory]: [ItemType.Epic],
  [ItemType.TestCase]: [ItemType.BusinessStory, ItemType.TechnicalStory],
};

/** Check if a parent type is valid for a given child type */
export function isValidParentType(childType: ItemType, parentType: ItemType | null): boolean {
  const validParents = VALID_PARENT_TYPES[childType];
  if (validParents === null) {
    return parentType === null;
  }
  return parentType !== null && validParents.includes(parentType);
}

/** Create item input (omits auto-generated fields) */
export type CreateItemInput = Omit<Item, 'id' | 'created_at' | 'updated_at' | 'deleted_at'>;

/** Update item input (all fields optional except id) */
export type UpdateItemInput = Partial<Omit<Item, 'id' | 'created_at' | 'created_by'>> & { id: string };
