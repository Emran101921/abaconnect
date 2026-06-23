import {
  childAgeInMonths,
  isEiServiceEligible,
} from './ei-eligibility.util';

describe('ei-eligibility.util', () => {
  const youngDob = new Date('2024-06-01');
  const oldDob = new Date('2020-06-01');
  const asOf = new Date('2026-06-01');

  it('computes child age in months', () => {
    expect(childAgeInMonths(youngDob, asOf)).toBe(24);
  });

  it('allows assignment when evaluation requested', () => {
    const result = isEiServiceEligible({
      dateOfBirth: youngDob,
      screening: {
        isDraft: false,
        riskLevel: 'LOW',
        evaluationRequestedAt: new Date(),
        template: { therapyType: 'EARLY_INTERVENTION', name: 'EI Intake' },
      },
    });
    expect(result.eligible).toBe(true);
  });

  it('allows assignment for moderate/high risk without evaluation request', () => {
    const result = isEiServiceEligible({
      dateOfBirth: youngDob,
      screening: {
        isDraft: false,
        riskLevel: 'MODERATE',
        evaluationRequestedAt: null,
        template: { therapyType: 'EARLY_INTERVENTION', name: 'EI Intake' },
      },
    });
    expect(result.eligible).toBe(true);
  });

  it('rejects children outside EI age range', () => {
    const result = isEiServiceEligible({
      dateOfBirth: oldDob,
      screening: {
        isDraft: false,
        riskLevel: 'HIGH',
        evaluationRequestedAt: new Date(),
        template: { therapyType: 'EARLY_INTERVENTION', name: 'EI Intake' },
      },
    });
    expect(result.eligible).toBe(false);
  });

  it('rejects low-risk screening without evaluation request', () => {
    const result = isEiServiceEligible({
      dateOfBirth: youngDob,
      screening: {
        isDraft: false,
        riskLevel: 'LOW',
        evaluationRequestedAt: null,
        template: { therapyType: 'EARLY_INTERVENTION', name: 'EI Intake' },
      },
    });
    expect(result.eligible).toBe(false);
  });
});
