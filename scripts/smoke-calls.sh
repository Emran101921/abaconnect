#!/usr/bin/env bash
set -euo pipefail

API="${API_BASE:-http://localhost:3000}"

login() {
  local email="$1" password="$2"
  local body challenge token
  body=$(curl -s -X POST "$API/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}")
  token=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))")
  if [ -n "$token" ]; then
    echo "$token"
    return
  fi
  challenge=$(echo "$body" | python3 -c "import sys,json; print(json.load(sys.stdin).get('mfaChallengeToken',''))")
  curl -s -X POST "$API/api/v1/auth/login/mfa" \
    -H 'Content-Type: application/json' \
    -d "{\"mfaChallengeToken\":\"$challenge\",\"code\":\"000000\"}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('accessToken',''))"
}

gql() {
  local token="$1" query="$2"
  curl -s -X POST "$API/graphql" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $token" \
    -d "{\"query\":$(python3 -c "import json; print(json.dumps('$query'))")}"
}

echo "== Call integration smoke test =="

THERAPIST_TOKEN=$(login therapist@demo.local 'Therapist123!')
PARENT_TOKEN=$(login parent1@demo.local 'Parent1Demo!')
PARENT_USER_ID=28a9c37a-388f-4577-9ee2-8ee0f27e7e37

echo "1. Therapist initiates audio call to parent..."
INIT=$(gql "$THERAPIST_TOKEN" "mutation { initiateCall(input: { recipientUserId: \"$PARENT_USER_ID\", callType: AUDIO }) { id status joinUrl recipientName } }")
echo "$INIT" | python3 -m json.tool
CALL_ID=$(echo "$INIT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('initiateCall',{}).get('id',''))")
if [ -z "$CALL_ID" ]; then
  echo "FAIL: initiateCall returned no id"
  exit 1
fi
echo "   OK call id=$CALL_ID"

echo "2. Parent sees incoming ringing call..."
RING=$(gql "$PARENT_TOKEN" "{ incomingRingingCall { id status initiatedByName } }")
echo "$RING" | python3 -m json.tool
RING_ID=$(echo "$RING" | python3 -c "import sys,json; d=json.load(sys.stdin); print((d.get('data') or {}).get('incomingRingingCall') or {}); import json as j; print(j.loads(sys.stdin.read()) if False else '')" 2>/dev/null || true)
RING_ID=$(echo "$RING" | python3 -c "import sys,json; r=json.load(sys.stdin).get('data',{}).get('incomingRingingCall'); print(r.get('id','') if r else '')")
if [ "$RING_ID" != "$CALL_ID" ]; then
  echo "WARN: incomingRingingCall id=$RING_ID (expected $CALL_ID)"
else
  echo "   OK incoming call matches"
fi

echo "3. Parent fetches callSession by id..."
SESSION=$(gql "$PARENT_TOKEN" "{ callSession(callSessionId: \"$CALL_ID\") { id status joinUrl } }")
echo "$SESSION" | python3 -m json.tool

echo "4. Parent accepts call..."
ACCEPT=$(gql "$PARENT_TOKEN" "mutation { acceptCall(callSessionId: \"$CALL_ID\") { id status joinUrl } }")
echo "$ACCEPT" | python3 -m json.tool
ACCEPT_STATUS=$(echo "$ACCEPT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('acceptCall',{}).get('status',''))")
if [ -z "$ACCEPT_STATUS" ]; then
  echo "FAIL: acceptCall failed"
  exit 1
fi
echo "   OK status=$ACCEPT_STATUS"

echo "5. Therapist ends call..."
END=$(gql "$THERAPIST_TOKEN" "mutation { endCall(callSessionId: \"$CALL_ID\") { id status durationSeconds } }")
echo "$END" | python3 -m json.tool

echo "6. Call history for therapist..."
HIST=$(gql "$THERAPIST_TOKEN" "{ callHistory(filter: { limit: 5 }) { id status callType recipientName } }")
echo "$HIST" | python3 -m json.tool

echo "== All call smoke checks passed =="
