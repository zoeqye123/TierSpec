import { describe, it, expect } from 'vitest';
import { ActorType, isValidActorType } from '../../src/db/types';

describe('ActorType', () => {
  it('should have exactly 3 values', () => {
    const values = Object.values(ActorType);
    expect(values).toHaveLength(3);
  });

  it('should have human value', () => {
    expect(ActorType.human).toBe('human');
  });

  it('should have ai value', () => {
    expect(ActorType.ai).toBe('ai');
  });

  it('should have system value', () => {
    expect(ActorType.system).toBe('system');
  });

  it('should contain all expected values', () => {
    const values = Object.values(ActorType);
    expect(values).toContain('human');
    expect(values).toContain('ai');
    expect(values).toContain('system');
  });
});

describe('isValidActorType', () => {
  it('should return true for valid actor types', () => {
    expect(isValidActorType('human')).toBe(true);
    expect(isValidActorType('ai')).toBe(true);
    expect(isValidActorType('system')).toBe(true);
  });

  it('should return false for invalid actor types', () => {
    expect(isValidActorType('user')).toBe(false);
    expect(isValidActorType('bot')).toBe(false);
    expect(isValidActorType('')).toBe(false);
    expect(isValidActorType('HUMAN')).toBe(false);
  });
});
