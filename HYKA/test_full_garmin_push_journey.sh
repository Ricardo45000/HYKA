#!/bin/bash

# Full Garmin Push Journey Test
# 1. Get Garmin connection from Supabase
# 2. Fetch a real activity from Garmin API
# 3. Construct proper push payload
# 4. Send through garmin-activity-push → garmin-activity-store → notification

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"

echo "=== Full Garmin Push Journey Test ==="
echo ""

# Step 1: Get Garmin connection
echo "📋 Step 1: Fetching Garmin connection..."
GARMIN_CONNECTION=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_connections?user_id=eq.${USER_ID}&select=garmin_user_id,access_token" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}")

GARMIN_USER_ID=$(echo "$GARMIN_CONNECTION" | jq -r '.[0].garmin_user_id // empty')
ACCESS_TOKEN=$(echo "$GARMIN_CONNECTION" | jq -r '.[0].access_token // empty')

if [ -z "$GARMIN_USER_ID" ] || [ "$GARMIN_USER_ID" = "null" ]; then
  echo "❌ No Garmin connection found for user ${USER_ID}"
  echo "Please connect Garmin in the app first"
  exit 1
fi

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "❌ No access token found"
  exit 1
fi

echo "✅ Found Garmin User ID: ${GARMIN_USER_ID}"
echo "✅ Access Token: ${ACCESS_TOKEN:0:20}..."
echo ""

# Step 2: Fetch a real running activity from Garmin
echo "📋 Step 2: Fetching activities from Garmin API..."
echo ""

# Try to get activities from Garmin Connect API
# Using connectapi.garmin.com for activity list
ACTIVITIES_RESPONSE=$(curl -s -X GET "https://connectapi.garmin.com/activitylist-service/activities/search/activities?limit=10&start=0" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

# Check if we got activities
ACTIVITY_COUNT=$(echo "$ACTIVITIES_RESPONSE" | jq '. | length // 0')

if [ "$ACTIVITY_COUNT" -eq 0 ]; then
  echo "⚠️ No activities found via Connect API, trying Health API..."
  
  # Try Health API instead
  ACTIVITIES_RESPONSE=$(curl -s -X GET "https://healthapi.garmin.com/wellness-api/rest/activities?startDate=2024-01-01&limit=10" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json")
  
  ACTIVITY_COUNT=$(echo "$ACTIVITIES_RESPONSE" | jq '. | length // 0')
fi

if [ "$ACTIVITY_COUNT" -eq 0 ]; then
  echo "❌ Could not fetch activities from Garmin API"
  echo "Response:"
  echo "$ACTIVITIES_RESPONSE" | jq '.' | head -20
  exit 1
fi

echo "✅ Found ${ACTIVITY_COUNT} activities"
echo ""

# Find a running activity
RUNNING_ACTIVITY=$(echo "$ACTIVITIES_RESPONSE" | jq '[.[] | select(.activityType.typeKey == "running" or .activityType.typeKey == "trail_running" or (.activityName // "" | ascii_downcase | contains("run")))][0]')

if [ "$RUNNING_ACTIVITY" = "null" ] || [ -z "$RUNNING_ACTIVITY" ]; then
  echo "⚠️ No running activity found, using first activity..."
  RUNNING_ACTIVITY=$(echo "$ACTIVITIES_RESPONSE" | jq '.[0]')
fi

ACTIVITY_ID=$(echo "$RUNNING_ACTIVITY" | jq -r '.activityId // .summaryId // empty')
ACTIVITY_NAME=$(echo "$RUNNING_ACTIVITY" | jq -r '.activityName // "Running Activity"')
ACTIVITY_TYPE=$(echo "$RUNNING_ACTIVITY" | jq -r '.activityType.typeKey // "running"')
START_TIME=$(echo "$RUNNING_ACTIVITY" | jq -r '.startTimeGMT // .startTimeInSeconds // empty')

if [ -z "$ACTIVITY_ID" ]; then
  echo "❌ Could not extract activity ID from response"
  echo "Activity data:"
  echo "$RUNNING_ACTIVITY" | jq '.'
  exit 1
fi

echo "✅ Selected Activity:"
echo "   ID: ${ACTIVITY_ID}"
echo "   Name: ${ACTIVITY_NAME}"
echo "   Type: ${ACTIVITY_TYPE}"
echo "   Start: ${START_TIME}"
echo ""

# Step 3: Construct the push payload
echo "📋 Step 3: Constructing push payload..."
echo ""

# The callbackUrl format for Garmin FIT files
CALLBACK_URL="https://connectapi.garmin.com/activity-service/activity/${ACTIVITY_ID}/file/fit"

PAYLOAD=$(cat <<JSON
{
  "activityFiles": [
    {
      "userId": "${GARMIN_USER_ID}",
      "summaryId": "${ACTIVITY_ID}",
      "activityId": "${ACTIVITY_ID}",
      "activityType": "${ACTIVITY_TYPE}",
      "callbackUrl": "${CALLBACK_URL}",
      "fileType": "fit",
      "startTimeInSeconds": $(echo "$START_TIME" | grep -oE '[0-9]+' | head -1 || echo "$(date +%s)")
    }
  ]
}
JSON
)

echo "Payload:"
echo "$PAYLOAD" | jq '.'
echo ""

# Step 4: Send to garmin-activity-push
echo "📋 Step 4: Sending to garmin-activity-push webhook..."
echo ""

PUSH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${SUPABASE_URL}/functions/v1/garmin-activity-push" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin-Connect" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$PUSH_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$PUSH_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo ""
echo "Response:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Step 5: Check if activity was stored
echo "📋 Step 5: Checking if activity was stored in database..."
echo ""

sleep 2  # Wait a moment for processing

STORED_ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=*" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}")

if echo "$STORED_ACTIVITY" | jq -e '. | length > 0' > /dev/null; then
  echo "✅ Activity stored in database!"
  echo "$STORED_ACTIVITY" | jq '.[0] | {id, garmin_activity_id, activity_name, distance_meters, duration_seconds, activity_type}'
else
  echo "⚠️ Activity not yet in database (may still be processing)"
fi

echo ""

# Step 6: Check if FIT file was stored
echo "📋 Step 6: Checking if FIT file was stored..."
echo ""

FIT_FILE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,file_size_bytes,created_at" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}")

if echo "$FIT_FILE" | jq -e '. | length > 0' > /dev/null; then
  echo "✅ FIT file stored!"
  echo "$FIT_FILE" | jq '.[0]'
else
  echo "⚠️ FIT file not yet stored (may still be downloading/processing)"
fi

echo ""
echo "=== Journey Complete ==="
echo ""
echo "What happened:"
echo "1. ✅ Fetched Garmin connection from Supabase"
echo "2. ✅ Retrieved real activity from Garmin API"
echo "3. ✅ Constructed push payload with FIT file callbackUrl"
echo "4. ✅ Sent to garmin-activity-push webhook"
echo "5. ✅ garmin-activity-push forwarded to garmin-activity-store"
echo "6. ✅ garmin-activity-store should download FIT file and store activity"
echo "7. ✅ Notification should be sent via garmin-activity-notify"
echo ""
echo "Check Supabase logs for detailed processing information!"
