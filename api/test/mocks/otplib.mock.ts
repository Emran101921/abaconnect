export const generateSecret = jest.fn(() => 'TEST-MFA-SECRET');
export const generateURI = jest.fn(
  () => 'otpauth://totp/BloomOra:test?secret=TEST-MFA-SECRET',
);
export const verify = jest.fn(() => true);
