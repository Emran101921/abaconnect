#!/usr/bin/env bash
# Smoke-test re-applied features on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"

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
  local email="$1" password="$2"
  curl -sf -X POST "$API/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    -H 'x-device-id: smoke-ci-device' \
    -H 'x-device-model: CI smoke runner' \
    -H 'x-device-platform: ci' \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); \
assert not d.get('requiresMfa'), 'MFA challenge — seed smoke-ci-device as trusted'; \
print(d['accessToken'])"
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
PARENT=$(login parent@demo.local 'Parent123!')
PD=$(gql "$PARENT" 'query { parentDashboard { childrenCount upcomingAppointments appointmentsToday pendingReviews onboardingStepsCompleted onboardingStepsTotal hasChild hasScreening hasBookedTherapist } }')
check "parentDashboard query" "d.get('data',{}).get('parentDashboard') is not None" "$PD"
check "parentDashboard childrenCount >= 0" "d['data']['parentDashboard']['childrenCount'] >= 0" "$PD"
check "parentDashboard onboarding fields" "'onboardingStepsCompleted' in d['data']['parentDashboard']" "$PD"

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
AD=$(gql "$AGENCY" 'query { agencyDashboard { therapistCount activeClients appointmentsToday pendingTherapists } agencyUpcomingAppointments { id childName therapistName locationType } }')
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
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
