#!/bin/bash

# ============================================================================
# Test Notification with Specific Payload
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

if [ -z "$SERVICE_KEY" ]; then
  echo "❌ Error: SUPABASE_SERVICE_ROLE_KEY not set"
  echo ""
  echo "Get it from: Supabase Dashboard → Settings → API → service_role key"
  echo "Then run:"
  echo "  export SUPABASE_SERVICE_ROLE_KEY='your-key-here'"
  echo "  ./test_notification_now.sh"
  exit 1
fi

echo "📱 Testing notification with your payload..."
echo ""

PAYLOAD='{
  "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
  "activity_id": "test-123",
  "activity_name": "Test Run",
  "activity_type": "Running",
  "distance_meters": 5000,
  "duration_seconds": 1800
}'

echo "📋 Payload:"
echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
echo ""

echo "📤 Sending notification..."
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/garmin-activity-notify" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q "\"success\":true"; then
  echo "✅ Notification sent successfully!"
  echo ""
  echo "Check your device for:"
  echo "   Title: Distance: 5.0 km - Pace: 6:00 m/km"
  echo "   Body: Check your HYKA digital twin for your upcoming event"
else
  echo "❌ Notification failed"
  echo ""
  echo "Check Supabase logs for details:"
  echo "   Dashboard → Edge Functions → garmin-activity-notify → Logs"
fi

echo ""


