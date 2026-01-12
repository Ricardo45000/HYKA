#!/bin/bash

# ============================================================================
# Debug Notification Issues
# ============================================================================

USER_ID="${1:-84b13928-a931-4841-9289-bf2ab30cb07d}"
SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SERVICE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

if [ -z "$SERVICE_KEY" ]; then
  echo "❌ Error: SUPABASE_SERVICE_ROLE_KEY not set"
  exit 1
fi

echo "🔍 Debugging notification for user: $USER_ID"
echo ""

# 1. Check device tokens
echo "1️⃣ Checking device tokens..."
DEVICE_RESPONSE=$(curl -s -X GET "$SUPABASE_URL/rest/v1/user_devices?user_id=eq.$USER_ID&push_enabled=eq.true&select=*" \
  -H "apikey: $SERVICE_KEY" \
  -H "Authorization: Bearer $SERVICE_KEY")

echo "$DEVICE_RESPONSE" | jq '.' 2>/dev/null || echo "$DEVICE_RESPONSE"
echo ""

# 2. Check APNs configuration (via function logs)
echo "2️⃣ Sending test notification and checking response..."
NOTIFY_RESPONSE=$(curl -s -X POST "$SUPABASE_URL/functions/v1/garmin-activity-notify" \
  -H "Authorization: Bearer $SERVICE_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"activity_id\": \"debug-test-$(date +%s)\",
    \"activity_name\": \"Debug Test\",
    \"activity_type\": \"Running\",
    \"distance_meters\": 5000,
    \"duration_seconds\": 1800
  }")

echo "Response:"
echo "$NOTIFY_RESPONSE" | jq '.' 2>/dev/null || echo "$NOTIFY_RESPONSE"
echo ""

# 3. Check if APNs secrets are configured
echo "3️⃣ Checking APNs configuration..."
echo "   (Check Supabase Dashboard → Settings → Edge Functions → Secrets)"
echo "   Required secrets:"
echo "   - APNS_KEY_ID"
echo "   - APNS_TEAM_ID"
echo "   - APNS_KEY_CONTENT"
echo "   - APNS_BUNDLE_ID (optional, defaults to app.hyka.com)"
echo ""

# 4. Instructions
echo "4️⃣ Next steps:"
echo "   - Check Supabase Dashboard → Edge Functions → garmin-activity-notify → Logs"
echo "   - Look for:"
echo "     ✅ 'Push notification sent to device'"
echo "     ❌ 'APNs error'"
echo "     ❌ 'APNs not configured'"
echo "   - Verify device token is valid (not expired/uninstalled)"
echo ""


