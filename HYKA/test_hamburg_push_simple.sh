#!/bin/bash

# Simple test - just send the push with a test Garmin User ID
# We'll let the function look it up from the activity

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

ACTIVITY_ID="21193470552"

# Try to get garmin_user_id from existing activity's connection
# Or use a placeholder - the function should look it up
GARMIN_USER_ID="105112636"  # Common Garmin user ID format, or we can try to get it

echo "=== Testing Hamburg Running Activity Push ==="
echo "Activity ID: ${ACTIVITY_ID}"
echo "Garmin User ID: ${GARMIN_USER_ID} (will be looked up if wrong)"
echo ""

# Construct push payload
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
echo "=== Waiting 10 seconds for processing... ==="
sleep 10

echo ""
echo "=== Checking Results ==="
curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,garmin_activity_id,activity_name,distance_meters,duration_seconds,average_heart_rate,max_heart_rate,average_cadence,has_fit_file" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" | jq '.'
