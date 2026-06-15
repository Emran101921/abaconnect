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

echo "=== Parent marketplace requests (childId field) ==="
PARENT=$(login parent1@demo.local 'Parent1Demo!')
MY_REQS=$(gql "$PARENT" 'query { myMarketplaceRequests { id anonymousPublicId childId interestCount status } }')
check "myMarketplaceRequests query" "isinstance(d.get('data',{}).get('myMarketplaceRequests'), list)" "$MY_REQS"

echo
echo "=== Provider browse + saved searches ==="
THER=$(login therapist@demo.local 'Therapist123!')
BROWSE=$(gql "$THER" 'query { browseMarketplaceRequests { id anonymousPublicId matchScore distanceMiles } }')
check "browseMarketplaceRequests query" "isinstance(d.get('data',{}).get('browseMarketplaceRequests'), list)" "$BROWSE"

SAVED=$(gql "$THER" 'query { myMarketplaceSavedSearches { id name alertsEnabled zipCode radiusMiles } }')
check "myMarketplaceSavedSearches query" "isinstance(d.get('data',{}).get('myMarketplaceSavedSearches'), list)" "$SAVED"

echo
echo "=== Admin moderation endpoints ==="
ADMIN=$(login admin@abaconnect.local 'Admin123!')
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
AGENCY=$(login agency@demo.local 'Agency123!')
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

PENDING_INTEREST=$(echo "$MY_REQS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('myMarketplaceRequests') or []
for row in rows:
    if (row.get('interestCount') or 0) > 0:
        print(row['id'])
        break
")
if [ -n "$PENDING_INTEREST" ]; then
  INTERESTS=$(gql "$PARENT" "query { marketplaceRequestInterests(marketplaceRequestId: \"$PENDING_INTEREST\") { status provider { id } } }")
  PROVIDER_ID=$(echo "$INTERESTS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('marketplaceRequestInterests') or []
pending = next((r['provider']['id'] for r in rows if r.get('status') == 'PENDING_PARENT_REVIEW'), '')
print(pending)
")
  if [ -n "$PROVIDER_ID" ]; then
    REJECT=$(gql "$PARENT" "mutation { rejectMarketplaceInterest(marketplaceRequestId: \"$PENDING_INTEREST\", providerProfileId: \"$PROVIDER_ID\") }")
    check "rejectMarketplaceInterest mutation" \
      "d.get('data',{}).get('rejectMarketplaceInterest') is True" "$REJECT"
  else
    echo "SKIP: rejectMarketplaceInterest (no pending interests in seed)"
  fi
else
  echo "SKIP: rejectMarketplaceInterest (no requests with interests in seed)"
fi

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
