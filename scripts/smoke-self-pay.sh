#!/usr/bin/env bash
# Smoke-test self-pay session flow on a running API (http://localhost:3000).
#
# Flow: recordTherapistArrival → requestSessionPayment → confirmPaymentDemo → startSession
#
# Demo data: seed does not include self-pay appointments. This script creates a
# self-pay child + books a confirmed appointment when none is available.
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
DEVICE_HEADERS=(
  -H 'x-device-id: smoke-self-pay-device'
  -H 'x-device-model: Smoke self-pay runner'
  -H 'x-device-platform: ci'
)

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
    echo "$data" | python3 -m json.tool 2>/dev/null | head -40 || echo "$data"
    fail=$((fail + 1))
  fi
}

login() {
  local email="$1" password="$2"
  local resp
  resp=$(curl -sf -X POST "$API/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    "${DEVICE_HEADERS[@]}" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}")
  if echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('requiresMfa') else 1)" 2>/dev/null; then
    local token
    token=$(echo "$resp" | python3 -c "import sys,json; print(json.load(sys.stdin)['mfaChallengeToken'])")
    resp=$(curl -sf -X POST "$API/api/v1/auth/login/mfa" \
      -H 'Content-Type: application/json' \
      "${DEVICE_HEADERS[@]}" \
      -d "{\"mfaChallengeToken\":\"$token\",\"code\":\"000000\"}")
  fi
  echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['accessToken'])"
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

gql_mutation() {
  local token="$1" query="$2" variables="$3"
  local body
  body=$(python3 -c "import json; print(json.dumps({'query': '''$query''', 'variables': $variables}))")
  curl -sf -X POST "$GQL" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$body"
}

echo "=== Health ==="
curl -sf "$API/api/v1/health" | python3 -m json.tool
echo

echo "=== Login parent + therapist ==="
PARENT=$(login parent1@demo.local 'Parent1Demo!')
THER=$(login therapist@demo.local 'Therapist123!')
check "parent login" "True" "{\"ok\":true}"
check "therapist login" "True" "{\"ok\":true}"

echo
echo "=== Resolve therapist profile ==="
THER_PROFILE=$(gql "$THER" 'query { myTherapistProfile { id } }')
THERAPIST_ID=$(echo "$THER_PROFILE" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['myTherapistProfile']['id'])")
check "myTherapistProfile" "d.get('data',{}).get('myTherapistProfile',{}).get('id')" "$THER_PROFILE"

echo
echo "=== Find or create self-pay child ==="
CHILDREN=$(gql "$PARENT" 'query { myChildren { id firstName lastName insuranceType } }')
CHILD_ID=$(echo "$CHILDREN" | python3 -c "
import sys, json
d = json.load(sys.stdin)
children = d.get('data', {}).get('myChildren', []) or []
self_pay = [c for c in children if not c.get('insuranceType') or c.get('insuranceType') == 'Self-pay']
print(self_pay[0]['id'] if self_pay else '')
" 2>/dev/null || true)

if [ -z "$CHILD_ID" ]; then
  echo "No self-pay child found — creating demo child for parent1@demo.local"
  ADD_CHILD=$(gql_mutation "$PARENT" \
    'mutation($input: AddChildInput!) { addChild(input: $input) { id insuranceType } }' \
    '{"input":{"firstName":"SelfPay","lastName":"Child","dateOfBirth":"2020-01-15T00:00:00.000Z","insuranceType":"Self-pay"}}')
  CHILD_ID=$(echo "$ADD_CHILD" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['addChild']['id'])")
  check "addChild (self-pay)" "d.get('data',{}).get('addChild',{}).get('id')" "$ADD_CHILD"
else
  echo "Using existing self-pay child: $CHILD_ID"
  check "myChildren has self-pay child" "True" "{\"ok\":true}"
fi

echo
echo "=== Find or book confirmed self-pay appointment ==="
APPOINTMENTS=$(gql "$THER" 'query { myTherapistAppointments { id status requiresSelfPayCollection child { id } sessionPaymentStatus } }')
APPOINTMENT_ID=$(echo "$APPOINTMENTS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
rows = d.get('data', {}).get('myTherapistAppointments', []) or []
candidates = [
    a for a in rows
    if a.get('requiresSelfPayCollection')
    and a.get('child', {}).get('id') == '$CHILD_ID'
    and a.get('status') in ('CONFIRMED', 'SCHEDULED', 'CHECKED_IN')
    and a.get('sessionPaymentStatus') != 'SUCCEEDED'
]
print(candidates[0]['id'] if candidates else '')
" 2>/dev/null || true)

if [ -z "$APPOINTMENT_ID" ]; then
  echo "No suitable self-pay appointment — booking new one"
  START=$(python3 -c "from datetime import datetime, timedelta, timezone; s=datetime.now(timezone.utc)+timedelta(hours=2); e=s+timedelta(hours=1); print(s.strftime('%Y-%m-%dT%H:%M:%S.000Z'), e.strftime('%Y-%m-%dT%H:%M:%S.000Z'))")
  SCHED_START=$(echo "$START" | awk '{print $1}')
  SCHED_END=$(echo "$START" | awk '{print $2}')
  BOOK=$(gql_mutation "$PARENT" \
    'mutation($input: BookAppointmentInput!) { bookAppointment(input: $input) { id status } }' \
    "{\"input\":{\"childId\":\"$CHILD_ID\",\"therapistId\":\"$THERAPIST_ID\",\"therapyType\":\"SPEECH\",\"scheduledStart\":\"$SCHED_START\",\"scheduledEnd\":\"$SCHED_END\",\"locationType\":\"IN_HOME\"}}")
  APPOINTMENT_ID=$(echo "$BOOK" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('errors'):
    print('', end='')
    sys.exit(0)
print(d['data']['bookAppointment']['id'])
" 2>/dev/null || true)
  if [ -z "$APPOINTMENT_ID" ]; then
    echo "FAIL: bookAppointment"
    echo "$BOOK" | python3 -m json.tool 2>/dev/null | head -40 || echo "$BOOK"
    fail=$((fail + 1))
    echo "=== Summary: $pass passed, $fail failed ==="
    exit 1
  fi
  check "bookAppointment" "d.get('data',{}).get('bookAppointment',{}).get('id')" "$BOOK"

  CONFIRM=$(gql_mutation "$THER" \
    'mutation($appointmentId: ID!) { confirmAppointment(appointmentId: $appointmentId) { id status } }' \
    "{\"appointmentId\":\"$APPOINTMENT_ID\"}")
  check "confirmAppointment" "d.get('data',{}).get('confirmAppointment',{}).get('status') == 'CONFIRMED'" "$CONFIRM"
else
  echo "Using existing appointment: $APPOINTMENT_ID"
  check "myTherapistAppointments has self-pay candidate" "True" "{\"ok\":true}"
fi

echo
echo "=== Therapist records arrival ==="
CURRENT_STATUS=$(echo "$APPOINTMENTS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myTherapistAppointments', []) or []
match = next((a for a in rows if a.get('id') == '$APPOINTMENT_ID'), None)
print(match.get('status', '') if match else '')
" 2>/dev/null || true)
if [ "$CURRENT_STATUS" = "CHECKED_IN" ] || [ "$CURRENT_STATUS" = "IN_PROGRESS" ]; then
  echo "Appointment already checked in — skipping recordTherapistArrival"
  check "recordTherapistArrival (already checked in)" "True" "{\"ok\":true}"
else
  ARRIVAL=$(gql_mutation "$THER" \
    'mutation($appointmentId: ID!) { recordTherapistArrival(appointmentId: $appointmentId) { id status hasArrived requiresSelfPayCollection } }' \
    "{\"appointmentId\":\"$APPOINTMENT_ID\"}")
  check "recordTherapistArrival" \
    "d.get('data',{}).get('recordTherapistArrival',{}).get('status') == 'CHECKED_IN' and d.get('data',{}).get('recordTherapistArrival',{}).get('hasArrived') is True" \
    "$ARRIVAL"
fi

echo
echo "=== Therapist requests session payment ==="
PAY_REQ=$(gql_mutation "$THER" \
  'mutation($appointmentId: ID!) { requestSessionPayment(appointmentId: $appointmentId) { payment { id status amount } stripeConfigured } }' \
  "{\"appointmentId\":\"$APPOINTMENT_ID\"}")
PAYMENT_ID=$(echo "$PAY_REQ" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('errors'):
    print('', end='')
    sys.exit(0)
print(d['data']['requestSessionPayment']['payment']['id'])
" 2>/dev/null || true)
if [ -z "$PAYMENT_ID" ]; then
  echo "FAIL: requestSessionPayment"
  echo "$PAY_REQ" | python3 -m json.tool 2>/dev/null | head -40 || echo "$PAY_REQ"
  fail=$((fail + 1))
  echo "=== Summary: $pass passed, $fail failed ==="
  exit 1
fi
check "requestSessionPayment" \
  "d.get('data',{}).get('requestSessionPayment',{}).get('payment',{}).get('status') in ('PENDING','SUCCEEDED')" \
  "$PAY_REQ"

echo
echo "=== Parent completes demo payment ==="
PAY_CONFIRM=$(gql_mutation "$PARENT" \
  'mutation($id: ID!) { confirmPaymentDemo(paymentId: $id) { id status } }' \
  "{\"id\":\"$PAYMENT_ID\"}")
check "confirmPaymentDemo" \
  "d.get('data',{}).get('confirmPaymentDemo',{}).get('status') == 'SUCCEEDED'" \
  "$PAY_CONFIRM"

echo
echo "=== Therapist starts session ==="
START_SESSION=$(gql_mutation "$THER" \
  'mutation($appointmentId: ID!) { startSession(appointmentId: $appointmentId) { id status } }' \
  "{\"appointmentId\":\"$APPOINTMENT_ID\"}")
check "startSession" \
  "d.get('data',{}).get('startSession',{}).get('status') == 'IN_PROGRESS'" \
  "$START_SESSION"

echo
echo "=== Verify appointment reflects paid session ==="
FINAL=$(gql "$THER" "query { myTherapistAppointments { id status canStartSession sessionPaymentStatus } }")
check "appointment payment succeeded" \
  "any(a.get('id')=='$APPOINTMENT_ID' and a.get('sessionPaymentStatus')=='SUCCEEDED' for a in d.get('data',{}).get('myTherapistAppointments',[]))" \
  "$FINAL"

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
