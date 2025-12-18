#!/bin/bash

# ============================================================================
# Strava Webhook Setup Script
# ============================================================================
# This script creates a webhook subscription in Strava using their API
# ============================================================================

# Configuration
STRAVA_CLIENT_ID="${STRAVA_CLIENT_ID:-your_client_id}"
STRAVA_CLIENT_SECRET="${STRAVA_CLIENT_SECRET:-your_client_secret}"
WEBHOOK_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook"
VERIFY_TOKEN="strava-webhook-verify-token-2025"

echo "🔧 Strava Webhook Setup"
echo "======================"
echo ""
echo "This script will create a webhook subscription in Strava."
echo ""
echo "Webhook URL: $WEBHOOK_URL"
echo "Verify Token: $VERIFY_TOKEN"
echo ""

# Check if credentials are set
if [ "$STRAVA_CLIENT_ID" = "your_client_id" ] || [ "$STRAVA_CLIENT_SECRET" = "your_client_secret" ]; then
    echo "⚠️  Please set your Strava credentials:"
    echo "   export STRAVA_CLIENT_ID=your_actual_client_id"
    echo "   export STRAVA_CLIENT_SECRET=your_actual_client_secret"
    echo ""
    echo "Or edit this script and replace the placeholder values."
    exit 1
fi

echo "📤 Creating webhook subscription..."
echo ""

# Create webhook subscription
RESPONSE=$(curl -X POST "https://www.strava.com/api/v3/push_subscriptions" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_id\": \"$STRAVA_CLIENT_ID\",
    \"client_secret\": \"$STRAVA_CLIENT_SECRET\",
    \"callback_url\": \"$WEBHOOK_URL\",
    \"verify_token\": \"$VERIFY_TOKEN\"
  }" 2>/dev/null)

echo "Response: $RESPONSE"
echo ""

# Check if successful
if echo "$RESPONSE" | grep -q "id"; then
    echo "✅ Webhook subscription created successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Strava will send a verification GET request to your webhook"
    echo "2. Check Supabase Edge Function logs to confirm verification"
    echo "3. Create a test activity on Strava to test the webhook"
else
    echo "❌ Failed to create webhook subscription"
    echo ""
    echo "Common issues:"
    echo "- Invalid client_id or client_secret"
    echo "- Webhook URL already exists"
    echo "- Check the response above for error details"
fi

echo ""
echo "📋 To list existing webhooks:"
echo "curl -X GET \"https://www.strava.com/api/v3/push_subscriptions?client_id=$STRAVA_CLIENT_ID&client_secret=$STRAVA_CLIENT_SECRET\""
echo ""
echo "📋 To delete a webhook:"
echo "curl -X DELETE \"https://www.strava.com/api/v3/push_subscriptions/{subscription_id}?client_id=$STRAVA_CLIENT_ID&client_secret=$STRAVA_CLIENT_SECRET\""


