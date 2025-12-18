#!/bin/bash

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

echo "=== Notification Test with Detailed Response ==="
echo ""

read -p "Enter your user_id (UUID): " USER_ID

if [ -z "$USER_ID" ]; then
  echo "Error: User ID is required"
  exit 1
fi

# Test values
DISTANCE_METERS=30500
DURATION_SECONDS=6619
ACTIVITY_ID="test-$(date +%s)"

echo ""
echo "Test Parameters:"
echo "  Distance: 30.5 km (${DISTANCE_METERS} meters)"
echo "  Pace: 3:37 m/km"
echo "  Duration: ${DURATION_SECONDS} seconds"
echo "  User ID: ${USER_ID}"
echo "  Activity ID: ${ACTIVITY_ID}"
echo ""

echo "Sending notification..."
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${SUPABASE_URL}/functions/v1/garmin-activity-notify" \
  -H "Content-Type: application/json" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -d "{
    \"user_id\": \"${USER_ID}\",
    \"activity_id\": \"${ACTIVITY_ID}\",
    \"activity_name\": \"Test Run\",
    \"activity_type\": \"Running\",
    \"distance_meters\": ${DISTANCE_METERS},
    \"duration_seconds\": ${DURATION_SECONDS}
  }")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo ""
echo "Response Body:"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

echo ""
echo ""
echo "=== Troubleshooting Steps ==="
echo ""
echo "If devices_notified = 0, check:"
echo "  1. Device token is registered: SELECT * FROM user_devices WHERE user_id = '${USER_ID}';"
echo "  2. push_enabled = true in user_devices table"
echo "  3. App has notification permissions enabled"
echo "  4. Device token was registered after app launch"
echo ""
echo "If devices_notified > 0 but you didn't receive it:"
echo "  1. Check Supabase Edge Function logs for APNs errors"
echo "  2. Verify APNs credentials are configured in Supabase secrets"
echo "  3. Check if device token is still valid (not expired/uninstalled)"
echo "  4. Ensure app is running or in background (not force-closed)"
