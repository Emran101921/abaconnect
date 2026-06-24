#!/usr/bin/env bash
# Smoke-test marketplace features on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
SMOKE_DEVICE_ID='smoke-marketplace-device'
SMOKE_DEVICE_MODEL='Smoke marketplace runner'
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

rest() {
  local method="$1" token="$2" path="$3"
  curl -sf -X "$method" "$API/api/v1$path" \
    -H "Authorization: Bearer $token" \
    -H 'Content-Type: application/json'
}

echo "=== Health ==="
curl -sf "$API/api/v1/health" | python3 -m json.tool
echo

# Reuse tokens from smoke-features.sh when exported; agency before admin on fallback.
PARENT="${SMOKE_PARENT_TOKEN:-$(login parent1@demo.local 'Parent1Demo!')}"
THER="${SMOKE_THERAPIST_TOKEN:-$(login therapist@demo.local 'Therapist123!')}"
AGENCY="${SMOKE_AGENCY_TOKEN:-$(login agency@demo.local 'Agency123!')}"
ADMIN="${SMOKE_ADMIN_TOKEN:-$(login admin@abaconnect.local 'Admin123!')}"

echo "=== Parent marketplace requests (childId field) ==="
MY_REQS=$(gql "$PARENT" 'query { myMarketplaceRequests { id anonymousPublicId childId interestCount status } }')
check "myMarketplaceRequests query" "isinstance(d.get('data',{}).get('myMarketplaceRequests'), list)" "$MY_REQS"

echo
echo "=== Provider browse + saved searches ==="
BROWSE=$(gql "$THER" 'query { browseMarketplaceRequests { id anonymousPublicId matchScore distanceMiles } }')
check "browseMarketplaceRequests query" "isinstance(d.get('data',{}).get('browseMarketplaceRequests'), list)" "$BROWSE"

SAVED=$(gql "$THER" 'query { myMarketplaceSavedSearches { id name alertsEnabled zipCode radiusMiles } }')
check "myMarketplaceSavedSearches query" "isinstance(d.get('data',{}).get('myMarketplaceSavedSearches'), list)" "$SAVED"

echo
echo "=== Admin moderation endpoints ==="
LISTINGS=$(rest GET "$ADMIN" '/admin/marketplace-requests')
check "admin marketplace listings" "isinstance(d, list)" "$LISTINGS"

REPORTS=$(rest GET "$ADMIN" '/admin/marketplace-reports')
check "admin marketplace reports" "isinstance(d, list)" "$REPORTS"

PROVIDERS=$(rest GET "$ADMIN" '/admin/marketplace-providers')
check "admin pending providers" "isinstance(d, list)" "$PROVIDERS"

AUDIT=$(rest GET "$ADMIN" '/admin/audit-logs')
check "admin marketplace audit logs" "isinstance(d, list)" "$AUDIT"

echo
echo "=== GraphQL marketplace consent types ==="
CONSENT_TYPES=$(gql "$PARENT" 'query { marketplaceConsentHistory(marketplaceRequestId: "00000000-0000-4000-8000-000000000000") { id consentType } }')
# Invalid id should error gracefully, not crash server
check "marketplaceConsentHistory handles missing request" \
  "d.get('errors') is not None or d.get('data',{}).get('marketplaceConsentHistory') is not None" "$CONSENT_TYPES"

echo
echo "=== Agency marketplace profile ==="
AGENCY_PROFILE=$(gql "$AGENCY" 'query { myProviderMarketplaceProfile { id verifiedStatus displayName } }')
check "myProviderMarketplaceProfile for agency" \
  "'myProviderMarketplaceProfile' in d.get('data', {})" "$AGENCY_PROFILE"

echo
echo "=== Parent consent history (when requests exist) ==="
REQ_ID=$(echo "$MY_REQS" | python3 -c "import sys,json; r=json.load(sys.stdin).get('data',{}).get('myMarketplaceRequests') or []; print(r[0]['id'] if r else '')")
if [ -n "$REQ_ID" ]; then
  CONSENT_HIST=$(gql "$PARENT" "query { marketplaceConsentHistory(marketplaceRequestId: \"$REQ_ID\") { id consentType granted } }")
  check "marketplaceConsentHistory for parent request" \
    "isinstance(d.get('data',{}).get('marketplaceConsentHistory'), list)" "$CONSENT_HIST"
else
  echo "SKIP: parent consent history (no marketplace requests in seed)"
fi

echo
echo "=== Parent marketplace lifecycle mutations ==="
ACTIVE_ID=$(echo "$MY_REQS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myMarketplaceRequests') or []
active = next((r['id'] for r in rows if r.get('status') == 'ACTIVE'), '')
print(active)
")
PAUSED_ID=$(echo "$MY_REQS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myMarketplaceRequests') or []
paused = next((r['id'] for r in rows if r.get('status') == 'PAUSED'), '')
print(paused)
")

if [ -n "$ACTIVE_ID" ]; then
  PAUSE=$(gql "$PARENT" "mutation { pauseMarketplaceRequest(marketplaceRequestId: \"$ACTIVE_ID\") }")
  check "pauseMarketplaceRequest mutation" \
    "d.get('data',{}).get('pauseMarketplaceRequest') is True" "$PAUSE"
  RESUME=$(gql "$PARENT" "mutation { resumeMarketplaceRequest(marketplaceRequestId: \"$ACTIVE_ID\") }")
  check "resumeMarketplaceRequest mutation" \
    "d.get('data',{}).get('resumeMarketplaceRequest') is True" "$RESUME"
elif [ -n "$PAUSED_ID" ]; then
  RESUME=$(gql "$PARENT" "mutation { resumeMarketplaceRequest(marketplaceRequestId: \"$PAUSED_ID\") }")
  check "resumeMarketplaceRequest mutation" \
    "d.get('data',{}).get('resumeMarketplaceRequest') is True" "$RESUME"
  echo "SKIP: pauseMarketplaceRequest (no ACTIVE request in seed)"
else
  echo "SKIP: pause/resume mutations (no marketplace requests in seed)"
fi

# Self-contained setup so rejectMarketplaceInterest always runs (even without DB seed).
echo
echo "=== rejectMarketplaceInterest mutation ==="
CHILD_ID=$(gql "$PARENT" 'query { myChildren { id zipCode } }' | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myChildren') or []
with_zip = next((c['id'] for c in rows if c.get('zipCode')), '')
print(with_zip or (rows[0]['id'] if rows else ''))
")
if [ -z "$CHILD_ID" ]; then
  ADD_CHILD=$(gql "$PARENT" 'mutation { addChild(input: { firstName: "Smoke", lastName: "Child", dateOfBirth: "2021-06-01", zipCode: "11230" }) { id } }')
  CHILD_ID=$(echo "$ADD_CHILD" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('addChild',{}).get('id',''))")
  check "addChild for rejectMarketplaceInterest setup" "bool('${CHILD_ID}')" "$ADD_CHILD"
fi

REJECT_REQ_ID=""
if [ -n "$CHILD_ID" ]; then
  CREATE_REJECT=$(gql "$PARENT" "mutation { createMarketplaceRequest(input: { childId: \"$CHILD_ID\", anonymousConsentGranted: true, locationType: HOME, publicDescription: \"Smoke reject interest test\" }) { id status } }")
  REJECT_REQ_ID=$(echo "$CREATE_REJECT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('createMarketplaceRequest',{}).get('id',''))")
  check "createMarketplaceRequest for reject setup" "bool('${REJECT_REQ_ID}')" "$CREATE_REJECT"
fi

if [ -n "$REJECT_REQ_ID" ]; then
  SUBMIT_INTEREST=$(gql "$THER" "mutation { submitMarketplaceInterest(input: { marketplaceRequestId: \"$REJECT_REQ_ID\", message: \"Smoke test provider interest\" }) }")
  check "submitMarketplaceInterest for reject setup" \
    "d.get('data',{}).get('submitMarketplaceInterest') is True" "$SUBMIT_INTEREST"

  INTERESTS=$(gql "$PARENT" "query { marketplaceRequestInterests(marketplaceRequestId: \"$REJECT_REQ_ID\") { status provider { id } } }")
  PROVIDER_ID=$(echo "$INTERESTS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('marketplaceRequestInterests') or []
pending = next((r['provider']['id'] for r in rows if r.get('status') == 'PENDING_PARENT_REVIEW'), '')
print(pending)
")
  if [ -n "$PROVIDER_ID" ]; then
    REJECT=$(gql "$PARENT" "mutation { rejectMarketplaceInterest(marketplaceRequestId: \"$REJECT_REQ_ID\", providerProfileId: \"$PROVIDER_ID\") }")
    check "rejectMarketplaceInterest mutation" \
      "d.get('data',{}).get('rejectMarketplaceInterest') is True" "$REJECT"
  else
    echo "FAIL: rejectMarketplaceInterest setup (no pending provider interest)"
    fail=$((fail + 1))
  fi
else
  echo "FAIL: rejectMarketplaceInterest setup (no child for parent1)"
  fail=$((fail + 1))
fi

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
