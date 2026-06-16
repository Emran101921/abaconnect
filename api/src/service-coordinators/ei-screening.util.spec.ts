import {
  deriveEiScreeningPriority,
  screeningCompletionPercent,
  EI_INITIAL_REQUIRED_KEYS,
} from './ei-screening.util';

describe('ei-screening.util', () => {
  it('derives HIGH priority for urgent safety concerns', () => {
    expect(
      deriveEiScreeningPriority({ urgentSafetyConcern: 'yes' }),
    ).toBe('HIGH');
  });

  it('derives MEDIUM priority for missed sessions', () => {
    expect(deriveEiScreeningPriority({ missedSessions: true })).toBe('MEDIUM');
  });

  it('derives LOW priority for stable cases', () => {
    expect(deriveEiScreeningPriority({ servicesActive: true })).toBe('LOW');
  });

  it('computes screening completion percent', () => {
    const answers: Record<string, string> = {};
    EI_INITIAL_REQUIRED_KEYS.forEach((k, i) => {
      if (i < 3) answers[k] = 'filled';
    });
    expect(screeningCompletionPercent(answers, EI_INITIAL_REQUIRED_KEYS)).toBe(
      43,
    );
  });
});
