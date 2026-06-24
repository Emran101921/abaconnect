#!/usr/bin/env bash
# Shared login helper for smoke scripts — retries auth rate limits (HTTP 429).

smoke_curl_json() {
  local url="$1"
  shift
  local attempt=0
  local max_attempts=6
  local body http_code

  while (( attempt < max_attempts )); do
    body=$(curl -s -w '\n__HTTP_CODE__:%{http_code}' "$@" "$url")
    http_code="${body##*__HTTP_CODE__:}"
    body="${body%__HTTP_CODE__:*}"

    if [[ "$http_code" == "429" ]]; then
      attempt=$((attempt + 1))
      sleep $((attempt * 2))
      continue
    fi

    if [[ "$http_code" =~ ^2 ]]; then
      printf '%s' "$body"
      return 0
    fi

    printf '%s\n' "$body" >&2
    return 1
  done

  echo "Rate limited after ${max_attempts} attempts: $url" >&2
  return 1
}

smoke_extract_access_token() {
  local email="$1"
  EMAIL="$email" python3 -c "
import json, os, sys

email = os.environ['EMAIL']
try:
    d = json.load(sys.stdin)
except json.JSONDecodeError:
    print(f'Login failed for {email}: auth response is not valid JSON', file=sys.stderr)
    sys.exit(1)
if 'accessToken' not in d:
    msg = d.get('message') or d.get('error') or str(d)[:200]
    print(f'Login failed for {email}: no accessToken in response: {msg}', file=sys.stderr)
    sys.exit(1)
print(d['accessToken'])
"
}

smoke_login() {
  local email="$1" password="$2"
  local device_id="${SMOKE_DEVICE_ID:-smoke-ci-device}"
  local device_model="${SMOKE_DEVICE_MODEL:-CI smoke runner}"
  local device_platform="${SMOKE_DEVICE_PLATFORM:-ci}"
  local resp token

  if ! resp=$(smoke_curl_json "$API/api/v1/auth/login" \
    -X POST \
    -H 'Content-Type: application/json' \
    -H "x-device-id: $device_id" \
    -H "x-device-model: $device_model" \
    -H "x-device-platform: $device_platform" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}"); then
    echo "Login failed for ${email}: auth request failed (HTTP error or rate limit)" >&2
    return 1
  fi

  if echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('requiresMfa') else 1)" 2>/dev/null; then
    if ! token=$(echo "$resp" | EMAIL="$email" python3 -c "
import json, os, sys

email = os.environ['EMAIL']
try:
    d = json.load(sys.stdin)
    print(d['mfaChallengeToken'])
except (json.JSONDecodeError, KeyError):
    print(f'Login failed for {email}: invalid MFA challenge response', file=sys.stderr)
    sys.exit(1)
"); then
      return 1
    fi
    if ! resp=$(smoke_curl_json "$API/api/v1/auth/login/mfa" \
      -X POST \
      -H 'Content-Type: application/json' \
      -H "x-device-id: $device_id" \
      -H "x-device-model: $device_model" \
      -H "x-device-platform: $device_platform" \
      -d "{\"mfaChallengeToken\":\"$token\",\"code\":\"000000\"}"); then
      echo "Login failed for ${email}: MFA request failed (HTTP error or rate limit)" >&2
      return 1
    fi
  fi

  echo "$resp" | smoke_extract_access_token "$email"
}
