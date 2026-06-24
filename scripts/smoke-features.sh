#!/usr/bin/env bash
# Smoke-test re-applied features on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
# shellcheck source=smoke-login.sh
source "$(dirname "$0")/smoke-login.sh"

pass=0
fail=0

check() {
  local name="$1"
  local expr="$2"
  local data="$3"
  if echo "$data" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if ($expr) else 1)" 2>/dev/null; then
    echo "PASS: $name"
    pass=$((pass + 1))
  else
    echo "FAIL: $name"
    echo "$data" | python3 -m json.tool 2>/dev/null | head -20 || echo "$data"
    fail=$((fail + 1))
  fi
}

login() {
  smoke_login "$1" "$2"
}

gql() {
  local token="$1" query="$2"
  local body
  body=$(python3 -c "import json; print(json.dumps({'query': '''$query'''}))")
  curl -sf -X POST "$GQL" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$body"
}

echo "=== Health ==="
curl -sf "$API/api/v1/health" | python3 -m json.tool
echo

echo "=== Parent dashboards & messaging ==="
PARENT=$(login parent1@demo.local 'Parent1Demo!')
PD=$(gql "$PARENT" 'query { parentDashboard { childrenCount upcomingAppointments appointmentsToday pendingReviews onboardingStepsCompleted onboardingStepsTotal hasChild hasScreening hasBookedTherapist } }')
check "parentDashboard query" "d.get('data',{}).get('parentDashboard') is not None" "$PD"
check "parentDashboard childrenCount >= 0" "d['data']['parentDashboard']['childrenCount'] >= 0" "$PD"
check "parentDashboard onboarding fields" "'onboardingStepsCompleted' in d['data']['parentDashboard']" "$PD"

PAY_CFG=$(gql "$PARENT" 'query { paymentsConfig { stripeConfigured } }')
check "paymentsConfig query" "'stripeConfigured' in d.get('data',{}).get('paymentsConfig',{})" "$PAY_CFG"

THREADS=$(gql "$PARENT" 'query { myMessageThreads { id hasUnread otherParticipantName } unreadMessageThreadCount }')
check "myMessageThreads query" "isinstance(d.get('data',{}).get('myMessageThreads'), list)" "$THREADS"
check "unreadMessageThreadCount" "'unreadMessageThreadCount' in d.get('data',{})" "$THREADS"

echo
echo "=== Therapist dashboards & sessions ==="
THER=$(login therapist@demo.local 'Therapist123!')
TD=$(gql "$THER" 'query { therapistDashboard { pendingRequests appointmentsToday inProgressSessions pendingDocumentation } }')
check "therapistDashboard query" "d.get('data',{}).get('therapistDashboard') is not None" "$TD"

SESSIONS=$(gql "$THER" 'query { myTherapistSessions { id status child { firstName lastName } soapNote { id } } }')
check "myTherapistSessions query" "isinstance(d.get('data',{}).get('myTherapistSessions'), list)" "$SESSIONS"

APTS=$(gql "$THER" 'query { myTherapistAppointments { id status locationType child { firstName } } }')
check "therapist appointments locationType field" \
  "all('locationType' in a for a in d.get('data',{}).get('myTherapistAppointments',[])) or d.get('data',{}).get('myTherapistAppointments')==[]" "$APTS"

echo
echo "=== Agency & admin ==="
AGENCY=$(login agency@demo.local 'Agency123!')
AD=$(gql "$AGENCY" 'query { agencyDashboard { therapistCount activeClients appointmentsToday pendingTherapists serviceCoordinatorCount activeScCaseload } agencyUpcomingAppointments { id childName therapistName locationType } }')
check "agencyDashboard query" "d.get('data',{}).get('agencyDashboard') is not None" "$AD"
check "agencyUpcomingAppointments query" "isinstance(d.get('data',{}).get('agencyUpcomingAppointments'), list)" "$AD"

ADMIN=$(login admin@abaconnect.local 'Admin123!')
NOTIF=$(gql "$ADMIN" 'query { myNotifications { id title readAt actionType } }')
check "admin notifications query" "isinstance(d.get('data',{}).get('myNotifications'), list)" "$NOTIF"

echo
echo "=== Notifications deep-link fields ==="
PN=$(gql "$PARENT" 'query { myNotifications { id actionType threadId appointmentId sessionId } }')
check "notification actionType fields" \
  "isinstance(d.get('data',{}).get('myNotifications'), list)" "$PN"

echo
echo "=== Telehealth (TELEHEALTH filter data) ==="
PAPTS=$(gql "$PARENT" 'query { myAppointments { id locationType status therapyType } }')
check "parent appointments locationType" \
  "all('locationType' in a for a in d.get('data',{}).get('myAppointments',[])) or d.get('data',{}).get('myAppointments')==[]" "$PAPTS"

TH_COUNT=$(echo "$PAPTS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(sum(1 for a in d.get('data',{}).get('myAppointments',[]) if a.get('locationType')=='TELEHEALTH'))")
echo "INFO: parent TELEHEALTH appointments: $TH_COUNT"

echo
echo "=== Analytics reconciliation ==="
ANALYTICS=$(gql "$ADMIN" 'query { tenantAnalytics { metricKey metricValue } adminClaimsPipeline { summary { paidCount paidAmountTotal } } }')
check "tenantAnalytics claims_paid_total" \
  "any(m.get('metricKey')=='claims_paid_total' for m in d.get('data',{}).get('tenantAnalytics',[]))" "$ANALYTICS"
check "claims pipeline paidAmountTotal" \
  "'paidAmountTotal' in d.get('data',{}).get('adminClaimsPipeline',{}).get('summary',{})" "$ANALYTICS"

echo
echo "=== Service coordinator flows ==="
if bash "$(dirname "$0")/smoke-service-coordinator.sh"; then
  echo "PASS: smoke-service-coordinator.sh"
  pass=$((pass + 1))
else
  echo "FAIL: smoke-service-coordinator.sh"
  fail=$((fail + 1))
fi

echo
echo "=== Marketplace (HIPAA module) ==="
export SMOKE_PARENT_TOKEN="$PARENT"
export SMOKE_THERAPIST_TOKEN="$THER"
export SMOKE_ADMIN_TOKEN="$ADMIN"
export SMOKE_AGENCY_TOKEN="$AGENCY"
# Brief pause — prior scripts may have consumed auth rate-limit budget.
sleep 3
if bash "$(dirname "$0")/smoke-marketplace.sh"; then
  echo "PASS: smoke-marketplace.sh"
  pass=$((pass + 1))
else
  echo "FAIL: smoke-marketplace.sh"
  fail=$((fail + 1))
fi

echo
echo "=== Redesign routes ==="
SC=$(login sc@demo.local 'SC123!')
export SMOKE_PARENT_TOKEN="$PARENT"
export SMOKE_THERAPIST_TOKEN="$THER"
export SMOKE_AGENCY_TOKEN="$AGENCY"
export SMOKE_ADMIN_TOKEN="$ADMIN"
export SMOKE_SC_TOKEN="$SC"
sleep 3
if bash "$(dirname "$0")/smoke-redesign-routes.sh"; then
  echo "PASS: smoke-redesign-routes.sh"
  pass=$((pass + 1))
else
  echo "FAIL: smoke-redesign-routes.sh"
  fail=$((fail + 1))
fi

echo
echo "=== EI billing (NY Medicaid) ==="
BILLING=$(login billing@demo.local 'Billing123!')
export SMOKE_BILLING_TOKEN="$BILLING"
export SMOKE_AGENCY_TOKEN="$AGENCY"
sleep 3
if bash "$(dirname "$0")/smoke-ei-billing.sh"; then
  echo "PASS: smoke-ei-billing.sh"
  pass=$((pass + 1))
else
  echo "FAIL: smoke-ei-billing.sh"
  fail=$((fail + 1))
fi

echo
echo "=== Self-pay session flow ==="
# Brief pause + retry — prior scripts can trip auth rate limits.
sleep 3
self_pay_ok=0
for attempt in 1 2 3; do
  if bash "$(dirname "$0")/smoke-self-pay.sh"; then
    self_pay_ok=1
    break
  fi
  echo "WARN: smoke-self-pay attempt $attempt failed; retrying in ${attempt}0s..."
  sleep $((attempt * 10))
done
if [[ "$self_pay_ok" -eq 1 ]]; then
  echo "PASS: smoke-self-pay.sh"
  pass=$((pass + 1))
else
  echo "FAIL: smoke-self-pay.sh"
  fail=$((fail + 1))
fi

echo
echo "=== Calls integration ==="
export SMOKE_THERAPIST_TOKEN="$THER"
export SMOKE_PARENT_TOKEN="$PARENT"
sleep 3
if bash "$(dirname "$0")/smoke-calls.sh"; then
  echo "PASS: smoke-calls.sh"
  pass=$((pass + 1))
else
  echo "FAIL: smoke-calls.sh"
  fail=$((fail + 1))
fi

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
