#!/bin/bash

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

ACTIVITY_ID="21193470552"
GARMIN_USER_ID="ae3cd04a-b8d6-4803-b7ed-7213c975c258"

echo "=== Testing Hamburg Running Activity Push (Retry) ==="
echo "Activity ID: ${ACTIVITY_ID}"
echo ""

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

echo "=== Sending Push ==="
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${FUNCTION_URL}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin-Connect" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

echo ""
echo "=== Waiting 20 seconds for full processing... ==="
sleep 20

echo ""
echo "=== Checking Activity ==="
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,garmin_activity_id,activity_name,distance_meters,duration_seconds,average_heart_rate,has_fit_file" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

echo "$ACTIVITY" | jq '.[0]'

ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
if [ -n "$ACTIVITY_UUID" ] && [ "$ACTIVITY_UUID" != "null" ]; then
  echo ""
  echo "=== FIT File & Samples ==="
  FIT_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ANON_KEY}" | jq '. | length' 2>/dev/null || echo "0")
  echo "FIT files: ${FIT_COUNT}"
  
  SAMPLE_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ANON_KEY}" | jq '. | length' 2>/dev/null || echo "0")
  echo "Samples: ${SAMPLE_COUNT}"
fi

echo ""
echo "=== Test Complete ==="
