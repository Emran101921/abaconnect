# ABAConnect – Phase Deliverables Map

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
- Wire telehealth vendor SDK (Daily/Twilio)
- Enable MFA (TOTP/WebAuthn)
- Field-level encryption service for PHI columns
- Clearinghouse integration for 837/835 claims
- Load testing for 100k+ users
