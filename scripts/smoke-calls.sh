#!/usr/bin/env bash
# Smoke-test call integration on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
SMOKE_DEVICE_ID='smoke-calls-device'
SMOKE_DEVICE_MODEL='Smoke calls runner'
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
    echo "$data" | python3 -m json.tool 2>/dev/null | head -30 || echo "$data"
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

gql_mutation() {
  local token="$1" query="$2" variables="$3"
  local body
  body=$(python3 -c "import json; print(json.dumps({'query': '''$query''', 'variables': $variables}))")
  curl -sf -X POST "$GQL" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$body"
}

auth_me_id() {
  local token="$1"
  curl -sf "$API/api/v1/auth/me" \
    -H "Authorization: Bearer $token" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))"
}

ensure_call_authorized_appointment() {
  local parent_token="$1" therapist_token="$2" parent_user_id="$3"
  local has_apt
  has_apt=$(gql "$therapist_token" 'query { myTherapistAppointments { id parentUserId status } }' | python3 -c "
import sys, json
parent_id = '''$parent_user_id'''
rows = json.load(sys.stdin).get('data', {}).get('myTherapistAppointments') or []
print('yes' if any(
    a.get('parentUserId') == parent_id and a.get('status') not in ('CANCELLED', 'NO_SHOW')
    for a in rows
) else '')
")
  if [[ -n "$has_apt" ]]; then
    echo "INFO: therapist-parent appointment already exists for calls"
    return 0
  fi

  echo "INFO: booking demo appointment so therapist can call parent..."
  local therapist_id child_id sched_start sched_end book appointment_id payment_id

  therapist_id=$(gql "$therapist_token" 'query { myTherapistProfile { id } }' \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['myTherapistProfile']['id'])")

  child_id=$(gql "$parent_token" 'query { myChildren { id } }' | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myChildren') or []
print(rows[0]['id'] if rows else '')
")
  if [[ -z "$child_id" ]]; then
    child_id=$(gql_mutation "$parent_token" \
      'mutation($input: AddChildInput!) { addChild(input: $input) { id } }' \
      '{"input":{"firstName":"Call","lastName":"Smoke","dateOfBirth":"2020-06-01T00:00:00.000Z","insuranceType":"Self-pay","zipCode":"11201"}}' \
      | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['addChild']['id'])")
  fi

  read -r sched_start sched_end < <(python3 -c "from datetime import datetime, timedelta, timezone; s=datetime.now(timezone.utc)+timedelta(hours=3); e=s+timedelta(hours=1); print(s.strftime('%Y-%m-%dT%H:%M:%S.000Z'), e.strftime('%Y-%m-%dT%H:%M:%S.000Z'))")

  book=$(gql_mutation "$parent_token" \
    'mutation($input: BookAppointmentInput!) { bookAppointment(input: $input) { id } }' \
    "{\"input\":{\"childId\":\"$child_id\",\"therapistId\":\"$therapist_id\",\"therapyType\":\"SPEECH\",\"scheduledStart\":\"$sched_start\",\"scheduledEnd\":\"$sched_end\",\"locationType\":\"IN_HOME\"}}")
  appointment_id=$(echo "$book" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('bookAppointment',{}).get('id',''))")
  if [[ -z "$appointment_id" ]]; then
    echo "FAIL: bookAppointment for call setup"
    echo "$book" | python3 -m json.tool 2>/dev/null | head -20 || echo "$book"
    return 1
  fi

  payment_id=$(gql_mutation "$parent_token" \
    'mutation($appointmentId: ID!) { confirmAppointmentAsParent(appointmentId: $appointmentId) { paymentId } }' \
    "{\"appointmentId\":\"$appointment_id\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('confirmAppointmentAsParent',{}).get('paymentId') or '')")
  if [[ -n "$payment_id" ]]; then
    gql_mutation "$parent_token" \
      'mutation($id: ID!) { confirmPaymentDemo(paymentId: $id) { id status } }' \
      "{\"id\":\"$payment_id\"}" >/dev/null
  fi
}

echo "=== Call integration smoke test ==="

THER="${SMOKE_THERAPIST_TOKEN:-$(login therapist@demo.local 'Therapist123!')}"
PARENT="${SMOKE_PARENT_TOKEN:-$(login parent1@demo.local 'Parent1Demo!')}"

PARENT_USER_ID=$(auth_me_id "$PARENT")
if [[ -z "$PARENT_USER_ID" ]]; then
  PARENT_USER_ID=$(gql "$THER" 'query { myTherapistAppointments { parentUserId } }' | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myTherapistAppointments') or []
print(next((a['parentUserId'] for a in rows if a.get('parentUserId')), ''))
")
fi
if [[ -z "$PARENT_USER_ID" ]]; then
  echo "FAIL: could not resolve parent user id from auth/me or therapist appointments"
  exit 1
fi

if ! ensure_call_authorized_appointment "$PARENT" "$THER" "$PARENT_USER_ID"; then
  exit 1
fi

echo "INFO: parent user id=$PARENT_USER_ID"

echo
echo "1. Therapist initiates audio call to parent..."
INIT=$(gql "$THER" "mutation { initiateCall(input: { recipientUserId: \"$PARENT_USER_ID\", callType: AUDIO }) { id status joinUrl recipientName } }")
check "initiateCall mutation" "d.get('data',{}).get('initiateCall',{}).get('id')" "$INIT"
CALL_ID=$(echo "$INIT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('initiateCall',{}).get('id',''))")
if [[ -z "$CALL_ID" ]]; then
  echo "=== Summary: $pass passed, $fail failed ==="
  exit 1
fi
echo "INFO: call id=$CALL_ID"

echo
echo "2. Parent sees incoming ringing call..."
RING=$(gql "$PARENT" 'query { incomingRingingCall { id status initiatedByName } }')
check "incomingRingingCall query" "d.get('data',{}).get('incomingRingingCall') is not None" "$RING"
RING_ID=$(echo "$RING" | python3 -c "import sys,json; r=json.load(sys.stdin).get('data',{}).get('incomingRingingCall'); print(r.get('id','') if r else '')")
if [[ "$RING_ID" == "$CALL_ID" ]]; then
  echo "PASS: incomingRingingCall id matches initiated call"
  pass=$((pass + 1))
else
  echo "WARN: incomingRingingCall id=$RING_ID (expected $CALL_ID)"
fi

echo
echo "3. Parent fetches callSession by id..."
SESSION=$(gql "$PARENT" "query { callSession(callSessionId: \"$CALL_ID\") { id status joinUrl } }")
check "callSession query" "d.get('data',{}).get('callSession',{}).get('id') == '$CALL_ID'" "$SESSION"

echo
echo "4. Parent accepts call..."
ACCEPT=$(gql "$PARENT" "mutation { acceptCall(callSessionId: \"$CALL_ID\") { id status joinUrl } }")
check "acceptCall mutation" "d.get('data',{}).get('acceptCall',{}).get('status')" "$ACCEPT"

echo
echo "5. Therapist ends call..."
END=$(gql "$THER" "mutation { endCall(callSessionId: \"$CALL_ID\") { id status durationSeconds } }")
check "endCall mutation" "d.get('data',{}).get('endCall',{}).get('id') == '$CALL_ID'" "$END"

echo
echo "6. Call history for therapist..."
HIST=$(gql "$THER" 'query { callHistory(filter: { limit: 5 }) { id status callType recipientName } }')
check "callHistory query" "isinstance(d.get('data',{}).get('callHistory'), list)" "$HIST"

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
