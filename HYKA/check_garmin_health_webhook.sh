#!/bin/bash

# Check Garmin Health Webhook Status
# This script helps diagnose why health data isn't syncing

echo "🔍 Checking Garmin Health Webhook Status..."
echo ""

# Get Supabase project details
SUPABASE_URL="${SUPABASE_URL:-https://gvfhtiljkybbrbxoyqsq.supabase.co}"
HEALTH_WEBHOOK_URL="${SUPABASE_URL}/functions/v1/garmin-health-webhook"
ACTIVITY_WEBHOOK_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"

echo "📋 Webhook URLs:"
echo "   Health Webhook: $HEALTH_WEBHOOK_URL"
echo "   Activity Webhook: $ACTIVITY_WEBHOOK_URL"
echo ""

echo "✅ Next Steps:"
echo ""
echo "1. Check Garmin Developer Portal:"
echo "   - Go to: https://developer.garmin.com/my-apps/"
echo "   - Select your app"
echo "   - Navigate to 'Webhooks' or 'API Settings'"
echo "   - Verify webhook URLs are registered:"
echo "     • Health: $HEALTH_WEBHOOK_URL"
echo "     • Activity: $ACTIVITY_WEBHOOK_URL"
echo ""
echo "2. Check Supabase Edge Function Logs:"
echo "   - Go to: Supabase Dashboard → Edge Functions → garmin-health-webhook → Logs"
echo "   - Look for: '🏥 Garmin Health Webhook received'"
echo "   - Also check: garmin-activity-push logs for '🏥 Processing Health Data'"
echo ""
echo "3. Manual Health Sync (Temporary Fix):"
echo "   - Use the garmin-health-sync Edge Function to pull today's data"
echo "   - See GARMIN_HEALTH_WEBHOOK_SETUP.md for instructions"
echo ""
echo "4. Verify Garmin User ID Match:"
echo "   - Check that garmin_user_id in garmin_connections matches the user ID"
echo "   - Garmin sends webhooks with their user ID, which must match your database"
echo ""
