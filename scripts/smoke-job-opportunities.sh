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
d = json.load(sys.stdin)
items = d.get('data', {}).get('browseJobOpportunities', {}) or {}
items = items.get('items') or []
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
echo "=== Job interview scheduling ==="
  APPLY=$(gql "$THER" "mutation { applyToJobOpportunity(input: { jobOpportunityId: \"$JOB_ID\" }) { id status } }")
APP_ID=$(echo "$APPLY" | python3 -c "
import sys, json
d = json.load(sys.stdin)
app = d.get('data', {}).get('applyToJobOpportunity') or {}
print(app.get('id', ''))
" 2>/dev/null || true)
if [[ -z "$APP_ID" ]]; then
  APPS=$(gql "$AGENCY" "query { agencyJobApplications(jobOpportunityId: \"$JOB_ID\") { id status } }")
  APP_ID=$(echo "$APPS" | python3 -c "
import sys, json
rows = json.load(sys.stdin).get('data', {}).get('agencyJobApplications') or []
print(rows[0]['id'] if rows else '')
" 2>/dev/null || true)
fi
if [[ -z "$APP_ID" ]]; then
  echo "FAIL: no job application for interview smoke test"
  fail=$((fail + 1))
else
  SCHEDULE_AT=$(python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc)+timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
  SCHEDULE=$(gql "$AGENCY" "mutation { scheduleJobInterview(input: { applicationId: \"$APP_ID\", scheduledAt: \"$SCHEDULE_AT\", durationMinutes: 30, recordingRequested: true, agencyRecordingConsent: true }) { id status scheduledAt recordingRequested } }")
  if echo "$SCHEDULE" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('data',{}).get('scheduleJobInterview') else 1)" 2>/dev/null; then
    check "scheduleJobInterview mutation" \
      "d.get('data',{}).get('scheduleJobInterview',{}).get('status') in ('SCHEDULED', 'CONFIRMED')" "$SCHEDULE"
    INTERVIEW_ID=$(echo "$SCHEDULE" | python3 -c "
import sys, json
row = json.load(sys.stdin).get('data', {}).get('scheduleJobInterview') or {}
print(row.get('id', ''))
" 2>/dev/null || true)
  else
    EXISTING=$(gql "$AGENCY" "query { jobInterviewForApplication(applicationId: \"$APP_ID\") { id status } }")
    check "jobInterviewForApplication (existing interview)" \
      "d.get('data',{}).get('jobInterviewForApplication',{}).get('status') in ('SCHEDULED', 'CONFIRMED')" "$EXISTING"
    INTERVIEW_ID=$(echo "$EXISTING" | python3 -c "
import sys, json
row = json.load(sys.stdin).get('data', {}).get('jobInterviewForApplication') or {}
print(row.get('id', ''))
" 2>/dev/null || true)
  fi

  if [[ -n "$INTERVIEW_ID" ]]; then
    AGENCY_CAL=$(gql "$AGENCY" 'query { agencyJobInterviews { id status jobTitle therapistName } }')
    check "agencyJobInterviews query" \
      "any(i.get('id') == '$INTERVIEW_ID' for i in d.get('data',{}).get('agencyJobInterviews',[]))" "$AGENCY_CAL"

    THER_CAL=$(gql "$THER" 'query { myJobInterviews { id status jobTitle agencyName } }')
    check "myJobInterviews query" \
      "any(i.get('id') == '$INTERVIEW_ID' for i in d.get('data',{}).get('myJobInterviews',[]))" "$THER_CAL"

    CONSENT=$(gql "$THER" "mutation { grantJobInterviewRecordingConsent(input: { interviewId: \"$INTERVIEW_ID\", consent: true }) { id therapistRecordingConsent agencyRecordingConsent } }")
    check "grantJobInterviewRecordingConsent (therapist)" \
      "d.get('data',{}).get('grantJobInterviewRecordingConsent',{}).get('therapistRecordingConsent') is True" "$CONSENT"
  else
    echo "FAIL: could not resolve interview id"
    fail=$((fail + 1))
  fi
fi

echo
echo "=== Hiring pipeline: offer → accept → hire ==="
if [[ -n "$APP_ID" ]]; then
  PIPELINE=$(gql "$AGENCY" 'query { agencyHiringPipelineSummary { totalPendingActions newApplicants readyToHire } }')
  check "agencyHiringPipelineSummary query" \
    "isinstance(d.get('data',{}).get('agencyHiringPipelineSummary',{}).get('totalPendingActions'), int)" "$PIPELINE"

  OFFER=$(gql "$AGENCY" "mutation { sendJobOffer(input: { applicationId: \"$APP_ID\", compensationRate: \"\\\$65/hr\", message: \"Welcome aboard\" }) { id status } }")
  check "sendJobOffer mutation" \
    "d.get('data',{}).get('sendJobOffer',{}).get('status') == 'OFFER_SENT'" "$OFFER"

  ACCEPT=$(gql "$THER" "mutation { respondToJobOffer(input: { applicationId: \"$APP_ID\", accept: true }) { id status } }")
  check "respondToJobOffer accept" \
    "d.get('data',{}).get('respondToJobOffer',{}).get('status') == 'APPROVED'" "$ACCEPT"

  HIRED=$(gql "$AGENCY" "mutation { markTherapistHiredContracted(applicationId: \"$APP_ID\") { id status } }")
  check "markTherapistHiredContracted mutation" \
    "d.get('data',{}).get('markTherapistHiredContracted',{}).get('status') == 'HIRED_CONTRACTED'" "$HIRED"

  ROSTER=$(gql "$AGENCY" "mutation { addTherapistToAgencyRosterFromApplication(applicationId: \"$APP_ID\") }")
  check "addTherapistToAgencyRosterFromApplication mutation" \
    "d.get('data',{}).get('addTherapistToAgencyRosterFromApplication') is True" "$ROSTER"

  SESSION_AT=$(python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc)+timedelta(days=3)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
  SESSION=$(gql "$AGENCY" "mutation { scheduleFirstSessionFromHire(input: { applicationId: \"$APP_ID\", scheduledStart: \"$SESSION_AT\", durationMinutes: 60 }) { appointmentId childId } }")
  check "scheduleFirstSessionFromHire mutation" \
    "d.get('data',{}).get('scheduleFirstSessionFromHire',{}).get('appointmentId')" "$SESSION"
fi

echo
echo "=== Summary: $pass passed, $fail failed ==="
test "$fail" -eq 0
