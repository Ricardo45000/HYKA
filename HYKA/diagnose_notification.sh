#!/bin/bash

echo "=== Notification Diagnostic Tool ==="
echo ""
echo "This will help diagnose why notifications aren't being received."
echo ""

# Get user ID
read -p "Enter your user_id (UUID): " USER_ID

if [ -z "$USER_ID" ]; then
  echo "Error: User ID is required"
  exit 1
fi

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

echo ""
echo "1. Checking if device token is registered..."
echo ""

# Check device tokens
curl -s -X POST "${SUPABASE_URL}/rest/v1/user_devices?select=user_id,device_token,device_type,push_enabled,created_at&user_id=eq.${USER_ID}" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | jq '.'

echo ""
echo "2. Testing notification function..."
echo ""

# Test notification
DISTANCE_METERS=30500
DURATION_SECONDS=6619
ACTIVITY_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')

RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/functions/v1/garmin-activity-notify" \
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

echo "$RESPONSE" | jq '.'

echo ""
echo "3. Common issues to check:"
echo "   - Is push_enabled = true in user_devices table?"
echo "   - Is the device_token valid and registered?"
echo "   - Are APNs credentials configured in Supabase secrets?"
echo "   - Is the app running and has notification permissions?"
echo "   - Check Supabase Edge Function logs for errors"
