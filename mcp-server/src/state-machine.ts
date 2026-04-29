export const WORKFLOW_STATES = [
  'todo',
  'in_progress',
  'test',
  'done',
  'blocked',
  'cancelled',
  'needs_info',
] as const;

export type WorkflowState = (typeof WORKFLOW_STATES)[number];

export type ActorType = 'human' | 'ai' | 'system';

const MAIN_STATES: readonly WorkflowState[] = ['todo', 'in_progress', 'test', 'done'];
const AUXILIARY_STATES: readonly WorkflowState[] = ['blocked', 'cancelled', 'needs_info'];

/**
 * Defines allowed state transitions.
 * Key: current state (excluding auxiliary states which have special handling)
 * Value: array of allowed target states
 */
const ALLOWED_TRANSITIONS: ReadonlyMap<WorkflowState, readonly WorkflowState[]> = new Map([
  ['todo', ['in_progress']],
  ['in_progress', ['test']],
  ['test', ['done', 'in_progress']],
  ['done', []],
  ['blocked', []], // Special handling - can return to previous state
  ['cancelled', []], // Terminal state
  ['needs_info', ['todo']],
]);

function isWorkflowState(value: string): value is WorkflowState {
  return (WORKFLOW_STATES as readonly string[]).includes(value);
}

function isActorType(value: string): value is ActorType {
  return ['human', 'ai', 'system'].includes(value);
}

/**
 * Asserts that a state transition is valid.
 * 
 * @param from - Current state
 * @param to - Target state
 * @param actorType - Type of actor performing the transition
 * @param options - Additional options (previousState for blocked items)
 * @throws Error if transition is invalid
 */
export function assertValidStateTransition(
  from: string,
  to: string,
  actorType: string,
  options: { previousState?: string | null } = {},
): void {
  // Validate states
  if (!isWorkflowState(from)) {
    throw new Error(`Unknown workflow state: "${from}".`);
  }

  if (!isWorkflowState(to)) {
    throw new Error(`Unknown workflow state: "${to}".`);
  }

  if (!isActorType(actorType)) {
    throw new Error(`Unknown actor type: "${actorType}". Must be "human", "ai", or "system".`);
  }

  // Cannot transition to same state
  if (from === to) {
    throw new Error(`Item is already in state "${from}".`);
  }

  // Rule: cancelled is terminal - no transitions allowed
  if (from === 'cancelled') {
    throw new Error(`Cancelled items cannot be transitioned to any other state.`);
  }

  // Rule: Any actor can transition to blocked
  if (to === 'blocked') {
    return;
  }

  // Rule: Any actor can transition to cancelled
  if (to === 'cancelled') {
    return;
  }

  // Rule: Any actor can transition to needs_info
  if (to === 'needs_info') {
    return;
  }

  // Rule: Blocked items can return to todo or in_progress
  if (from === 'blocked') {
    if (to === 'todo' || to === 'in_progress') {
      return;
    }
    throw new Error(
      `Blocked items can only transition to "todo", "in_progress", "blocked", "cancelled", or "needs_info". Cannot transition to "${to}".`,
    );
  }

  // Rule: Only HUMAN actors can transition to done
  if (to === 'done' && actorType !== 'human') {
    throw new Error(
      `Only human actors can transition to "done". Actor type "${actorType}" is not allowed.`,
    );
  }

  // Rule: needs_info can only transition to todo
  if (from === 'needs_info') {
    if (to === 'todo') {
      return;
    }
    throw new Error(
      `Items in "needs_info" can only transition to "todo", "blocked", "cancelled", or "needs_info". Cannot transition to "${to}".`,
    );
  }

  // Rule: done is terminal (except to auxiliary states already handled above)
  if (from === 'done') {
    throw new Error(
      `Items in "done" can only transition to "blocked", "cancelled", or "needs_info". Cannot transition to "${to}".`,
    );
  }

  // Check allowed transitions for main states
  const allowedTargets = ALLOWED_TRANSITIONS.get(from) ?? [];
  if (allowedTargets.includes(to)) {
    return;
  }

  // Build allowed description for error message
  const allowedDescription = [...allowedTargets, ...AUXILIARY_STATES];
  throw new Error(
    `Cannot transition item from "${from}" to "${to}". Allowed states: ${allowedDescription.join(', ')}.`,
  );
}

/**
 * Gets all allowed transitions for a given state.
 * 
 * @param state - Current state
 * @param actorType - Actor type (affects whether 'done' is included)
 * @returns Array of allowed target states
 */
export function getAllowedTransitions(
  state: WorkflowState,
  actorType: ActorType = 'human',
): WorkflowState[] {
  // Cancelled is terminal
  if (state === 'cancelled') {
    return [];
  }

  // Done can only go to auxiliary states
  if (state === 'done') {
    return ['blocked', 'cancelled', 'needs_info'];
  }

  // Blocked can go to todo, in_progress, or auxiliary states
  if (state === 'blocked') {
    return ['todo', 'in_progress', 'cancelled', 'needs_info'];
  }

  // needs_info can go to todo or auxiliary states
  if (state === 'needs_info') {
    return ['todo', 'blocked', 'cancelled'];
  }

  // Main states
  const baseTransitions = ALLOWED_TRANSITIONS.get(state) ?? [];
  
  // Filter out 'done' if actor is not human
  const filteredTransitions = baseTransitions.filter(t => {
    if (t === 'done') {
      return actorType === 'human';
    }
    return true;
  });

  return [...filteredTransitions, ...AUXILIARY_STATES];
}
