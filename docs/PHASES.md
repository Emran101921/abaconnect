# BloomOra – Phase Deliverables Map

## Phase 0 – Compliance foundation
- [x] `AuditLog`, `HipaaConsent`, `DocumentAccessLog` models
- [x] `ComplianceModule` + `AuditModule`
- [x] Global JWT guard, helmet, throttling
- [x] `docs/hipaa/README.md`
- [x] Security e2e test skeleton (`api/test/security/`)

## Phase 1 – MVP marketplace
- [x] Auth (register/login/refresh) with bcrypt + JWT
- [x] Parent, Child, Therapist profiles (Prisma + REST)
- [x] Appointments module
- [x] Matching engine (`POST /matching/discover`, `/matching/score`)
- [x] Flutter role-based UI (parent, therapist, agency, admin)

## Phase 2 – Clinical & operations
- [x] Screening templates + responses
- [x] Documents module (S3-ready metadata)
- [x] Sessions, SOAP notes, progress notes, treatment plans
- [x] Agency / agency-therapist links
- [x] EVV fields on sessions

## Phase 3 – Payments & insurance
- [x] Stripe service + Payment model
- [x] Payouts, Insurance claims models
- [x] Analytics snapshots module

## Phase 4 – Advanced
- [x] Telehealth session model + Flutter screen
- [x] GPS `LocationEvent` model + module
- [x] AI module (stub endpoints for SOAP/matching assist)
- [x] Reviews, badges, complaints, disputes
- [x] Multi-tenant `Tenant` with branding JSON
- [x] Terraform AWS skeleton, Docker, GitHub CI

## Production follow-ups (manual)
- Execute BAAs and AWS HIPAA account setup
- [x] Configure Stripe webhooks (`STRIPE_WEBHOOK_SECRET`, `POST /api/v1/webhooks/stripe`)
- [x] Telehealth vendor integration (Daily/Twilio/local via `TELEHEALTH_VENDOR`)
- [x] MFA TOTP (`/auth/mfa/*`, login challenge)
- [x] Password reset email (`SMTP_*` or dev log)
- [x] Parent appointment reschedule
- WebAuthn MFA (optional upgrade)
- Field-level encryption service for PHI columns
- [x] 837 claim assembly + stub generator + clearinghouse adapter (stub vendor)
- Production clearinghouse integration for live 837/835 exchange
- Load testing for 100k+ users
