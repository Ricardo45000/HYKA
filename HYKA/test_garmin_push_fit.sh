#!/bin/bash

# Test garmin-activity-push with FIT file data
# This simulates what Garmin sends when a new activity with FIT file is available

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"

echo "=== Test Garmin Activity Push with FIT File ==="
echo ""

# Try to get garmin_user_id from connection
echo "Checking for Garmin connection..."
GARMIN_CONNECTION=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_connections?user_id=eq.${USER_ID}&select=garmin_user_id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

GARMIN_USER_ID=$(echo "$GARMIN_CONNECTION" | jq -r '.[0].garmin_user_id // empty')

if [ -z "$GARMIN_USER_ID" ] || [ "$GARMIN_USER_ID" = "null" ]; then
  echo "⚠️ No Garmin connection found in database"
  echo ""
  echo "You can either:"
  echo "  1. Connect Garmin in the app first, then run this script again"
  echo "  2. Provide a Garmin User ID manually to test the webhook format"
  echo ""
  read -p "Enter Garmin User ID (or press Enter to use a test ID): " MANUAL_GARMIN_ID
  
  if [ -z "$MANUAL_GARMIN_ID" ]; then
    GARMIN_USER_ID="test-garmin-user-123"
    echo "Using test Garmin User ID: ${GARMIN_USER_ID}"
    echo "Note: This will fail at the user lookup step, but you can see the webhook format"
  else
    GARMIN_USER_ID="$MANUAL_GARMIN_ID"
  fi
else
  echo "✅ Found Garmin User ID: ${GARMIN_USER_ID}"
fi

echo ""

# Create a test activity ID
ACTIVITY_ID="test-activity-$(date +%s)"

echo "Creating test payload with FIT file data..."
echo "  Activity ID: ${ACTIVITY_ID}"
echo "  Garmin User ID: ${GARMIN_USER_ID}"
echo ""

# Create payload simulating Garmin's activityFiles push
# Garmin sends FIT file metadata with a callbackUrl to download the actual file
# Note: For real testing, you'd need a real callbackUrl from an actual Garmin activity
PAYLOAD=$(cat <<JSON
{
  "activityFiles": [
    {
      "userId": "${GARMIN_USER_ID}",
      "summaryId": "${ACTIVITY_ID}",
      "activityId": "${ACTIVITY_ID}",
      "activityType": "running",
      "callbackUrl": "https://connectapi.garmin.com/activity-service/activity/${ACTIVITY_ID}/file/fit",
      "fileType": "fit",
      "startTimeInSeconds": $(date +%s)
    }
  ]
}
JSON
)

echo "Payload structure:"
echo "$PAYLOAD" | jq '.'
echo ""

echo "Sending test push to garmin-activity-push..."
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
echo ""
echo "=== What happens next ==="
echo "1. garmin-activity-push receives the webhook"
echo "2. It looks up your HYKA user_id from garmin_user_id"
echo "3. It forwards to garmin-activity-store with the file data"
echo "4. garmin-activity-store downloads the FIT file from callbackUrl"
echo "5. Stores FIT file in garmin_fit_files table"
echo "6. Processes and stores the activity"
echo "7. Sends a notification via garmin-activity-notify"
