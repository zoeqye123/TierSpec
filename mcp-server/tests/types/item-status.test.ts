import { describe, expect, it } from 'vitest';

import { ItemStatus, isValidItemStatus } from '../../src/db/types.js';

describe('ItemStatus', () => {
  it('has exactly 7 status values', () => {
    const statusValues = Object.values(ItemStatus);
    expect(statusValues).toHaveLength(7);
  });

  it('contains the required status values', () => {
    expect(ItemStatus.Todo).toBe('todo');
    expect(ItemStatus.InProgress).toBe('in_progress');
    expect(ItemStatus.Test).toBe('test');
    expect(ItemStatus.Done).toBe('done');
    expect(ItemStatus.Blocked).toBe('blocked');
    expect(ItemStatus.Cancelled).toBe('cancelled');
    expect(ItemStatus.NeedsInfo).toBe('needs_info');
  });

  it('validates correct status values', () => {
    expect(isValidItemStatus('todo')).toBe(true);
    expect(isValidItemStatus('in_progress')).toBe(true);
    expect(isValidItemStatus('test')).toBe(true);
    expect(isValidItemStatus('done')).toBe(true);
    expect(isValidItemStatus('blocked')).toBe(true);
    expect(isValidItemStatus('cancelled')).toBe(true);
    expect(isValidItemStatus('needs_info')).toBe(true);
  });

  it('rejects invalid status values', () => {
    expect(isValidItemStatus('backlog')).toBe(false);
    expect(isValidItemStatus('testing')).toBe(false);
    expect(isValidItemStatus('completed')).toBe(false);
    expect(isValidItemStatus('requirement_input')).toBe(false);
    expect(isValidItemStatus('invalid')).toBe(false);
  });
});
