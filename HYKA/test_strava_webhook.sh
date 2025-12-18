#!/bin/bash

# ============================================================================
# Test Strava Webhook Setup
# ============================================================================

CLIENT_ID="184009"
CLIENT_SECRET="9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45"
WEBHOOK_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook"

echo "🔍 Testing Strava Webhook Setup"
echo ""

# 1. Check if webhook subscription exists
echo "1️⃣ Checking webhook subscription..."
RESPONSE=$(curl -s -X GET "https://www.strava.com/api/v3/push_subscriptions?client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")

if echo "$RESPONSE" | grep -q "\"id\""; then
    echo "✅ Webhook subscription found!"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    echo ""
else
    echo "❌ No webhook subscription found!"
    echo "   Response: $RESPONSE"
    echo ""
    echo "   You need to create the webhook first:"
    echo "   ./create_strava_webhook.sh"
    exit 1
fi

# 2. Test webhook verification endpoint
echo "2️⃣ Testing webhook verification endpoint..."
VERIFY_RESPONSE=$(curl -s -X GET "$WEBHOOK_URL?hub.mode=subscribe&hub.verify_token=strava-webhook-verify-token-2025&hub.challenge=test123")

if echo "$VERIFY_RESPONSE" | grep -q "test123"; then
    echo "✅ Webhook verification endpoint works!"
    echo "   Response: $VERIFY_RESPONSE"
else
    echo "❌ Webhook verification failed!"
    echo "   Response: $VERIFY_RESPONSE"
    echo ""
    echo "   Check if the Edge Function is deployed:"
    echo "   cd supabase && npx supabase functions deploy strava-activity-webhook --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt"
fi

echo ""
echo "3️⃣ Database Connection Check:"
echo "   Your Strava connection:"
echo "   - strava_athlete_id: 107848938"
echo "   - user_id: 84b13928-a931-4841-9289-bf2ab30cb07d"
echo ""
echo "   When Strava sends a webhook, it will include:"
echo "   - owner_id: 107848938 (should match your strava_athlete_id)"
echo ""
echo "4️⃣ Next Steps:"
echo "   - Create a test activity on Strava"
echo "   - Check Supabase Edge Function logs for 'strava-activity-webhook'"
echo "   - Look for: '📥 Strava Activity Webhook started'"
echo "   - Look for: '📋 Parsed webhook event' with owner_id: 107848938"
echo ""


