import { describe, expect, it } from 'vitest';

import { assertValidStateTransition } from '../src/state-machine.js';

describe('state machine', () => {
  it('allows the spec-defined transitions', () => {
    expect(() => assertValidStateTransition('requirement_input', 'requirement_review')).not.toThrow();
    expect(() => assertValidStateTransition('requirement_review', 'backlog')).not.toThrow();
    expect(() => assertValidStateTransition('requirement_review', 'needs_info')).not.toThrow();
    expect(() => assertValidStateTransition('backlog', 'ai_decomposing')).not.toThrow();
    expect(() => assertValidStateTransition('testing', 'acceptance')).not.toThrow();
    expect(() => assertValidStateTransition('testing', 'in_progress')).not.toThrow();
    expect(() => assertValidStateTransition('in_progress', 'blocked')).not.toThrow();
    expect(() => assertValidStateTransition('blocked', 'testing', { previousState: 'testing' })).not.toThrow();
  });

  it('rejects transitions outside the spec-defined graph', () => {
    expect(() => assertValidStateTransition('requirement_input', 'backlog')).toThrow(
      /cannot transition item from "requirement_input" to "backlog"/i,
    );

    expect(() => assertValidStateTransition('blocked', 'completed', { previousState: 'testing' })).toThrow(
      /must transition back to previous_state "testing"/i,
    );
  });
});
