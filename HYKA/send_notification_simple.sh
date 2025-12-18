#!/bin/bash

# Simple script to send a test notification
# Usage: ./send_notification_simple.sh [user_id]

USER_ID="${1:-84b13928-a931-4841-9289-bf2ab30cb07d}"
SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"

# You need to set this - get it from Supabase Dashboard → Settings → API → service_role key
SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

if [ -z "$SERVICE_KEY" ]; then
  echo "❌ Error: SUPABASE_SERVICE_ROLE_KEY not set"
  echo ""
  echo "Get it from: Supabase Dashboard → Settings → API → service_role key"
  echo "Then run:"
  echo "  export SUPABASE_SERVICE_ROLE_KEY='your-key-here'"
  echo "  ./send_notification_simple.sh $USER_ID"
  exit 1
fi

echo "📱 Sending test notification to user: $USER_ID"
echo ""

# Test activity: 5km in 30 minutes (6:00 m/km pace)
curl -X POST "$SUPABASE_URL/functions/v1/garmin-activity-notify" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"activity_id\": \"test-$(date +%s)\",
    \"activity_name\": \"Test Run\",
    \"activity_type\": \"Running\",
    \"distance_meters\": 5000,
    \"duration_seconds\": 1800
  }" | jq '.'

echo ""
echo "✅ Done! Check your device for the notification."


