#!/usr/bin/env bash
# Smoke-test marketplace features on a running API (http://localhost:3000).
set -euo pipefail

API="${API_URL:-http://localhost:3000}"
GQL="$API/graphql"
DEVICE_HEADERS=(
  -H 'x-device-id: smoke-marketplace-device'
  -H 'x-device-model: Smoke marketplace runner'
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
    echo "$data" | python3 -m json.tool 2>/dev/null | head -30 || echo "$data"
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
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
