import { ClaimSecurityService } from './claim-security.service';

describe('ClaimSecurityService', () => {
  const audit = { log: jest.fn() };
  const prisma = {
    insuranceClaim: {
      findFirst: jest.fn(),
      update: jest.fn(),
      create: jest.fn(),
    },
    claimEditHistory: { create: jest.fn() },
  };

  const service = new ClaimSecurityService(prisma as never, audit as never);

  beforeEach(() => jest.clearAllMocks());

  it('computes stable duplicate hashes', () => {
    const date = new Date('2026-01-15');
    const a = service.computeDuplicateHash({
      childId: 'child-1',
      serviceDate: date,
      cptCode: '97153',
      billedAmount: 120,
      payerName: 'Medicaid',
    });
    const b = service.computeDuplicateHash({
      childId: 'child-1',
      serviceDate: date,
      cptCode: '97153',
      billedAmount: 120,
      payerName: 'medicaid',
    });
    expect(a).toBe(b);
  });

  it('rejects edits on locked claims', () => {
    expect(() =>
      service.assertEditable({
        status: 'SUBMITTED',
        lockedAt: new Date(),
      }),
    ).toThrow('Claim is locked');
  });
});
