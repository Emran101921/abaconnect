import { scanJobOpportunityPublicText } from './job-opportunity-phi.util';

describe('job-opportunity-phi.util', () => {
  it('passes clean staffing descriptions', () => {
    const result = scanJobOpportunityPublicText(
      'Occupational Therapy (OT) Therapist Needed – Brooklyn',
      'Seeking licensed OT for in-home early intervention caseload. Bilingual Spanish preferred.',
    );
    expect(result.passed).toBe(true);
    expect(result.flags).toEqual([]);
  });

  it('blocks child names and referral language', () => {
    const result = scanJobOpportunityPublicText(
      'Referral for child named Emma Smith',
      'Autism diagnosis required',
    );
    expect(result.passed).toBe(false);
    expect(result.flags.length).toBeGreaterThan(0);
    expect(result.blockedMessage).toContain('blocked');
  });

  it('blocks medicaid and insurance identifiers', () => {
    const result = scanJobOpportunityPublicText(
      'ABA therapist needed',
      'Contact with medicaid id 123456789',
    );
    expect(result.passed).toBe(false);
    expect(result.flags.some((f) => f.includes('medicaid'))).toBe(true);
  });

  it('blocks SSN-like patterns', () => {
    const result = scanJobOpportunityPublicText(
      'Speech therapist',
      'Notes include 123-45-6789 on file',
    );
    expect(result.passed).toBe(false);
  });
});
