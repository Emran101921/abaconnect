# HIPAA Compliance Documentation (BloomOra)

Last updated: June 2026 — reflects **implemented** controls in this repo, not aspirational claims.

## Organizational requirements (outside codebase)

- Designate **Privacy Officer** and **Security Officer**
- Complete annual **risk assessment** and remediation plan
- Workforce **HIPAA training** and sanction policy
- Signed **BAAs** with: AWS, Stripe, telehealth vendor, SMS/email providers, AI vendor (if PHI used)
- **Incident response** and breach notification procedures (60-day rule)
- **Business continuity** and disaster recovery tested annually

## Technical safeguards — implemented

| Safeguard | Implementation | Key files |
|-----------|----------------|-----------|
| Access control | JWT + RBAC (`UserRole`), tenant Prisma extension, `TenantContextInterceptor` | `jwt.strategy.ts`, `tenant-prisma.extension.ts`, `roles.guard.ts` |
| Audit controls | Append-only `AuditLog`; PHI read logging via `PhiAuditService`; document access logs | `audit.service.ts`, `phi-audit.service.ts` |
| Security events | `SecurityEvent` table; login failures, lockouts, breach queries | `security-event.service.ts`, `GET /security/events` |
| Integrity | Prisma transactions; screening template versioning | `schema.prisma` |
| Transmission security | TLS required in prod; Helmet; CORS allowlist (`CORS_ORIGINS`) | `main.ts`, `api_constants.dart` |
| Encryption at rest | S3 SSE-KMS for documents (prod); AES-GCM for local dev + message bodies when `PHI_ENCRYPTION_KEY` set; MFA secrets encrypted | `s3-document.storage.ts`, `field-crypto.util.ts`, `mfa.service.ts` |
| Authentication | bcrypt; MFA (TOTP); account lockout (5 failures → 15 min); refresh token store + `tokenVersion` revocation | `auth.service.ts`, `refresh-token.service.ts` |
| Session management | Short-lived JWT; 15-min mobile idle logout; server-side logout revokes refresh tokens | `session_idle_guard.dart`, `auth.service.ts` |
| Minimum necessary | GraphQL role-scoped resolvers; legacy REST PHI scaffolds return 403 | `block-scaffold-rest.guard.ts` |
| HIPAA consent | Server `HipaaConsentInterceptor` + mobile router gate; `HipaaConsent` records | `hipaa-consent.interceptor.ts`, `consent_gate_provider.dart` |
| PHI access accounting | Patient-facing report (§164.528) | `GET /compliance/me/phi-access-report` |
| Rate limiting | Global `ThrottlerGuard`; strict limits on auth endpoints | `app.module.ts`, `auth.controller.ts` |
| Push content policy | Generic push body only (no PHI in FCM payload) | `notifications.service.ts` |
| Clinical screen protection | Screenshot/recording block on PHI screens (mobile) | `secure_clinical_scope.dart` |

## Consent & legal artifacts

- `HipaaConsent` — versioned grants/revocations (`compliance.service.ts`, GraphQL `grantConsent` / `revokeConsent`)
- Agency `baaSignedAt`, `baaDocumentKey` on `Agency` model; admin mutation `setAgencyBaaSigned`
- Telehealth `recordingConsentGranted`, `recordingConsentAt`, `recordingConsentByUserId` on `TelehealthSession`; required when `TELEHEALTH_RECORDING_ENABLED=true`

## Data retention

- Policy constants: 7 years clinical, 6 years billing (`ComplianceService.getRetentionPolicy()`)
- Status summary per tenant (`summarizeRetentionStatus`) — **no automated purge job yet**

## Breach notification workflow

1. Detect via monitoring / user report → `Complaint` or security channel
2. Contain — `POST /auth/logout` revokes tokens; `isActive=false` disables accounts
3. Assess scope — `GET /security/events`, `GET /audit` (tenant-scoped, append-only)
4. Legal review → notify affected users and HHS if required

## Production environment variables

```
JWT_SECRET, JWT_REFRESH_SECRET, JWT_RESET_SECRET  (≥16 chars)
PHI_ENCRYPTION_KEY
CORS_ORIGINS=https://your-app.example.com
AWS_S3_BUCKET, AWS_KMS_KEY_ID, AWS_REGION          (documents — no local uploads/ in prod)
```

Run migrations before deploy:

```bash
cd api && npx prisma migrate deploy
```

## June 2026 security architecture expansion

| Area | Implementation |
|------|----------------|
| Extended RBAC | `BILLING_STAFF`, `COMPLIANCE_AUDITOR`, `SUPPORT_STAFF` + `permissions.ts` matrix |
| Permissions guard | `@Permissions()` + `PermissionsGuard` on admin security routes |
| Audit enrichment | `actorRole`, `patientId`, `success`, `deviceId`, `fieldChanges` (redacted) |
| Claim security | `ClaimSecurityService` — lock on submit, edit history, duplicate detection, resubmit |
| Provider onboarding gate | `ProviderOnboardingService` blocks therapist PHI until approved |
| Legal documents | `ComplianceDocument` + acceptance tracking with IP/user agent |
| Admin security dashboard | `GET /admin/security/dashboard`, user disable / MFA reset |
| PHI in notifications | Generic in-app + push bodies for messages |
| Hosting guide | `docs/hipaa/HOSTING.md` |

## Known gaps (not yet in code)

- Postgres RLS (app-layer tenant middleware only)
- Field-level encryption for all PHI columns in Postgres (expanded but not exhaustive)
- Email verification gate (`emailVerifiedAt` unused)
- Automated retention purge / legal-hold scheduler
- WORM / immutable audit storage backend
- Certificate pinning and jailbreak detection (mobile)
- AI de-identification pipeline
- Pen test and full BAA execution with subprocessors

## Pre-production checklist

- [ ] Penetration test
- [ ] BAA executed with all subprocessors
- [ ] AWS HIPAA account configuration
- [ ] Rotate all secrets; no `change-me` placeholders
- [ ] Enable CloudTrail, GuardDuty, VPC flow logs
- [ ] Document encryption key rotation procedure
- [ ] `npx prisma migrate deploy` on staging/production
- [ ] API e2e + Flutter tests green in CI

## Cursor remediation tasks (T1–T22)

| Task | Status | Notes |
|------|--------|-------|
| T1 Audit append-only + admin tenant scope | Done | `audit.controller.ts`, `audit.service.ts` |
| T2–T4 REST PHI scaffolds blocked | Done | `BlockScaffoldRestGuard` on controllers |
| T5 Register role restriction | Done | `auth.dto.ts`, `resolvePublicRegisterRole()` |
| T6 isActive + DB role on JWT | Done | `jwt.strategy.ts` |
| T7 ThrottlerGuard global | Done | `app.module.ts` |
| T8 CORS allowlist | Done | `main.ts` |
| T9 Demo payment disabled in prod | Done | `payments.resolver.ts` |
| T10 Complaints use `@CurrentUser()` | Done | `complaints.controller.ts` |
| T11 Admin tenant checks | Done | `admin.service.ts`, resolvers |
| T12 Document access tightened | Done | `documents.service.ts` |
| T13 Mail dev logging redacted | Done | `mail.service.ts` (no reset URL in logs) |
| T14 Stripe webhook fail-closed | Done | `stripe-webhooks.controller.ts` |
| T15 Demo creds `kDebugMode` only | Done | `login_screen.dart` |
| T16 HIPAA consent router gate | Done | `app_router_redirect.dart` |
| T17 Screening wrong-child fix | Done | `screening_screen.dart` |
| T18 HTTPS-only release builds | Done | `api_constants.dart` |
| T19 PHI read audit wiring | Done | `phi-audit.service.ts` + services |
| T20 Mobile refresh token flow | Done | `api_client.dart`, `auth_repository.dart` |
| T21 HIPAA e2e tests | Done | `test/app.e2e-spec.ts` (10 tests) |
| T22 Document actual vs claimed safeguards | Done | This file |
