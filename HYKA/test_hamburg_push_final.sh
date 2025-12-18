#!/bin/bash

# Test push for Hamburg Running activity
# Using correct Garmin User ID

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

ACTIVITY_ID="21193470552"
GARMIN_USER_ID="ae3cd04a-b8d6-4803-b7ed-7213c975c258"

echo "=== Testing Hamburg Running Activity Push ==="
echo "Activity ID: ${ACTIVITY_ID}"
echo "Garmin User ID: ${GARMIN_USER_ID}"
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

echo "=== Push Payload ==="
echo "$PAYLOAD" | jq '.'
echo ""

echo "=== Sending to garmin-activity-push ==="
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
echo "=== Waiting 15 seconds for processing (FIT download + parsing)... ==="
sleep 15

echo ""
echo "=== Checking Stored Activity ==="
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,garmin_activity_id,activity_name,activity_type,distance_meters,duration_seconds,average_heart_rate,max_heart_rate,average_cadence,has_fit_file,created_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

echo "$ACTIVITY" | jq '.'

ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
if [ -n "$ACTIVITY_UUID" ] && [ "$ACTIVITY_UUID" != "null" ]; then
  echo ""
  echo "=== Checking FIT File ==="
  FIT_FILE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=id,file_size_bytes,created_at" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ANON_KEY}")
  echo "$FIT_FILE" | jq '.'
  
  echo ""
  echo "=== Checking Samples Count ==="
  SAMPLE_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ANON_KEY}" \
    -H "Prefer: count=exact" | jq '. | length' 2>/dev/null || echo "0")
  
  echo "Total samples: ${SAMPLE_COUNT}"
  
  if [ "$SAMPLE_COUNT" -gt 0 ]; then
    echo ""
    echo "=== First 5 Samples ==="
    curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=timestamp_seconds,sample_time,latitude,longitude,elevation_meters,heart_rate,speed_mps,steps_per_minute&limit=5&order=timestamp_seconds.asc" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}" | jq '.'
      
    echo ""
    echo "=== Last 5 Samples ==="
    curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=timestamp_seconds,sample_time,latitude,longitude,elevation_meters,heart_rate,speed_mps,steps_per_minute&limit=5&order=timestamp_seconds.desc" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}" | jq '.'
  fi
else
  echo "⚠️ No samples found yet - FIT processor may still be running"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "Check Supabase Edge Function logs for detailed processing information!"
