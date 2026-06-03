# ABAConnect

HIPAA-oriented therapy marketplace connecting parents with licensed providers (ABA, Speech, OT, PT, and related services).

## Monorepo structure

| Path | Description |
|------|-------------|
| `apps/mobile/` | Flutter 3.x (iOS, Android, Web) |
| `api/` | NestJS 10 – GraphQL + REST, Prisma, Redis queues |
| `infra/terraform/` | AWS HIPAA-eligible infrastructure (skeleton) |
| `infra/docker/` | Container definitions |
| `docs/hipaa/` | Compliance policies and runbooks |

## Phases delivered in this repo

| Phase | Scope |
|-------|--------|
| **0** | Audit logging, HIPAA consent model, compliance module, security middleware |
| **1** | Auth, parent/child profiles, therapist profiles, appointments, matching API |
| **2** | Screenings, documents, sessions, SOAP notes, EVV fields, agency links |
| **3** | Payments (Stripe), insurance claims model, analytics snapshots |
| **4** | Telehealth, GPS tracking, AI stubs, badges, reviews, multi-tenant `Tenant` |

## Quick start

### Prerequisites

- Node.js 20+
- Flutter 3.x
- PostgreSQL 16+ and Redis 7+ (or Docker)

### 1. Database & API

```bash
cd api
cp .env.example .env
# Edit DATABASE_URL, JWT_SECRET, REDIS_HOST

npm install
npx prisma migrate dev --name init
npm run start:dev
```

API: `http://localhost:3000/api/v1`  
GraphQL: `http://localhost:3000/graphql`

### 2. Flutter

```bash
cd apps/mobile
flutter pub get
flutter run -d chrome   # web
flutter run             # mobile
```

### 3. Docker (required for local DB unless you have Postgres)

```bash
docker compose up -d postgres redis
cd api && npx prisma migrate deploy && npx prisma db seed
```

### GraphQL (parent booking)

With a parent JWT (`parent@demo.local` / `Parent123!` after seed):

```graphql
query {
  myChildren { id firstName lastName }
  recommendedTherapists(input: { therapyType: ABA }) {
    id ratingAverage matchScore
    user { firstName lastName }
  }
}

mutation {
  bookAppointment(input: {
    childId: "00000000-0000-4000-8000-000000000001"
    therapistId: "<therapist-id-from-query>"
    therapyType: ABA
    scheduledStart: "2026-06-10T14:00:00.000Z"
    scheduledEnd: "2026-06-10T15:00:00.000Z"
  }) { id status }
}
```

### Flutter + API

```bash
# Terminal 1 – API
cd api && npm run start:dev

# Terminal 2 – Flutter Web
cd apps/mobile && flutter run -d chrome
```

Demo logins (after seed):

| Role | Email | Password |
|------|-------|----------|
| Parent | `parent@demo.local` | `Parent123!` |
| Therapist | `therapist@demo.local` | `Therapist123!` |
| Agency | `agency@demo.local` | `Agency123!` |
| Admin | `admin@abaconnect.local` | `Admin123!` |

Health check: `GET http://localhost:3000/api/v1/health`

**REST:** `GET /api/v1/auth/me` (Bearer token) returns profile + `parentId` / `therapistId`.

**GraphQL parent:** booking, children, reviews, screening, messages, payments, telehealth, documents, notifications, insurance, consent, complaints.

**GraphQL therapist:** profile, appointments, sessions, SOAP, EVV (`recordEvvCheckIn`), AI SOAP assist (`suggestSoapNote`).

**GraphQL admin:** dashboard, users, verify therapists, audit logs, complaints (`adminComplaints`, `resolveComplaint`), payment disputes (`adminDisputes`, `resolvePaymentDispute`), payouts (`adminPayouts`, `markPayoutPaid`).

**GraphQL agency:** `agencyDashboard`, `agencyTherapists`.

**Payments & billing (Flutter):** Parents use **Payments** → pay session (Stripe Checkout when `STRIPE_SECRET_KEY` is set), mark paid in demo, sync status, open disputes. Therapists use **Payouts**. Admins resolve payment disputes and mark payouts paid on the dashboard.

**Stripe webhooks:** `POST /api/v1/webhooks/stripe` with raw body and `STRIPE_WEBHOOK_SECRET` (use Stripe CLI: `stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe`).

**Booking:** Parents can book **weekly recurring** sessions (2–12 weeks). **Review prompts** appear on the parent home after completed sessions.

**Admin:** Review moderation (publish/hide). **Agency:** Invite unlinked therapists to the roster.

**Appointments:** Therapists **confirm/decline** `REQUESTED` visits; booking sends in-app notifications to both parties. **Sessions:** Therapists mark **Complete** to notify parents for reviews.

**Password reset:** `POST /api/v1/auth/forgot-password` (dev returns `resetToken`), then `POST /api/v1/auth/reset-password`. Flutter: **Forgot password?** on login. With `SMTP_*` set, reset links are emailed (otherwise logged to the API console).

**MFA (TOTP):** `POST /api/v1/auth/mfa/setup`, `/mfa/enable`, `/login/mfa`. Flutter **Security** screen (parent/therapist home).

**Telehealth vendors:** `TELEHEALTH_VENDOR=local|daily|twilio` plus `DAILY_API_KEY` or Twilio credentials. Rooms store `vendor` on `TelehealthSession`.

**Reschedule:** GraphQL `rescheduleAppointment` — parent **My Appointments** → menu → Reschedule.

**Production Docker:**

```bash
cp api/.env.example api/.env   # set JWT_SECRET, POSTGRES_PASSWORD, STRIPE keys, APP_URL
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec api npx prisma db seed
```

### Therapist SOAP workflow (Flutter)

1. Sign in as **Therapist demo** (`therapist@demo.local` / `Therapist123!`)
2. Open **Appointments** → tap **Start session & document** on a confirmed visit
3. Open **Session Notes** → tap a session → fill SOAP → **Save**

One-command dev (Docker + API + Flutter web):

```bash
chmod +x scripts/dev.sh && npm run dev
```

## Environment variables

See `api/.env.example` and `infra/docker/.env.example`.

## HIPAA note

This codebase provides **technical safeguards** (encryption hooks, audit logs, RBAC, consent records). Production HIPAA compliance also requires organizational policies, BAAs with vendors, risk assessments, and penetration testing. See `docs/hipaa/`.

## License

Proprietary – All rights reserved.
