#!/usr/bin/env bash
# Smoke-test NY EI billing flows on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
SMOKE_DEVICE_ID='smoke-ei-billing-device'
SMOKE_DEVICE_MODEL='Smoke EI billing runner'
DEMO_READY_RECORD_ID='00000000-0000-4000-8000-0000000000e2'
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

echo "=== EI billing smoke test ==="

BILLING="${SMOKE_BILLING_TOKEN:-$(login billing@demo.local 'Billing123!')}"
AGENCY="${SMOKE_AGENCY_TOKEN:-$(login agency@demo.local 'Agency123!')}"

echo
echo "=== Dashboard & queue ==="
DASH=$(gql "$BILLING" 'query { eiBillingDashboard { totalRecords readyAgencyReview missingInformation submitted paid denialsAndCorrections } }')
check "eiBillingDashboard query" "d.get('data',{}).get('eiBillingDashboard') is not None" "$DASH"
check "eiBillingDashboard has demo records" "d['data']['eiBillingDashboard']['totalRecords'] >= 1" "$DASH"

QUEUE=$(gql "$BILLING" 'query { eiBillingQueue(filter: { take: 10 }) { id queueStatus childDisplayName units validationIssues { code severity resolved } } }')
check "eiBillingQueue query" "isinstance(d.get('data',{}).get('eiBillingQueue'), list)" "$QUEUE"
check "eiBillingQueue has seeded records" "len(d.get('data',{}).get('eiBillingQueue',[])) >= 1" "$QUEUE"

RECORD_ID=$(echo "$QUEUE" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('eiBillingQueue') or []
ready = next((r['id'] for r in rows if r.get('queueStatus') == 'READY_AGENCY_REVIEW'), '')
print(ready or (rows[0]['id'] if rows else ''))
")
if [[ -z "$RECORD_ID" ]]; then
  RECORD_ID="$DEMO_READY_RECORD_ID"
fi

echo
echo "=== Record detail (agency + billing) ==="
DETAIL=$(gql "$BILLING" "query { eiBillingRecord(id: \"$RECORD_ID\") { id queueStatus childDisplayName therapistName } }")
check "eiBillingRecord query" "d.get('data',{}).get('eiBillingRecord',{}).get('id') == '$RECORD_ID'" "$DETAIL"

PROFILE=$(gql "$AGENCY" 'query { eiAgencyBillingProfile { id agencyId legalName enrollmentComplete npi } }')
check "eiAgencyBillingProfile query" "d.get('data',{}).get('eiAgencyBillingProfile') is not None" "$PROFILE"

echo
echo "=== Validate record ==="
VALIDATE=$(gql "$BILLING" "mutation { validateEiBillingRecord(recordId: \"$RECORD_ID\") { id queueStatus validationIssues { code severity message resolved } } }")
check "validateEiBillingRecord mutation" "d.get('data',{}).get('validateEiBillingRecord',{}).get('id') == '$RECORD_ID'" "$VALIDATE"

echo
echo "=== Export record ==="
EXPORT=$(gql "$BILLING" "mutation { exportEiBillingRecord(input: { recordId: \"$RECORD_ID\", workflow: EI_HUB, authorizedConfirm: true }) { artifactType fileName payload } }")
check "exportEiBillingRecord mutation" "d.get('data',{}).get('exportEiBillingRecord',{}).get('fileName')" "$EXPORT"
check "exportEiBillingRecord payload" "bool(d.get('data',{}).get('exportEiBillingRecord',{}).get('payload'))" "$EXPORT"

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
