import {
  hasParentSignature,
  isEipFormFullySigned,
  isReadyForParentSignature,
  missingFieldsForParentSignature,
} from './eip-form.util';

const completeForm = (): Record<string, unknown> => ({
  childName: 'Alex Smith',
  childDob: '2020-01-01',
  childSex: 'Male',
  interventionistName: 'Dr. Jane Doe',
  credentials: 'SLP',
  npi: '1234567893',
  licenseNumber: 'SLP-123456',
  serviceType: 'Speech',
  sessionDate: '2026-06-03',
  ifspServiceLocation: 'Home',
  timeFrom: '9:00',
  timeTo: '10:00',
  intensity: 'Home/Community (as authorized in IFSP)',
  sessionDelivered: 'In-person',
  dateNoteWritten: '2026-06-03',
  icd10Code: 'F80.2',
  participantChild: true,
  participantParent: true,
  q1IfspOutcomes: 'Outcome 1',
  q2SessionDescription: 'Worked on communication.',
  q3ObservedRoutines: true,
  q4HomeStrategies: 'Practice daily.',
  parentRelationship: 'Mother',
});

describe('eip-form.util', () => {
  it('reports missing fields when form is incomplete', () => {
    expect(missingFieldsForParentSignature({})).toContain('Child\'s name');
    expect(isReadyForParentSignature({})).toBe(false);
  });

  it('allows parent signature when all required fields are present', () => {
    const form = completeForm();
    expect(missingFieldsForParentSignature(form)).toEqual([]);
    expect(isReadyForParentSignature(form)).toBe(true);
  });

  it('detects GPS-verified parent and full signatures', () => {
    const signed = {
      ...completeForm(),
      parentSignature: 'Parent Name',
      parentSignatureLatitude: 40.7,
      parentSignatureLongitude: -74.0,
      interventionistSignature: 'Dr. Jane Doe',
      interventionistSignatureLatitude: 40.7,
      interventionistSignatureLongitude: -74.0,
    };
    expect(hasParentSignature(signed)).toBe(true);
    expect(isEipFormFullySigned(signed)).toBe(true);
  });
});
