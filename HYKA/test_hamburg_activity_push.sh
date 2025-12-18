#!/bin/bash

# Test push for "Dec 6 - Hamburg Running" activity
# Activity ID: 21193470552

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"
ACTIVITY_ID="21193470552"

echo "=== Testing Hamburg Running Activity Push ==="
echo "Activity ID: ${ACTIVITY_ID}"
echo ""

# Get Garmin User ID from database
echo "📋 Fetching Garmin connection..."
GARMIN_CONNECTION=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_connections?user_id=eq.${USER_ID}&select=garmin_user_id" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}")

GARMIN_USER_ID=$(echo "$GARMIN_CONNECTION" | jq -r '.[0].garmin_user_id // empty')

if [ -z "$GARMIN_USER_ID" ] || [ "$GARMIN_USER_ID" = "null" ]; then
  echo "❌ No Garmin connection found"
  echo "Connection data:"
  echo "$GARMIN_CONNECTION" | jq '.'
  exit 1
fi

echo "✅ Garmin User ID: ${GARMIN_USER_ID}"
echo ""

# Construct push payload with FIT file callbackUrl
CALLBACK_URL="https://connectapi.garmin.com/activity-service/activity/${ACTIVITY_ID}/file/fit"

PAYLOAD=$(cat <<JSON
{
  "activityFiles": [
    {
      "userId": "${GARMIN_USER_ID}",
      "summaryId": "${ACTIVITY_ID}",
      "activityId": "${ACTIVITY_ID}",
      "activityType": "running",
      "callbackUrl": "${CALLBACK_URL}",
      "fileType": "fit",
      "startTimeInSeconds": 1765108616
    }
  ]
}
JSON
)

echo "=== Push Payload ==="
echo "$PAYLOAD" | jq '.'
echo ""

echo "=== Sending to garmin-activity-push ==="
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${FUNCTION_URL}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin-Connect" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo ""
echo "Response:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

echo "=== Waiting 5 seconds for processing... ==="
sleep 5

echo ""
echo "=== Checking stored activity ==="
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=*" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}")

echo "$ACTIVITY" | jq '.[0] | {id, garmin_activity_id, activity_name, activity_type, distance_meters, duration_seconds, average_heart_rate, max_heart_rate, average_cadence, has_fit_file}' 2>/dev/null || echo "$ACTIVITY"

echo ""
echo "=== Checking FIT file ==="
ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
if [ -n "$ACTIVITY_UUID" ] && [ "$ACTIVITY_UUID" != "null" ]; then
  FIT_FILE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=id,file_size_bytes,created_at" \
    -H "apikey: ${SERVICE_KEY}" \
    -H "Authorization: Bearer ${SERVICE_KEY}")
  echo "$FIT_FILE" | jq '.'
  
  echo ""
  echo "=== Checking samples ==="
  SAMPLES=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=count" \
    -H "apikey: ${SERVICE_KEY}" \
    -H "Authorization: Bearer ${SERVICE_KEY}" \
    -H "Prefer: count=exact")
  
  SAMPLE_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id" \
    -H "apikey: ${SERVICE_KEY}" \
    -H "Authorization: Bearer ${SERVICE_KEY}" \
    -H "Prefer: count=exact" | jq '. | length' 2>/dev/null || echo "0")
  
  echo "Sample count: ${SAMPLE_COUNT}"
  
  if [ "$SAMPLE_COUNT" -gt 0 ]; then
    echo ""
    echo "First 3 samples:"
    curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=*&limit=3&order=timestamp_seconds.asc" \
      -H "apikey: ${SERVICE_KEY}" \
      -H "Authorization: Bearer ${SERVICE_KEY}" | jq '.'
  fi
fi

echo ""
echo "=== Test Complete ==="
