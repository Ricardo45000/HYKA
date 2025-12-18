#!/bin/bash

# Test Garmin Push with Real Activity from Browser
# Usage: ./test_garmin_push_with_activity.sh <ACTIVITY_ID> <GARMIN_USER_ID>

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"

# Get activity ID from command line or prompt
if [ -z "$1" ]; then
  echo "=== Garmin Push Test with Real Activity ==="
  echo ""
  echo "To get an activity ID:"
  echo "1. Go to https://connect.garmin.com/modern/activities"
  echo "2. Click on a running activity"
  echo "3. Look at the URL - it will be like: /modern/activity/1234567890"
  echo "   The number at the end is the activity ID"
  echo ""
  read -p "Enter Activity ID from Garmin Connect: " ACTIVITY_ID
  read -p "Enter Garmin User ID (or press Enter to auto-detect): " GARMIN_USER_ID
else
  ACTIVITY_ID="$1"
  GARMIN_USER_ID="$2"
fi

# Try to get Garmin User ID from database if not provided
if [ -z "$GARMIN_USER_ID" ]; then
  echo ""
  echo "Fetching Garmin connection from database..."
  GARMIN_CONNECTION=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_connections?user_id=eq.${USER_ID}&select=garmin_user_id" \
    -H "apikey: ${ANON_KEY}" \
    -H "Authorization: Bearer ${ANON_KEY}")
  
  GARMIN_USER_ID=$(echo "$GARMIN_CONNECTION" | jq -r '.[0].garmin_user_id // empty' 2>/dev/null)
  
  if [ -z "$GARMIN_USER_ID" ] || [ "$GARMIN_USER_ID" = "null" ]; then
    echo "⚠️ Could not find Garmin User ID in database"
    echo "Please provide it manually or connect Garmin in the app first"
    read -p "Enter Garmin User ID: " GARMIN_USER_ID
  else
    echo "✅ Found Garmin User ID: ${GARMIN_USER_ID}"
  fi
fi

if [ -z "$ACTIVITY_ID" ] || [ -z "$GARMIN_USER_ID" ]; then
  echo "❌ Missing required parameters"
  exit 1
fi

echo ""
echo "=== Test Configuration ==="
echo "Activity ID: ${ACTIVITY_ID}"
echo "Garmin User ID: ${GARMIN_USER_ID}"
echo ""

# Construct the push payload exactly as Garmin sends it
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
      "startTimeInSeconds": $(date +%s)
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
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo ""
echo "Response:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

echo "=== What Happens Next ==="
echo "1. garmin-activity-push receives the webhook"
echo "2. Looks up HYKA user_id from garmin_user_id"
echo "3. Forwards to garmin-activity-store with file data"
echo "4. garmin-activity-store downloads FIT file from:"
echo "   ${CALLBACK_URL}"
echo "5. Stores FIT file in garmin_fit_files table"
echo "6. Stores activity in garmin_activities table"
echo "7. Calls garmin-activity-notify to send push notification"
echo ""
echo "Check Supabase Edge Function logs to see the full journey!"
