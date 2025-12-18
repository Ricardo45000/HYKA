#!/bin/bash

# ============================================================================
# Check Strava Webhook Subscription Status
# ============================================================================

CLIENT_ID="184009"
CLIENT_SECRET="9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45"

echo "🔍 Checking Strava Webhook Subscriptions..."
echo ""

# List all webhook subscriptions
RESPONSE=$(curl -s -X GET "https://www.strava.com/api/v3/push_subscriptions?client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

# Check if webhooks exist
if echo "$RESPONSE" | grep -q "\"id\""; then
    echo "✅ Webhook subscription(s) found!"
    echo ""
    
    # Extract webhook details
    WEBHOOK_ID=$(echo "$RESPONSE" | jq -r '.[0].id' 2>/dev/null || echo "N/A")
    CALLBACK_URL=$(echo "$RESPONSE" | jq -r '.[0].callback_url' 2>/dev/null || echo "N/A")
    
    echo "📋 Webhook Details:"
    echo "   ID: $WEBHOOK_ID"
    echo "   Callback URL: $CALLBACK_URL"
    echo ""
    
    echo "⚠️  IMPORTANT: Strava webhooks only trigger for activities created by users"
    echo "   who have connected their Strava account to your app."
    echo ""
    echo "   Your friend's activity will NOT trigger a webhook unless:"
    echo "   1. Your friend has connected their Strava account to HYKA"
    echo "   2. The activity was created by your friend (not imported)"
    echo ""
else
    echo "❌ No webhook subscriptions found!"
    echo ""
    echo "You need to create a webhook subscription first."
    echo "Run: ./create_strava_webhook.sh"
fi

echo ""
echo "📝 To test the webhook:"
echo "   1. Make sure you have connected your Strava account in the HYKA app"
echo "   2. Create a test activity on Strava (or record one with your watch)"
echo "   3. Check Supabase Edge Function logs for 'strava-activity-webhook'"
echo ""


