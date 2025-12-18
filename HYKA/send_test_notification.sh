#!/bin/bash

# ============================================================================
# Send Test Notification to Specific User
# ============================================================================

# Configuration
SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SUPABASE_SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"  # Set this as environment variable

# User ID - Replace with your user ID
USER_ID="${1:-84b13928-a931-4841-9289-bf2ab30cb07d}"

# Activity details (optional - for testing)
ACTIVITY_ID="${2:-test-activity-$(date +%s)}"
ACTIVITY_NAME="${3:-Test Run}"
DISTANCE_METERS="${4:-5000}"  # 5km
DURATION_SECONDS="${5:-1800}"  # 30 minutes

echo "📱 Sending test notification to user: $USER_ID"
echo ""

# Calculate pace
DISTANCE_KM=$(echo "scale=1; $DISTANCE_METERS / 1000" | bc)
DURATION_MIN=$(echo "scale=2; $DURATION_SECONDS / 60" | bc)
PACE_DECIMAL=$(echo "scale=2; $DURATION_MIN / $DISTANCE_KM" | bc)
PACE_MIN=$(echo "$PACE_DECIMAL" | cut -d. -f1)
PACE_SEC=$(echo "scale=0; ($PACE_DECIMAL - $PACE_MIN) * 60" | bc | cut -d. -f1)
PACE_SEC=$(printf "%02d" $PACE_SEC)
PACE_STRING="${PACE_MIN}:${PACE_SEC}"

echo "📊 Activity Details:"
echo "   Activity ID: $ACTIVITY_ID"
echo "   Name: $ACTIVITY_NAME"
echo "   Distance: $DISTANCE_KM km"
echo "   Duration: $DURATION_SECONDS seconds ($(echo "scale=1; $DURATION_SECONDS / 60" | bc) minutes)"
echo "   Pace: $PACE_STRING m/km"
echo ""

# Prepare payload
PAYLOAD=$(cat <<EOF
{
  "user_id": "$USER_ID",
  "activity_id": "$ACTIVITY_ID",
  "activity_name": "$ACTIVITY_NAME",
  "activity_type": "Running",
  "distance_meters": $DISTANCE_METERS,
  "duration_seconds": $DURATION_SECONDS
}
EOF
)

echo "📤 Sending notification request..."
echo "   URL: $SUPABASE_URL/functions/v1/garmin-activity-notify"
echo ""

# Check if service key is set
if [ -z "$SUPABASE_SERVICE_KEY" ]; then
  echo "❌ Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set"
  echo ""
  echo "Set it with:"
  echo "  export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key'"
  echo ""
  echo "Or pass it directly:"
  echo "  SUPABASE_SERVICE_ROLE_KEY='your-key' ./send_test_notification.sh [user_id] [activity_id] [name] [distance_m] [duration_s]"
  exit 1
fi

# Send notification
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/garmin-activity-notify" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

# Check if successful
if echo "$RESPONSE" | grep -q "\"success\":true"; then
  echo "✅ Notification sent successfully!"
  echo ""
  echo "Check your device for the notification:"
  echo "   Title: Distance: $DISTANCE_KM km - Pace: $PACE_STRING m/km"
  echo "   Body: Check your HYKA digital twin for your upcoming event"
else
  echo "❌ Notification failed"
  echo ""
  echo "Check the response above for error details"
fi

echo ""
echo "Usage:"
echo "  ./send_test_notification.sh [user_id] [activity_id] [name] [distance_meters] [duration_seconds]"
echo ""
echo "Example:"
echo "  ./send_test_notification.sh 84b13928-a931-4841-9289-bf2ab30cb07d test-123 'Morning Run' 10000 2400"


