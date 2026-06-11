/**
 * Dev-only: print the current 6-digit TOTP for seeded demo accounts.
 * Parent, therapist, and agency demo users share the seed MFA secret.
 *
 * Usage: npm run demo:mfa-code
 */
import { createGuardrails } from '@otplib/core';
import { generateSync } from 'otplib';

const DEMO_MFA_SECRET = 'JBSWY3DPEHPK3PXP';
const guardrails = createGuardrails({ MIN_SECRET_BYTES: 10 });

const code = generateSync({ secret: DEMO_MFA_SECRET, guardrails });
const expiresIn = 30 - (Math.floor(Date.now() / 1000) % 30);

console.log(code);
console.error(
  `Demo MFA code (expires in ~${expiresIn}s). Or set DEV_MFA_BYPASS_CODE in api/.env.`,
);
