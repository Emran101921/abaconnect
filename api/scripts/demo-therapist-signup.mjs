/**
 * Dev-only: register a new therapist test account and print MFA setup codes.
 *
 * Usage: npm run demo:therapist-signup
 */
import { createGuardrails } from '@otplib/core';
import { generateSync } from 'otplib';

const API = process.env.API_BASE ?? 'http://localhost:3000/api/v1';
const stamp = Date.now();
const email = `therapist-test-${stamp}@demo.local`;
const password = 'Therapist123!';

async function post(path, body, token) {
  const res = await fetch(`${API}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      'x-device-id': `demo-signup-${stamp}`,
      'x-device-platform': 'cli',
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`${path} -> ${res.status}: ${text}`);
  }
  return data;
}

const registered = await post('/auth/register', {
  email,
  password,
  firstName: 'Test',
  lastName: 'Therapist',
  role: 'THERAPIST',
});

const token = registered.accessToken;
const setup = await post('/auth/mfa/setup', {}, token);

let mfaCode = '000000';
if (setup.secret) {
  mfaCode = generateSync({
    secret: setup.secret,
    guardrails: createGuardrails({ MIN_SECRET_BYTES: 10 }),
  });
}

await post('/auth/mfa/enable', { code: mfaCode }, token);

console.log('--- New therapist test account ---');
console.log(`Email:    ${email}`);
console.log(`Password: ${password}`);
console.log(`MFA code: ${mfaCode} (or 000000 if DEV_MFA_BYPASS_CODE is set)`);
if (setup.secret) {
  console.log(`MFA secret (dev): ${setup.secret}`);
}
console.log('Next: acknowledge HIPAA notice in app, then sign in with these credentials.');
