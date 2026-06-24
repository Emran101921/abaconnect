#!/usr/bin/env bash
# Smoke-test service coordinator flows on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
SMOKE_DEVICE_ID='smoke-sc-device'
SMOKE_DEVICE_MODEL='Smoke SC runner'
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

gql_expect_error() {
  local token="$1" query="$2"
  local body
  body=$(python3 -c "import json; print(json.dumps({'query': '''$query'''}))")
  curl -s -X POST "$GQL" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$body"
}

echo "=== Health ==="
curl -sf "$API/api/v1/health" | python3 -m json.tool
echo

echo "=== Service coordinator login & dashboard ==="
SC=$(login sc@demo.local 'SC123!')
DASH=$(gql "$SC" 'query { serviceCoordinatorDashboard { totalCases urgentCases screeningsDue followUpsDue cases { childId childName } } }')
check "serviceCoordinatorDashboard query" \
  "d.get('data',{}).get('serviceCoordinatorDashboard') is not None" "$DASH"
check "SC has assigned cases" \
  "d['data']['serviceCoordinatorDashboard']['totalCases'] >= 1" "$DASH"

CHILD_ID=$(echo "$DASH" | python3 -c "import sys,json; d=json.load(sys.stdin); cases=d['data']['serviceCoordinatorDashboard']['cases']; print(cases[0]['childId'] if cases else '')")
if [[ -z "$CHILD_ID" ]]; then
  echo "FAIL: could not resolve assigned child id from dashboard"
  fail=$((fail + 1))
else
  CASE=$(gql "$SC" "query { serviceCoordinatorCase(childId: \"$CHILD_ID\") { childId childName parentName } }")
  check "serviceCoordinatorCase for assigned child" \
    "d['data']['serviceCoordinatorCase']['childId'] == '$CHILD_ID'" "$CASE"

  BAD=$(gql_expect_error "$SC" 'query { serviceCoordinatorCase(childId: "00000000-0000-0000-0000-000000000099") { childId } }')
  check "serviceCoordinatorCase rejects unassigned child" \
    "d.get('errors') is not None" "$BAD"
fi

echo
echo "=== SC messaging (assigned contacts only) ==="
CONTACTS=$(gql "$SC" 'query { myServiceCoordinatorContacts { userId displayName roleLabel childSummary } }')
check "myServiceCoordinatorContacts query" \
  "isinstance(d.get('data',{}).get('myServiceCoordinatorContacts'), list)" "$CONTACTS"
check "SC has parent contact on assigned case" \
  "len(d.get('data',{}).get('myServiceCoordinatorContacts',[])) >= 1" "$CONTACTS"

PARENT_ID=$(echo "$CONTACTS" | python3 -c "import sys,json; d=json.load(sys.stdin); cs=d['data']['myServiceCoordinatorContacts']; p=next((c for c in cs if c.get('roleLabel')=='Parent'), None); print(p['userId'] if p else '')")
if [[ -n "$PARENT_ID" ]]; then
  START=$(gql "$SC" "mutation { startServiceCoordinatorConversation(targetUserId: \"$PARENT_ID\") { id otherParticipantName } }")
  check "startServiceCoordinatorConversation with assigned parent" \
    "d.get('data',{}).get('startServiceCoordinatorConversation',{}).get('id')" "$START"
fi

THREADS=$(gql "$SC" 'query { myMessageThreads { id otherParticipantName } }')
check "SC can list message threads" \
  "isinstance(d.get('data',{}).get('myMessageThreads'), list)" "$THREADS"

echo
echo "=== Parent cannot access SC dashboard ==="
PARENT=$(login parent1@demo.local 'Parent1Demo!')
PARENT_SC=$(gql_expect_error "$PARENT" 'query { serviceCoordinatorDashboard { totalCases } }')
check "parent blocked from SC dashboard" \
  "d.get('errors') is not None" "$PARENT_SC"

echo
echo "=== Agency dashboard SC stats ==="
AGENCY=$(login agency@demo.local 'Agency123!')
AD=$(gql "$AGENCY" 'query { agencyDashboard { serviceCoordinatorCount activeScCaseload urgentScCases scFollowUpsDue } agencyCases { childId childName assignedCoordinatorName } }')
check "agency SC stat fields" \
  "'serviceCoordinatorCount' in d.get('data',{}).get('agencyDashboard',{})" "$AD"
check "agencyCases query" \
  "isinstance(d.get('data',{}).get('agencyCases'), list)" "$AD"
check "agency has SC on roster" \
  "d['data']['agencyDashboard']['serviceCoordinatorCount'] >= 1" "$AD"

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
