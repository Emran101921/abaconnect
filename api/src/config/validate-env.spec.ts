import { validateProductionEnv } from './validate-env';

describe('validateProductionEnv', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    process.env = { ...originalEnv };
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  it('allows missing secrets outside production', () => {
    delete process.env.NODE_ENV;
    delete process.env.JWT_SECRET;
    expect(() => validateProductionEnv()).not.toThrow();
  });

  it('throws when production secrets are missing', () => {
    process.env.NODE_ENV = 'production';
    delete process.env.JWT_SECRET;
    delete process.env.JWT_REFRESH_SECRET;
    delete process.env.JWT_RESET_SECRET;

    expect(() => validateProductionEnv()).toThrow(/JWT_SECRET/);
  });

  it('throws when production uses the insecure JWT fallback', () => {
    process.env.NODE_ENV = 'production';
    process.env.JWT_SECRET = 'change-me';
    process.env.JWT_REFRESH_SECRET = 'refresh-secret';
    process.env.JWT_RESET_SECRET = 'reset-secret';

    expect(() => validateProductionEnv()).toThrow(/fallback/);
  });
});
