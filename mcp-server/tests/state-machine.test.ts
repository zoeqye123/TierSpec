import { describe, expect, it } from 'vitest';

import { assertValidStateTransition, getAllowedTransitions } from '../src/state-machine.js';

describe('state machine', () => {
  it('allows the spec-defined transitions', () => {
    expect(() => assertValidStateTransition('requirement_input', 'requirement_review')).not.toThrow();
    expect(() => assertValidStateTransition('requirement_review', 'backlog')).not.toThrow();
    expect(() => assertValidStateTransition('requirement_review', 'needs_info')).not.toThrow();
    expect(() => assertValidStateTransition('backlog', 'ai_decomposing')).not.toThrow();
    expect(() => assertValidStateTransition('ai_decomposing', 'backlog')).not.toThrow();
    expect(() => assertValidStateTransition('in_progress', 'waiting_for_test')).not.toThrow();
    expect(() => assertValidStateTransition('waiting_for_test', 'testing')).not.toThrow();
    expect(() => assertValidStateTransition('testing', 'acceptance')).not.toThrow();
    expect(() => assertValidStateTransition('testing', 'in_progress')).not.toThrow();
    expect(() => assertValidStateTransition('acceptance', 'completed')).not.toThrow();
    expect(() => assertValidStateTransition('acceptance', 'in_progress')).not.toThrow();
    expect(() => assertValidStateTransition('completed', 'published')).not.toThrow();
    expect(() => assertValidStateTransition('in_progress', 'blocked')).not.toThrow();
    expect(() => assertValidStateTransition('published', 'cancelled')).not.toThrow();
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

  it('surfaces global cancellation in allowed transition introspection', () => {
    expect(getAllowedTransitions('published')).toEqual(['blocked', 'cancelled']);
    expect(getAllowedTransitions('blocked', 'testing')).toEqual(['testing', 'cancelled']);
    expect(getAllowedTransitions('cancelled')).toEqual([]);
  });
});
