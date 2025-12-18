#!/bin/bash

# ============================================================================
# Create Strava Webhook Subscription
# ============================================================================

echo "🔧 Creating Strava Webhook Subscription..."
echo ""

# Your Strava credentials
CLIENT_ID="184009"
CLIENT_SECRET="9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45"
WEBHOOK_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook"
VERIFY_TOKEN="strava-webhook-verify-token-2025"

echo "📤 Creating webhook subscription..."
echo "   Client ID: $CLIENT_ID"
echo "   Webhook URL: $WEBHOOK_URL"
echo "   Verify Token: $VERIFY_TOKEN"
echo ""

# Create webhook subscription
RESPONSE=$(curl -X POST "https://www.strava.com/api/v3/push_subscriptions" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_id\": \"$CLIENT_ID\",
    \"client_secret\": \"$CLIENT_SECRET\",
    \"callback_url\": \"$WEBHOOK_URL\",
    \"verify_token\": \"$VERIFY_TOKEN\"
  }" 2>/dev/null)

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

# Check if successful
if echo "$RESPONSE" | grep -q "\"id\""; then
    WEBHOOK_ID=$(echo "$RESPONSE" | jq -r '.id' 2>/dev/null || echo "$RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
    echo "✅ Webhook subscription created successfully!"
    echo "   Webhook ID: $WEBHOOK_ID"
    echo ""
    echo "Next steps:"
    echo "1. Strava will send a verification GET request to your webhook"
    echo "2. Check Supabase Edge Function logs to confirm verification"
    echo "3. Create a test activity on Strava to test the webhook"
else
    echo "❌ Failed to create webhook subscription"
    echo ""
    if echo "$RESPONSE" | grep -q "already exists"; then
        echo "⚠️  Webhook may already exist. Listing existing webhooks..."
        echo ""
        curl -X GET "https://www.strava.com/api/v3/push_subscriptions?client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET" | jq '.' 2>/dev/null || curl -X GET "https://www.strava.com/api/v3/push_subscriptions?client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET"
    fi
fi

echo ""
echo "📋 To list all webhooks:"
echo "curl -X GET \"https://www.strava.com/api/v3/push_subscriptions?client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET\""
echo ""
echo "📋 To delete a webhook (replace SUBSCRIPTION_ID):"
echo "curl -X DELETE \"https://www.strava.com/api/v3/push_subscriptions/SUBSCRIPTION_ID?client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET\""


