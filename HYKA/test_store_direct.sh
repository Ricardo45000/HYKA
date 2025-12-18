#!/bin/bash

# Test garmin-activity-store directly with file payload

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
STORE_URL="${SUPABASE_URL}/functions/v1/garmin-activity-store"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

ACTIVITY_ID="21193470552"
GARMIN_USER_ID="ae3cd04a-b8d6-4803-b7ed-7213c975c258"
USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"
CALLBACK_URL="https://connectapi.garmin.com/activity-service/activity/${ACTIVITY_ID}/file/fit"

# Test with file payload (what garmin-activity-push sends)
PAYLOAD=$(cat <<JSON
{
  "garminUserId": "${GARMIN_USER_ID}",
  "userId": "${USER_ID}",
  "file": {
    "summaryId": "${ACTIVITY_ID}",
    "activityId": "${ACTIVITY_ID}",
    "callbackUrl": "${CALLBACK_URL}",
    "fileType": "fit",
    "startTimeInSeconds": 1765108616
  },
  "callbackUrl": "${CALLBACK_URL}"
}
JSON
)

echo "=== Testing garmin-activity-store directly ==="
echo ""
echo "Payload:"
echo "$PAYLOAD" | jq '.'
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${STORE_URL}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo "Response:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
