export const WORKFLOW_STATES = [
  'requirement_input',
  'requirement_review',
  'needs_info',
  'backlog',
  'ai_decomposing',
  'in_progress',
  'waiting_for_test',
  'testing',
  'acceptance',
  'completed',
  'published',
  'blocked',
  'cancelled',
] as const;

export type WorkflowState = (typeof WORKFLOW_STATES)[number];

const ALLOWED_TRANSITIONS: ReadonlyMap<Exclude<WorkflowState, 'blocked'>, readonly WorkflowState[]> = new Map([
  ['requirement_input', ['requirement_review']],
  ['requirement_review', ['backlog', 'needs_info']],
  ['needs_info', []],
  ['backlog', ['ai_decomposing']],
  ['ai_decomposing', ['backlog']],
  ['in_progress', ['waiting_for_test']],
  ['waiting_for_test', ['testing']],
  ['testing', ['acceptance', 'in_progress']],
  ['acceptance', ['completed', 'in_progress']],
  ['completed', ['published']],
  ['published', []],
  ['cancelled', []],
]);

function isWorkflowState(value: string): value is WorkflowState {
  return (WORKFLOW_STATES as readonly string[]).includes(value);
}

export function assertValidStateTransition(
  currentState: string,
  newState: string,
  options: { previousState?: string | null } = {},
) {
  if (!isWorkflowState(currentState)) {
    throw new Error(`Unknown workflow state: "${currentState}".`);
  }

  if (!isWorkflowState(newState)) {
    throw new Error(`Unknown workflow state: "${newState}".`);
  }

  if (currentState === newState) {
    throw new Error(`Item is already in state "${currentState}".`);
  }

  if (newState === 'blocked') {
    return;
  }

  if (newState === 'cancelled') {
    return;
  }

  if (currentState === 'blocked') {
    if (!options.previousState) {
      throw new Error('Blocked item is missing previous_state and cannot be restored.');
    }

    if (newState !== options.previousState) {
      throw new Error(
        `Blocked items must transition back to previous_state "${options.previousState}", received "${newState}".`,
      );
    }

    return;
  }

  const allowedTargets = ALLOWED_TRANSITIONS.get(currentState) ?? [];
  if (allowedTargets.includes(newState)) {
    return;
  }

  const allowedDescription = [...allowedTargets, 'blocked'];
  throw new Error(
    `Cannot transition item from "${currentState}" to "${newState}". Allowed states: ${allowedDescription.join(', ') || 'none'}.`,
  );
}

export function getAllowedTransitions(state: WorkflowState, previousState?: WorkflowState | null) {
  if (state === 'blocked') {
    return previousState ? [previousState, 'cancelled'] : ['cancelled'];
  }

  if (state === 'cancelled') {
    return [];
  }

  return [...(ALLOWED_TRANSITIONS.get(state) ?? []), 'blocked', 'cancelled'];
}
