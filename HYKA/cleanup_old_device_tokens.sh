#!/bin/bash

# ============================================================================
# Cleanup Old Device Tokens After Bundle ID Change
# ============================================================================
# This script helps delete old device tokens that were registered with
# a previous bundle ID so they can be re-registered with
# the current bundle ID (app.hyka.com)
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

echo "=========================================="
echo "Cleanup Old Device Tokens"
echo "=========================================="
echo ""
echo "This will delete all device tokens from the database."
echo "Users will automatically re-register new tokens when they open the app."
echo ""

read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Checking current device tokens..."
echo ""

# Get count of current tokens
CURRENT_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/user_devices?select=id" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" | jq '. | length')

echo "Found $CURRENT_COUNT device token(s)"
echo ""

if [ "$CURRENT_COUNT" -eq 0 ]; then
    echo "No device tokens to delete."
    exit 0
fi

echo "Deleting all device tokens..."
echo ""

# Delete all device tokens
# Note: This uses the REST API. For production, you might want to use
# the service role key or run SQL directly in Supabase Dashboard
RESPONSE=$(curl -s -X DELETE "${SUPABASE_URL}/rest/v1/user_devices?id=gt.0" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation")

echo "$RESPONSE" | jq '.'

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. ✅ Old device tokens deleted"
echo ""
echo "2. 📱 Users need to open the app:"
echo "   - The app will automatically register new device tokens"
echo "   - New tokens will be registered with bundle ID: app.hyka.com"
echo ""
echo "3. ✅ Verify new tokens:"
echo "   - Go to Supabase Dashboard → Table Editor → user_devices"
echo "   - Check that new tokens appear with recent timestamps"
echo ""
echo "4. 🧪 Test notifications:"
echo "   - Run: ./diagnose_notification.sh"
echo "   - Or use Supabase Dashboard → Edge Functions → garmin-activity-notify"
echo ""
echo "Note: If REST API deletion doesn't work, use Supabase SQL Editor:"
echo "   DELETE FROM user_devices;"
echo ""
