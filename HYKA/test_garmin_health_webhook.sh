#!/bin/bash

# Test Garmin Health Webhook Endpoint
# This script helps diagnose why health webhooks aren't being received

SUPABASE_URL="${SUPABASE_URL:-https://gvfhtiljkybbrbxoyqsq.supabase.co}"
WEBHOOK_URL="${SUPABASE_URL}/functions/v1/garmin-health-webhook"

echo "🧪 Testing Garmin Health Webhook Endpoint"
echo ""
echo "Webhook URL: $WEBHOOK_URL"
echo ""

# Test 1: Check if endpoint is accessible
echo "1️⃣ Testing endpoint accessibility..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "$WEBHOOK_URL")
if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Endpoint is accessible (HTTP $HTTP_CODE)"
else
    echo "❌ Endpoint returned HTTP $HTTP_CODE"
    echo "   This might indicate the Edge Function is not deployed or not accessible"
fi
echo ""

# Test 2: Send a test webhook payload (simulating Garmin)
echo "2️⃣ Sending test webhook payload (simulating Garmin)..."
TEST_PAYLOAD='{
  "userId": "TEST_USER_ID",
  "dailies": [{
    "userId": "TEST_USER_ID",
    "calendarDate": "'$(date +%Y-%m-%d)'",
    "steps": 10000,
    "activeKilocalories": 500,
    "bmrKilocalories": 1500,
    "restingHeartRateInBeatsPerMinute": 60
  }]
}'

RESPONSE=$(curl -s -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin-Health-Webhook-Test" \
  -d "$TEST_PAYLOAD")

echo "   Response: $RESPONSE"
echo ""

# Test 3: Check Supabase logs
echo "3️⃣ Next Steps:"
echo ""
echo "   Check Supabase Edge Function logs:"
echo "   - Go to: Supabase Dashboard → Edge Functions → garmin-health-webhook → Logs"
echo "   - Look for: '🏥 Garmin Health Webhook received'"
echo "   - Check timestamp around 12:45 (when your watch synced)"
echo ""
echo "   If you see NO logs at all:"
echo "   - Garmin is not sending webhooks to your endpoint"
echo "   - Possible reasons:"
echo "     1. Webhook URL not verified/activated in Garmin Portal"
echo "     2. Garmin only sends webhooks for certain events (not all syncs)"
echo "     3. Webhook endpoint not accessible from Garmin's servers"
echo "     4. Health data is sent via garmin-activity-push instead"
echo ""
echo "   If you see logs but no data stored:"
echo "   - Check for: '⚠️ No HYKA user found for Garmin user'"
echo "   - This means garmin_user_id doesn't match"
echo "   - Verify garmin_user_id in garmin_connections table"
echo ""
