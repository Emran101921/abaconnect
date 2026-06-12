import {
  applyWriteEncryption,
  decryptResult,
} from './phi-encryption.extension';

const KEY = 'unit-test-phi-key';

describe('phiEncryptionExtension helpers', () => {
  it('encrypts configured SoapNote string fields on write', () => {
    const args = {
      data: {
        subjective: 'patient was calm',
        objective: 'observed 3 tantrums',
        assessment: 'progress on goal 2',
        plan: 'continue plan',
        sessionId: 'abc',
      },
    };
    applyWriteEncryption('SoapNote', args, KEY);
    expect(args.data.subjective).toMatch(/^enc:/);
    expect(args.data.objective).toMatch(/^enc:/);
    expect(args.data.assessment).toMatch(/^enc:/);
    expect(args.data.plan).toMatch(/^enc:/);
    // Non-PHI field untouched.
    expect(args.data.sessionId).toBe('abc');
  });

  it('round-trips encrypted SoapNote fields back to plaintext on read', () => {
    const writeArgs = {
      data: { subjective: 'sensitive clinical note', plan: 'next steps' },
    };
    applyWriteEncryption('SoapNote', writeArgs, KEY);

    const row = { ...writeArgs.data };
    decryptResult(row, KEY);
    expect(row.subjective).toBe('sensitive clinical note');
    expect(row.plan).toBe('next steps');
  });

  it('encrypts Child first and last name on write', () => {
    const args = {
      data: {
        firstName: 'Alex',
        lastName: 'Demo',
        zipCode: '11230',
      },
    };
    applyWriteEncryption('Child', args, KEY);
    expect(args.data.firstName).toMatch(/^enc:/);
    expect(args.data.lastName).toMatch(/^enc:/);
    expect(args.data.zipCode).toBe('11230');
  });

  it('decrypts nested relation payloads (session include soapNote)', () => {
    const writeArgs = { data: { subjective: 'nested note' } };
    applyWriteEncryption('SoapNote', writeArgs, KEY);

    const session = {
      id: 's1',
      child: { firstName: 'Alex' },
      soapNote: { ...writeArgs.data },
    };
    decryptResult(session, KEY);
    expect(session.soapNote.subjective).toBe('nested note');
  });

  it('encrypts and round-trips ScreeningResponse JSON answers', () => {
    const args = {
      data: { responses: { q1: 'yes', q2: 'sometimes' }, childId: 'c1' },
    };
    applyWriteEncryption('ScreeningResponse', args, KEY);
    expect(typeof args.data.responses).toBe('string');
    expect(args.data.responses as unknown as string).toMatch(/^enc:/);

    const row = { responses: args.data.responses };
    decryptResult(row, KEY);
    expect(row.responses).toEqual({ q1: 'yes', q2: 'sometimes' });
  });

  it('leaves legacy plaintext values untouched on read', () => {
    const row = { subjective: 'legacy unencrypted note' };
    decryptResult(row, KEY);
    expect(row.subjective).toBe('legacy unencrypted note');
  });

  it('does not double-encrypt already-encrypted values', () => {
    const args = { data: { subjective: 'note' } };
    applyWriteEncryption('SoapNote', args, KEY);
    const once = args.data.subjective;
    applyWriteEncryption('SoapNote', args, KEY);
    expect(args.data.subjective).toBe(once);
  });

  it('ignores models without configured PHI fields', () => {
    const args = { data: { email: 'user@example.com' } };
    applyWriteEncryption('User', args, KEY);
    expect(args.data.email).toBe('user@example.com');
  });
});
