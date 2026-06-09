const INSECURE_JWT_FALLBACK = 'change-me';

export function validateProductionEnv(): void {
  if (process.env.NODE_ENV !== 'production') {
    return;
  }

  const required = [
    'JWT_SECRET',
    'JWT_REFRESH_SECRET',
    'JWT_RESET_SECRET',
  ] as const;

  const missing = required.filter((key) => !process.env[key]?.trim());
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables in production: ${missing.join(', ')}`,
    );
  }

  if (process.env.JWT_SECRET === INSECURE_JWT_FALLBACK) {
    throw new Error('JWT_SECRET must not use the development fallback in production');
  }
}
