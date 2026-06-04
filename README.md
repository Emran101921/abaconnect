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

**GraphQL agency:** `agencyDashboard`, `agencyTherapists`, `inviteAgencyTherapist`, `removeAgencyTherapist`.

**Agency operations hub (Flutter):** Overview stats plus **Operations** links — roster, invites, analytics, appointments overview (`/agency/*`).

**Payments & billing (Flutter):** Parents use **Payments** → pay session (Stripe Checkout when `STRIPE_SECRET_KEY` is set), mark paid in demo, sync status, open disputes. Therapists use **Payouts**. Admins resolve payment disputes and mark payouts paid on the dashboard.

**Stripe webhooks:** `POST /api/v1/webhooks/stripe` with raw body and `STRIPE_WEBHOOK_SECRET` (use Stripe CLI: `stripe listen --forward-to localhost:3000/api/v1/webhooks/stripe`).

**Booking:** Parents can book **weekly recurring** sessions (2–12 weeks). **Review prompts** appear on the parent home after completed sessions.

**Admin:** Review moderation (publish/hide). **Agency:** Invite unlinked therapists to the roster.

**Appointments:** Therapists **confirm/decline** `REQUESTED` visits; booking sends in-app notifications to both parties. **Sessions:** Therapists mark **Complete** to notify parents for reviews.

**Password reset:** `POST /api/v1/auth/forgot-password` (dev returns `resetToken`), then `POST /api/v1/auth/reset-password`. Flutter: **Forgot password?** on login. With `SMTP_*` set, reset links are emailed (otherwise logged to the API console).

**MFA (TOTP):** `POST /api/v1/auth/mfa/setup`, `/mfa/enable`, `/login/mfa`. Flutter **Security** screen (parent/therapist home).

**Telehealth vendors:** `TELEHEALTH_VENDOR=local|daily|twilio` plus `DAILY_API_KEY` or Twilio credentials. Rooms store `vendor` on `TelehealthSession`.

**Reschedule & cancel:** GraphQL `rescheduleAppointment` / `cancelAppointment` — parent **My Appointments** → menu.

**Booking location:** Parents choose session location (in-home, clinic, telehealth, etc.) when booking.

**Push device registry:** `POST /api/v1/auth/device` (Bearer) stores tokens in `user_devices` for future FCM/APNs (Flutter registers on login).

**Admin insurance:** `adminInsuranceClaims` + `updateInsuranceClaim` — approve/deny/mark paid on the admin dashboard.

**Parent profile:** `myParentProfile` / `updateParentProfile` — address, emergency contact, insurance on **My Profile**.

**Session history:** `mySessionHistory` — parents view completed sessions (no SOAP content).

**Therapist cancel:** `cancelAppointmentAsTherapist` — cancel confirmed/scheduled visits with parent notification.

**Notifications:** `markAllNotificationsRead` — **Mark all read** on the notifications screen.

**Admin analytics:** `tenantAnalytics` — appointments (7d), sessions, revenue, children on the admin dashboard.

**Admin users:** `setUserActive` — activate/deactivate accounts on **Users** (platform admins protected).

**Agency roster:** `removeAgencyTherapist` — remove therapist from agency roster (menu on roster card).

**Agency appointments:** `agencyUpcomingAppointments` — 14-day schedule on **Appointments** under the agency hub.

**Document upload:** `POST /api/v1/documents/upload` (multipart, Bearer) stores files locally under `uploads/` (Docker volume `api_uploads`). Flutter **Documents** → pick file, optional child link (parents), download or delete via menu. GraphQL `deleteMyDocument` removes file and metadata.

**Therapist calendar export:** `GET /api/v1/therapist/appointments/ical` — upcoming visits as `.ics` from **My Appointments** (calendar icon).

**Messaging:** Parents pick a therapist to start a thread (`startTherapistConversation`). Therapists message parents from appointment contacts (`myTherapistParentContacts`, `startParentConversation`). New messages create in-app notifications for the other participant.

**Notifications:** `myNotifications` includes `actionType`, `threadId`, `appointmentId`, and `sessionId` — tap to open messages, appointments, or reviews. Parent and therapist homes use **Overview** + **Operations** hubs.

**Children:** Parents can **edit child** names and **date of birth** on **My Children** (date picker in add/edit dialog).

**Parent calendar export:** `GET /api/v1/parent/appointments/ical` (Bearer, `PARENT` role) — upcoming visits as `.ics`. Flutter **My Appointments** → calendar icon (web: browser download; mobile: temp file).

**Telehealth from appointments:** Parents with `TELEHEALTH` visits see **Join telehealth** on **My Appointments**.

**Unread badges:** `myUnreadNotificationCount` — badge on parent/therapist home **Notifications**.

**Production Docker:**

```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
# First-time demo data:
docker compose -f docker-compose.prod.yml exec api npx prisma db seed
```

Or manually:

```bash
cp api/.env.example api/.env   # set JWT_SECRET, STRIPE keys, APP_URL
export POSTGRES_PASSWORD=abaconnect_dev
docker compose -f docker-compose.prod.yml up -d --build
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
