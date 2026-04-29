import { describe, expect, it } from 'vitest';

import { assertValidStateTransition, getAllowedTransitions } from '../src/state-machine.js';

describe('state machine - valid transitions', () => {
  describe('main flow transitions (any actor)', () => {
    it('allows todo → in_progress for human', () => {
      expect(() => assertValidStateTransition('todo', 'in_progress', 'human')).not.toThrow();
    });

    it('allows todo → in_progress for ai', () => {
      expect(() => assertValidStateTransition('todo', 'in_progress', 'ai')).not.toThrow();
    });

    it('allows todo → in_progress for system', () => {
      expect(() => assertValidStateTransition('todo', 'in_progress', 'system')).not.toThrow();
    });

    it('allows in_progress → test for any actor', () => {
      expect(() => assertValidStateTransition('in_progress', 'test', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'test', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'test', 'system')).not.toThrow();
    });

    it('allows test → in_progress for any actor (on failure)', () => {
      expect(() => assertValidStateTransition('test', 'in_progress', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'in_progress', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'in_progress', 'system')).not.toThrow();
    });
  });

  describe('test → done transition (HUMAN ONLY)', () => {
    it('allows test → done for human', () => {
      expect(() => assertValidStateTransition('test', 'done', 'human')).not.toThrow();
    });

    it('rejects test → done for ai', () => {
      expect(() => assertValidStateTransition('test', 'done', 'ai')).toThrow(
        /only human actors can transition to "done"/i,
      );
    });

    it('rejects test → done for system', () => {
      expect(() => assertValidStateTransition('test', 'done', 'system')).toThrow(
        /only human actors can transition to "done"/i,
      );
    });
  });

  describe('global transitions to blocked (any actor)', () => {
    it('allows any state → blocked for human', () => {
      expect(() => assertValidStateTransition('todo', 'blocked', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'blocked', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'blocked', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('done', 'blocked', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('needs_info', 'blocked', 'human')).not.toThrow();
    });

    it('allows any state → blocked for ai', () => {
      expect(() => assertValidStateTransition('todo', 'blocked', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'blocked', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'blocked', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('done', 'blocked', 'ai')).not.toThrow();
    });

    it('allows any state → blocked for system', () => {
      expect(() => assertValidStateTransition('todo', 'blocked', 'system')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'blocked', 'system')).not.toThrow();
    });
  });

  describe('blocked state transitions', () => {
    it('allows blocked → todo for any actor', () => {
      expect(() => assertValidStateTransition('blocked', 'todo', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('blocked', 'todo', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('blocked', 'todo', 'system')).not.toThrow();
    });

    it('allows blocked → in_progress for any actor', () => {
      expect(() => assertValidStateTransition('blocked', 'in_progress', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('blocked', 'in_progress', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('blocked', 'in_progress', 'system')).not.toThrow();
    });

    it('allows blocked → cancelled for any actor', () => {
      expect(() => assertValidStateTransition('blocked', 'cancelled', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('blocked', 'cancelled', 'ai')).not.toThrow();
    });

    it('allows blocked → needs_info for any actor', () => {
      expect(() => assertValidStateTransition('blocked', 'needs_info', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('blocked', 'needs_info', 'ai')).not.toThrow();
    });

    it('rejects blocked → test', () => {
      expect(() => assertValidStateTransition('blocked', 'test', 'human')).toThrow(
        /blocked items can only transition to/i,
      );
    });

    it('rejects blocked → done', () => {
      expect(() => assertValidStateTransition('blocked', 'done', 'human')).toThrow(
        /blocked items can only transition to/i,
      );
    });
  });

  describe('global transitions to cancelled (any actor)', () => {
    it('allows any state → cancelled for human', () => {
      expect(() => assertValidStateTransition('todo', 'cancelled', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'cancelled', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'cancelled', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('done', 'cancelled', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('needs_info', 'cancelled', 'human')).not.toThrow();
    });

    it('allows any state → cancelled for ai', () => {
      expect(() => assertValidStateTransition('todo', 'cancelled', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'cancelled', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'cancelled', 'ai')).not.toThrow();
    });
  });

  describe('cancelled state (terminal)', () => {
    it('rejects all transitions from cancelled', () => {
      expect(() => assertValidStateTransition('cancelled', 'todo', 'human')).toThrow(
        /cancelled items cannot be transitioned/i,
      );
      expect(() => assertValidStateTransition('cancelled', 'in_progress', 'human')).toThrow(
        /cancelled items cannot be transitioned/i,
      );
      expect(() => assertValidStateTransition('cancelled', 'blocked', 'human')).toThrow(
        /cancelled items cannot be transitioned/i,
      );
      expect(() => assertValidStateTransition('cancelled', 'needs_info', 'human')).toThrow(
        /cancelled items cannot be transitioned/i,
      );
    });
  });

  describe('global transitions to needs_info (any actor)', () => {
    it('allows any state → needs_info for human', () => {
      expect(() => assertValidStateTransition('todo', 'needs_info', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'needs_info', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('test', 'needs_info', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('done', 'needs_info', 'human')).not.toThrow();
    });

    it('allows any state → needs_info for ai', () => {
      expect(() => assertValidStateTransition('todo', 'needs_info', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('in_progress', 'needs_info', 'ai')).not.toThrow();
    });
  });

  describe('needs_info state transitions', () => {
    it('allows needs_info → todo for any actor', () => {
      expect(() => assertValidStateTransition('needs_info', 'todo', 'human')).not.toThrow();
      expect(() => assertValidStateTransition('needs_info', 'todo', 'ai')).not.toThrow();
      expect(() => assertValidStateTransition('needs_info', 'todo', 'system')).not.toThrow();
    });

    it('rejects needs_info → in_progress', () => {
      expect(() => assertValidStateTransition('needs_info', 'in_progress', 'human')).toThrow(
        /items in "needs_info" can only transition to/i,
      );
    });

    it('rejects needs_info → test', () => {
      expect(() => assertValidStateTransition('needs_info', 'test', 'human')).toThrow(
        /items in "needs_info" can only transition to/i,
      );
    });
  });

  describe('done state (terminal except auxiliary)', () => {
    it('allows done → blocked', () => {
      expect(() => assertValidStateTransition('done', 'blocked', 'human')).not.toThrow();
    });

    it('allows done → cancelled', () => {
      expect(() => assertValidStateTransition('done', 'cancelled', 'human')).not.toThrow();
    });

    it('allows done → needs_info', () => {
      expect(() => assertValidStateTransition('done', 'needs_info', 'human')).not.toThrow();
    });

    it('rejects done → todo', () => {
      expect(() => assertValidStateTransition('done', 'todo', 'human')).toThrow(
        /items in "done" can only transition to/i,
      );
    });

    it('rejects done → in_progress', () => {
      expect(() => assertValidStateTransition('done', 'in_progress', 'human')).toThrow(
        /items in "done" can only transition to/i,
      );
    });
  });
});

describe('state machine - invalid inputs', () => {
  it('rejects unknown from state', () => {
    expect(() => assertValidStateTransition('unknown', 'todo', 'human')).toThrow(
      /unknown workflow state: "unknown"/i,
    );
  });

  it('rejects unknown to state', () => {
    expect(() => assertValidStateTransition('todo', 'unknown', 'human')).toThrow(
      /unknown workflow state: "unknown"/i,
    );
  });

  it('rejects unknown actor type', () => {
    expect(() => assertValidStateTransition('todo', 'in_progress', 'unknown')).toThrow(
      /unknown actor type: "unknown"/i,
    );
  });

  it('rejects transition to same state', () => {
    expect(() => assertValidStateTransition('todo', 'todo', 'human')).toThrow(
      /already in state "todo"/i,
    );
    expect(() => assertValidStateTransition('in_progress', 'in_progress', 'ai')).toThrow(
      /already in state "in_progress"/i,
    );
  });
});

describe('state machine - invalid transitions', () => {
  it('rejects todo → test', () => {
    expect(() => assertValidStateTransition('todo', 'test', 'human')).toThrow(
      /cannot transition item from "todo" to "test"/i,
    );
  });

  it('rejects todo → done', () => {
    expect(() => assertValidStateTransition('todo', 'done', 'human')).toThrow(
      /cannot transition item from "todo" to "done"/i,
    );
  });

  it('rejects in_progress → todo', () => {
    expect(() => assertValidStateTransition('in_progress', 'todo', 'human')).toThrow(
      /cannot transition item from "in_progress" to "todo"/i,
    );
  });

  it('rejects in_progress → done', () => {
    expect(() => assertValidStateTransition('in_progress', 'done', 'human')).toThrow(
      /cannot transition item from "in_progress" to "done"/i,
    );
  });

  it('rejects test → todo', () => {
    expect(() => assertValidStateTransition('test', 'todo', 'human')).toThrow(
      /cannot transition item from "test" to "todo"/i,
    );
  });
});

describe('getAllowedTransitions', () => {
  it('returns correct transitions for todo', () => {
    expect(getAllowedTransitions('todo', 'human')).toEqual([
      'in_progress',
      'blocked',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns correct transitions for in_progress', () => {
    expect(getAllowedTransitions('in_progress', 'human')).toEqual([
      'test',
      'blocked',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns correct transitions for test (human)', () => {
    expect(getAllowedTransitions('test', 'human')).toEqual([
      'done',
      'in_progress',
      'blocked',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns correct transitions for test (ai - no done)', () => {
    expect(getAllowedTransitions('test', 'ai')).toEqual([
      'in_progress',
      'blocked',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns correct transitions for test (system - no done)', () => {
    expect(getAllowedTransitions('test', 'system')).toEqual([
      'in_progress',
      'blocked',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns correct transitions for done', () => {
    expect(getAllowedTransitions('done', 'human')).toEqual([
      'blocked',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns correct transitions for blocked', () => {
    expect(getAllowedTransitions('blocked', 'human')).toEqual([
      'todo',
      'in_progress',
      'cancelled',
      'needs_info',
    ]);
  });

  it('returns empty array for cancelled', () => {
    expect(getAllowedTransitions('cancelled', 'human')).toEqual([]);
  });

  it('returns correct transitions for needs_info', () => {
    expect(getAllowedTransitions('needs_info', 'human')).toEqual([
      'todo',
      'blocked',
      'cancelled',
    ]);
  });
});
