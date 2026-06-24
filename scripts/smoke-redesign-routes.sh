#!/usr/bin/env bash
# Smoke-test redesign-related GraphQL surfaces per role.
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
  sleep 2
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

role_section() {
  local role="$1"
  echo
  echo "=== $role redesign routes ==="
}

role_section "Parent"
PARENT=$(login parent1@demo.local 'Parent1Demo!')
CHILDREN=$(gql "$PARENT" 'query { myChildren { id firstName lastName } }')
check "parent myChildren" "isinstance(d.get('data',{}).get('myChildren'), list)" "$CHILDREN"
CHILD_ID=$(echo "$CHILDREN" | python3 -c "import sys,json; rows=json.load(sys.stdin).get('data',{}).get('myChildren') or []; print(rows[0]['id'] if rows else '')")
if [[ -n "$CHILD_ID" ]]; then
  CALLS=$(gql "$PARENT" "query { callHistory(filter: { childId: \"$CHILD_ID\", limit: 5 }) { id status callType } }")
  check "parent callHistory (by child)" "isinstance(d.get('data',{}).get('callHistory'), list)" "$CALLS"
else
  echo "SKIP: parent callHistory (no children)"
fi

role_section "Therapist"
THER=$(login therapist@demo.local 'Therapist123!')
CHARTS=$(gql "$THER" 'query { myTherapistCaseloadCharts { childId firstName lastName therapyTypes } }')
check "therapist caseload charts" "isinstance(d.get('data',{}).get('myTherapistCaseloadCharts'), list)" "$CHARTS"
ONBOARD=$(gql "$THER" 'query { providerOnboardingChecklist { onboardingStatus phiAccessApproved licenseComplete } }')
check "therapist onboarding checklist" "d.get('data',{}).get('providerOnboardingChecklist') is not None" "$ONBOARD"

role_section "Agency"
AGENCY=$(login agency@demo.local 'Agency123!')
AG_CHARTS=$(gql "$AGENCY" 'query { agencyCaseloadCharts { childId firstName lastName } }')
check "agency caseload charts" "isinstance(d.get('data',{}).get('agencyCaseloadCharts'), list)" "$AG_CHARTS"
ROSTER=$(gql "$AGENCY" 'query { agencyTherapists { id rosterStatus onboardingStatus } }')
check "agency therapists roster" "isinstance(d.get('data',{}).get('agencyTherapists'), list)" "$ROSTER"

role_section "Service coordinator"
SC=$(login sc@demo.local 'SC123!')
SC_CHARTS=$(gql "$SC" 'query { myServiceCoordinatorCaseloadCharts { childId firstName lastName } }')
check "SC caseload charts" "isinstance(d.get('data',{}).get('myServiceCoordinatorCaseloadCharts'), list)" "$SC_CHARTS"

role_section "Admin"
ADMIN=$(login admin@abaconnect.local 'Admin123!')
USERS=$(gql "$ADMIN" 'query { adminUsers { id email role firstName lastName } }')
check "admin users" "isinstance(d.get('data',{}).get('adminUsers'), list)" "$USERS"
CLAIMS=$(gql "$ADMIN" 'query { adminClaimsPipeline { summary { paidCount } } }')
check "admin claims pipeline" "d.get('data',{}).get('adminClaimsPipeline') is not None" "$CLAIMS"

echo
echo "=== Redesign routes summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
