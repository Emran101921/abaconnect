import {
  computeSessionFeeCents,
  isSelfPayInsuranceType,
} from './self-pay.util';

describe('self-pay.util', () => {
  describe('isSelfPayInsuranceType', () => {
    it('treats null and Self-pay as self-pay', () => {
      expect(isSelfPayInsuranceType(null)).toBe(true);
      expect(isSelfPayInsuranceType(undefined)).toBe(true);
      expect(isSelfPayInsuranceType('Self-pay')).toBe(true);
    });

    it('treats insurance types as not self-pay', () => {
      expect(isSelfPayInsuranceType('Medicaid')).toBe(false);
      expect(isSelfPayInsuranceType('Private')).toBe(false);
    });
  });

  describe('computeSessionFeeCents', () => {
    it('charges at least one dollar and uses scheduled duration', () => {
      const start = new Date('2026-06-09T10:00:00Z');
      const end = new Date('2026-06-09T11:00:00Z');
      expect(computeSessionFeeCents(start, end, 120)).toBe(12000);
    });

    it('enforces a 30-minute minimum duration', () => {
      const start = new Date('2026-06-09T10:00:00Z');
      const end = new Date('2026-06-09T10:15:00Z');
      expect(computeSessionFeeCents(start, end, 120)).toBe(6000);
    });
  });
});
