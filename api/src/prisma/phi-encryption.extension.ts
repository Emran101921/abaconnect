import { Prisma } from '../../generated/prisma/client';
import { decryptField, encryptField } from '../common/crypto/field-crypto.util';

/**
 * Transparent field-level encryption for the highest-sensitivity PHI columns.
 *
 * Encrypts configured free-text/JSON fields on write and decrypts them on read
 * across every access path (including nested relation includes). Values are
 * prefixed with `enc:` so the layer is fully backward compatible with rows that
 * were written before encryption was enabled — legacy plaintext is returned
 * untouched.
 *
 * Encryption only activates when PHI_ENCRYPTION_KEY is configured. In
 * production/staging this key is required by validate-env.ts.
 */
const ENC_PREFIX = 'enc:';

// Free-text string columns that hold PHI and are never used as query filters.
const STRING_FIELDS_BY_MODEL: Record<string, string[]> = {
  SoapNote: ['subjective', 'objective', 'assessment', 'plan'],
  ProgressNote: ['summary', 'parentFeedback'],
  Child: [
    'guardianName',
    'guardianPhone',
    'guardianEmail',
    'addressLine1',
    'pediatricianName',
    'notes',
  ],
  Parent: ['insuranceMemberId', 'insuranceGroupNumber', 'emergencyContactPhone'],
  Therapist: ['taxId', 'bio'],
};

// JSON columns that hold raw clinical answers.
const JSON_FIELDS_BY_MODEL: Record<string, string[]> = {
  ScreeningResponse: ['responses'],
  ServiceLog: ['logData'],
  InsuranceClaim: ['metadata'],
};

// Flattened field-name lookups used by the recursive read-side decryptor so
// nested relation payloads (e.g. session.include({ soapNote: true })) are
// covered regardless of which model the query targeted.
const STRING_FIELD_NAMES = new Set<string>(
  Object.values(STRING_FIELDS_BY_MODEL).flat(),
);
const JSON_FIELD_NAMES = new Set<string>(
  Object.values(JSON_FIELDS_BY_MODEL).flat(),
);

const WRITE_OPERATIONS = new Set([
  'create',
  'createMany',
  'update',
  'updateMany',
  'upsert',
]);

function phiKey(): string | undefined {
  const key = process.env.PHI_ENCRYPTION_KEY?.trim();
  return key || undefined;
}

function encryptString(value: string, key: string): string {
  if (value.startsWith(ENC_PREFIX)) return value;
  return `${ENC_PREFIX}${encryptField(value, key)}`;
}

function decryptString(value: string, key: string): string {
  if (!value.startsWith(ENC_PREFIX)) return value;
  try {
    return decryptField(value.slice(ENC_PREFIX.length), key);
  } catch {
    return value;
  }
}

function encryptWriteData(
  data: Record<string, unknown>,
  stringFields: string[],
  jsonFields: string[],
  key: string,
): void {
  for (const field of stringFields) {
    const value = data[field];
    if (typeof value === 'string' && value.length > 0) {
      data[field] = encryptString(value, key);
    }
  }
  for (const field of jsonFields) {
    const value = data[field];
    if (value !== undefined && value !== null && typeof value !== 'string') {
      data[field] = encryptString(JSON.stringify(value), key);
    }
  }
}

export function applyWriteEncryption(
  model: string,
  args: unknown,
  key: string,
): void {
  const stringFields = STRING_FIELDS_BY_MODEL[model] ?? [];
  const jsonFields = JSON_FIELDS_BY_MODEL[model] ?? [];
  if (!stringFields.length && !jsonFields.length) return;

  const mutable = args as {
    data?: Record<string, unknown> | Record<string, unknown>[];
    create?: Record<string, unknown>;
    update?: Record<string, unknown>;
  };

  const targets: Record<string, unknown>[] = [];
  if (Array.isArray(mutable.data)) targets.push(...mutable.data);
  else if (mutable.data) targets.push(mutable.data);
  if (mutable.create) targets.push(mutable.create);
  if (mutable.update) targets.push(mutable.update);

  for (const target of targets) {
    encryptWriteData(target, stringFields, jsonFields, key);
  }
}

export function decryptResult(value: unknown, key: string): void {
  if (value == null || typeof value !== 'object') return;
  if (value instanceof Date || Buffer.isBuffer(value)) return;

  if (Array.isArray(value)) {
    for (const item of value) decryptResult(item, key);
    return;
  }

  const record = value as Record<string, unknown>;
  for (const [field, raw] of Object.entries(record)) {
    if (typeof raw === 'string' && raw.startsWith(ENC_PREFIX)) {
      if (STRING_FIELD_NAMES.has(field)) {
        record[field] = decryptString(raw, key);
        continue;
      }
      if (JSON_FIELD_NAMES.has(field)) {
        const plaintext = decryptString(raw, key);
        try {
          record[field] = JSON.parse(plaintext);
        } catch {
          record[field] = plaintext;
        }
        continue;
      }
    } else if (raw && typeof raw === 'object') {
      decryptResult(raw, key);
    }
  }
}

export const phiEncryptionExtension = Prisma.defineExtension({
  query: {
    $allModels: {
      async $allOperations({ model, operation, args, query }) {
        const key = phiKey();
        if (!key) {
          return query(args);
        }
        if (model && WRITE_OPERATIONS.has(operation)) {
          applyWriteEncryption(model, args, key);
        }
        const result = await query(args);
        decryptResult(result, key);
        return result;
      },
    },
  },
});
