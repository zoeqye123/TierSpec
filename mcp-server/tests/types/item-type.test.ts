import { describe, expect, it } from 'vitest';

import { ItemType, VALID_PARENT_TYPES, isValidItemType, isValidParentType } from '../../src/db/types.js';

describe('ItemType', () => {
  it('has exactly 4 type values', () => {
    const typeValues = Object.values(ItemType);
    expect(typeValues).toHaveLength(4);
  });

  it('contains the required type values', () => {
    expect(ItemType.Capability).toBe('capability');
    expect(ItemType.Feature).toBe('feature');
    expect(ItemType.UserStory).toBe('user_story');
    expect(ItemType.TestCase).toBe('test_case');
  });

  it('validates correct type values', () => {
    expect(isValidItemType('capability')).toBe(true);
    expect(isValidItemType('feature')).toBe(true);
    expect(isValidItemType('user_story')).toBe(true);
    expect(isValidItemType('test_case')).toBe(true);
  });

  it('rejects invalid type values', () => {
    expect(isValidItemType('epic')).toBe(false);
    expect(isValidItemType('business_story')).toBe(false);
    expect(isValidItemType('technical_story')).toBe(false);
    expect(isValidItemType('invalid')).toBe(false);
  });
});

describe('VALID_PARENT_TYPES', () => {
  it('allows Capability as root (no parent)', () => {
    expect(VALID_PARENT_TYPES[ItemType.Capability]).toBeNull();
  });

  it('allows Feature under Capability', () => {
    expect(VALID_PARENT_TYPES[ItemType.Feature]).toEqual([ItemType.Capability]);
  });

  it('allows UserStory under Feature', () => {
    expect(VALID_PARENT_TYPES[ItemType.UserStory]).toEqual([ItemType.Feature]);
  });

  it('allows TestCase under UserStory', () => {
    expect(VALID_PARENT_TYPES[ItemType.TestCase]).toEqual([ItemType.UserStory]);
  });
});

describe('isValidParentType', () => {
  it('validates Capability can have no parent', () => {
    expect(isValidParentType(ItemType.Capability, null)).toBe(true);
    expect(isValidParentType(ItemType.Capability, ItemType.Feature)).toBe(false);
  });

  it('validates Feature must have Capability parent', () => {
    expect(isValidParentType(ItemType.Feature, ItemType.Capability)).toBe(true);
    expect(isValidParentType(ItemType.Feature, null)).toBe(false);
    expect(isValidParentType(ItemType.Feature, ItemType.UserStory)).toBe(false);
  });

  it('validates UserStory must have Feature parent', () => {
    expect(isValidParentType(ItemType.UserStory, ItemType.Feature)).toBe(true);
    expect(isValidParentType(ItemType.UserStory, null)).toBe(false);
    expect(isValidParentType(ItemType.UserStory, ItemType.Capability)).toBe(false);
  });

  it('validates TestCase must have UserStory parent', () => {
    expect(isValidParentType(ItemType.TestCase, ItemType.UserStory)).toBe(true);
    expect(isValidParentType(ItemType.TestCase, null)).toBe(false);
    expect(isValidParentType(ItemType.TestCase, ItemType.Feature)).toBe(false);
  });
});
