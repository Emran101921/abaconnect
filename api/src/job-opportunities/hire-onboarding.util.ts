export const HIRE_ONBOARDING_STEP_KEYS = [
  'W9',
  'POLICIES',
  'NPI',
  'ORIENTATION',
  'FIRST_SESSION',
] as const;

export type HireOnboardingStepKey = (typeof HIRE_ONBOARDING_STEP_KEYS)[number];

export type HireOnboardingStepState = {
  complete: boolean;
  completedAt?: string;
  completedByUserId?: string;
};

export type HireOnboardingState = Partial<
  Record<
    'w9' | 'policies' | 'npi' | 'orientation' | 'firstSession',
    HireOnboardingStepState
  >
>;

const STEP_META: Record<
  HireOnboardingStepKey,
  {
    stateKey: keyof HireOnboardingState;
    label: string;
    therapistCanComplete: boolean;
  }
> = {
  W9: {
    stateKey: 'w9',
    label: 'W-9 submitted',
    therapistCanComplete: true,
  },
  POLICIES: {
    stateKey: 'policies',
    label: 'Agency policies acknowledged',
    therapistCanComplete: true,
  },
  NPI: {
    stateKey: 'npi',
    label: 'NPI verified',
    therapistCanComplete: false,
  },
  ORIENTATION: {
    stateKey: 'orientation',
    label: 'Orientation complete',
    therapistCanComplete: false,
  },
  FIRST_SESSION: {
    stateKey: 'firstSession',
    label: 'First session scheduled',
    therapistCanComplete: false,
  },
};

export function defaultHireOnboardingState(): HireOnboardingState {
  return {};
}

export function parseHireOnboardingState(raw: unknown): HireOnboardingState {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return defaultHireOnboardingState();
  }
  const input = raw as Record<string, unknown>;
  const readStep = (
    key: keyof HireOnboardingState,
  ): HireOnboardingStepState | undefined => {
    const row = input[key];
    if (!row || typeof row !== 'object' || Array.isArray(row)) return undefined;
    const step = row as Record<string, unknown>;
    if (typeof step.complete !== 'boolean') return undefined;
    return {
      complete: step.complete,
      completedAt:
        typeof step.completedAt === 'string' ? step.completedAt : undefined,
      completedByUserId:
        typeof step.completedByUserId === 'string'
          ? step.completedByUserId
          : undefined,
    };
  };
  return {
    w9: readStep('w9'),
    policies: readStep('policies'),
    npi: readStep('npi'),
    orientation: readStep('orientation'),
    firstSession: readStep('firstSession'),
  };
}

export function buildHireOnboardingView(state: HireOnboardingState) {
  const steps = HIRE_ONBOARDING_STEP_KEYS.map((key) => {
    const meta = STEP_META[key];
    const row = state[meta.stateKey];
    return {
      key,
      label: meta.label,
      complete: row?.complete === true,
      completedAt: row?.completedAt ? new Date(row.completedAt) : undefined,
      therapistCanComplete: meta.therapistCanComplete,
    };
  });
  const completedCount = steps.filter((step) => step.complete).length;
  return {
    steps,
    completedCount,
    totalCount: steps.length,
    isComplete: completedCount === steps.length,
  };
}

export function canTherapistUpdateStep(step: HireOnboardingStepKey): boolean {
  return STEP_META[step].therapistCanComplete;
}

export function canAgencyUpdateStep(step: HireOnboardingStepKey): boolean {
  return !STEP_META[step].therapistCanComplete && step !== 'FIRST_SESSION';
}

export function applyHireOnboardingStep(
  state: HireOnboardingState,
  step: HireOnboardingStepKey,
  complete: boolean,
  userId: string,
): HireOnboardingState {
  const meta = STEP_META[step];
  const next = { ...state };
  if (!complete) {
    delete next[meta.stateKey];
    return next;
  }
  next[meta.stateKey] = {
    complete: true,
    completedAt: new Date().toISOString(),
    completedByUserId: userId,
  };
  return next;
}

export function markFirstSessionScheduled(
  state: HireOnboardingState,
  userId: string,
): HireOnboardingState {
  return applyHireOnboardingStep(state, 'FIRST_SESSION', true, userId);
}
