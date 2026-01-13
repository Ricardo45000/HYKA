#!/bin/bash

# Manual Garmin Health Sync
# Syncs health data for a specific user

USER_ID="${1:-fc600af9-2926-4b86-b841-25a25d17c10c}"
DAYS_BACK="${2:-1}"

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-YOUR_ANON_KEY_HERE}"
SYNC_URL="${SUPABASE_URL}/functions/v1/garmin-health-sync"

echo "🔄 Manually Syncing Garmin Health Data"
echo ""
echo "User ID: $USER_ID"
echo "Days Back: $DAYS_BACK"
echo ""

if [ "$SUPABASE_ANON_KEY" = "YOUR_ANON_KEY_HERE" ]; then
    echo "⚠️  SUPABASE_ANON_KEY not set"
    echo ""
    echo "Option 1: Set environment variable:"
    echo "   export SUPABASE_ANON_KEY='your_anon_key'"
    echo "   ./sync_garmin_health_now.sh"
    echo ""
    echo "Option 2: Use Supabase Dashboard:"
    echo "   1. Go to: Supabase Dashboard → Edge Functions → garmin-health-sync"
    echo "   2. Click 'Invoke Function'"
    echo "   3. Send JSON body:"
    echo "      {"
    echo "        \"user_id\": \"$USER_ID\","
    echo "        \"days_back\": $DAYS_BACK"
    echo "      }"
    exit 1
fi

echo "📡 Calling garmin-health-sync Edge Function..."
echo ""

RESPONSE=$(curl -s -X POST "$SYNC_URL" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"user_id\": \"$USER_ID\",
    \"days_back\": $DAYS_BACK
  }")

echo "Response:"
echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
echo ""

echo "✅ Sync requested"
echo ""
echo "Next steps:"
echo "1. Check Supabase Edge Function logs:"
echo "   - Go to: Supabase Dashboard → Edge Functions → garmin-health-sync → Logs"
echo "   - Look for: '🏥 Garmin Health Sync started'"
echo ""
echo "2. Check database:"
echo "   - Query: SELECT * FROM garmin_health_metrics WHERE user_id = '$USER_ID' ORDER BY metric_date DESC LIMIT 10;"
echo ""
