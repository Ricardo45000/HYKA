#!/bin/bash

# Test Notification with curl
# Distance: 30.5 km, Pace: 3:37 m/km

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
FUNCTION_URL="${SUPABASE_URL}/functions/v1/garmin-activity-notify"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

# Test values
DISTANCE_METERS=30500
DURATION_SECONDS=6619
ACTIVITY_ID="test-$(date +%s)"

echo "Enter your user_id (UUID):"
read USER_ID

if [ -z "$USER_ID" ]; then
  echo "Error: User ID is required"
  exit 1
fi

echo ""
echo "Sending test notification..."
echo "Distance: 30.5 km, Pace: 3:37 m/km"
echo ""

curl -X POST "${FUNCTION_URL}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "{
    \"user_id\": \"${USER_ID}\",
    \"activity_id\": \"${ACTIVITY_ID}\",
    \"activity_name\": \"Test Run\",
    \"activity_type\": \"Running\",
    \"distance_meters\": ${DISTANCE_METERS},
    \"duration_seconds\": ${DURATION_SECONDS}
  }" | jq '.'

echo ""
