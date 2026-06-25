#!/usr/bin/env bash
# Smoke-test job opportunity marketplace on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
DEMO_JOB_ID='00000000-0000-4000-8000-000000000111'
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
  curl -s -X POST "$GQL" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json' \
    -d "$body"
}

echo "=== Job opportunities smoke test ==="

THER="${SMOKE_THERAPIST_TOKEN:-$(login therapist@demo.local 'Therapist123!')}"
AGENCY="${SMOKE_AGENCY_TOKEN:-$(login agency@demo.local 'Agency123!')}"

echo
echo "=== Therapist browse + saved jobs ==="
BROWSE=$(gql "$THER" 'query { browseJobOpportunities { total items { id title agencyName isSaved } } }')
check "browseJobOpportunities query" \
  "isinstance(d.get('data',{}).get('browseJobOpportunities',{}).get('items'), list)" "$BROWSE"

JOB_ID=$(echo "$BROWSE" | python3 -c "
import sys, json
items = json.load(sys.stdin).get('data', {}).get('browseJobOpportunities', {}).get('items') or []
match = next((i['id'] for i in items if i.get('id')), '')
print(match or '$DEMO_JOB_ID')
")

SAVE=$(gql "$THER" "mutation { saveJobOpportunity(jobOpportunityId: \"$JOB_ID\") { id isSaved title } }")
check "saveJobOpportunity mutation" \
  "d.get('data',{}).get('saveJobOpportunity',{}).get('isSaved') is True" "$SAVE"

SAVED=$(gql "$THER" 'query { savedJobOpportunities { id title } }')
check "savedJobOpportunities query" \
  "any(j.get('id') == '$JOB_ID' for j in d.get('data',{}).get('savedJobOpportunities',[]))" "$SAVED"

UNSAVE=$(gql "$THER" "mutation { unsaveJobOpportunity(jobOpportunityId: \"$JOB_ID\") }")
check "unsaveJobOpportunity mutation" \
  "d.get('data',{}).get('unsaveJobOpportunity') is True" "$UNSAVE"

echo
echo "=== Agency invite-to-apply + therapist invites ==="
ROSTER=$(gql "$AGENCY" 'query { agencyTherapists { id user { firstName lastName } } }')
THERAPIST_ID=$(echo "$ROSTER" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('agencyTherapists') or []
print(rows[0]['id'] if rows else '')
")
if [[ -z "$THERAPIST_ID" ]]; then
  echo "FAIL: agencyTherapists roster empty for invite setup"
  fail=$((fail + 1))
else
  INVITE=$(gql "$AGENCY" "mutation { inviteTherapistToApply(jobOpportunityId: \"$JOB_ID\", therapistId: \"$THERAPIST_ID\") { id jobTitle agencyName invitedAt } }")
  check "inviteTherapistToApply mutation" \
    "d.get('data',{}).get('inviteTherapistToApply',{}).get('jobTitle')" "$INVITE"

  INVITES=$(gql "$THER" 'query { myJobOpportunityInvites { id jobOpportunityId jobTitle agencyName } }')
  check "myJobOpportunityInvites query" \
    "any(i.get('jobOpportunityId') == '$JOB_ID' for i in d.get('data',{}).get('myJobOpportunityInvites',[]))" "$INVITES"

  NOTIFS=$(gql "$THER" 'query { myNotifications { id actionType jobOpportunityId title } }')
  check "therapist JOB_INVITE_TO_APPLY notification" \
    "any(n.get('actionType') == 'JOB_INVITE_TO_APPLY' and n.get('jobOpportunityId') == '$JOB_ID' for n in d.get('data',{}).get('myNotifications',[]))" "$NOTIFS"
fi

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
