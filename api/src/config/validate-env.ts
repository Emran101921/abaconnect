const INSECURE_JWT_FALLBACK = 'change-me';
const PLACEHOLDER_SECRETS = new Set([
  INSECURE_JWT_FALLBACK,
  'change-me-refresh',
  'change-me-reset',
  'your-jwt-secret',
  'your-refresh-secret',
  'your-reset-secret',
]);

function isProductionLike(): boolean {
  return (
    process.env.NODE_ENV === 'production' || process.env.NODE_ENV === 'staging'
  );
}

function assertSecret(name: string, value: string | undefined): void {
  if (!value?.trim()) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  if (PLACEHOLDER_SECRETS.has(value.trim())) {
    throw new Error(`${name} must not use a placeholder value`);
  }
  if (value.trim().length < 16) {
    throw new Error(`${name} must be at least 16 characters`);
  }
}

export function validateProductionEnv(): void {
  if (!isProductionLike()) {
    return;
  }

  assertSecret('JWT_SECRET', process.env.JWT_SECRET);
  assertSecret('JWT_REFRESH_SECRET', process.env.JWT_REFRESH_SECRET);
  assertSecret('JWT_RESET_SECRET', process.env.JWT_RESET_SECRET);

  const databaseUrl = process.env.DATABASE_URL ?? '';
  if (
    !databaseUrl.includes('sslmode=require') &&
    !databaseUrl.includes('ssl=true')
  ) {
    console.warn(
      'DATABASE_URL should use TLS (sslmode=require) in production-like environments',
    );
  }

  if (!process.env.PHI_ENCRYPTION_KEY?.trim()) {
    throw new Error(
      'PHI_ENCRYPTION_KEY is required in production for MFA secrets, message and field-level PHI encryption (SOAP notes, screening responses, child PHI), and document encryption',
    );
  }

  if (!process.env.CORS_ORIGINS?.trim()) {
    throw new Error('CORS_ORIGINS must be set in production-like environments');
  }

  if (!process.env.AWS_S3_BUCKET?.trim()) {
    throw new Error(
      'AWS_S3_BUCKET is required in production — local uploads/ are not permitted',
    );
  }

  if (!process.env.AWS_KMS_KEY_ID?.trim()) {
    throw new Error(
      'AWS_KMS_KEY_ID is required in production for SSE-KMS document encryption',
    );
  }
}
