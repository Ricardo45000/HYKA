#!/bin/bash

# Strava Connection Diagnostic Script
# Usage: ./diagnose_strava_connection.sh USER_ID

USER_ID="${1:-b7e9e717-1cad-4dc2-83de-4e563ce0c672}"
SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.jP0v7Xp6q_YPY2mdC0kiFfQM6xHWGZ2ty9fk7zmOcXs"
SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"

echo "============================================================================"
echo "STRAVA CONNECTION DIAGNOSTIC"
echo "============================================================================"
echo "User ID: $USER_ID"
echo ""

# 1. Check if connection exists
echo "1️⃣ Checking Strava connection..."
CONNECTION_CHECK=$(curl -s -X GET \
  "${SUPABASE_URL}/rest/v1/strava_connections?user_id=eq.${USER_ID}&select=*" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}")

if echo "$CONNECTION_CHECK" | grep -q "strava_athlete_id"; then
  echo "✅ Connection found!"
  echo "$CONNECTION_CHECK" | python3 -m json.tool 2>/dev/null || echo "$CONNECTION_CHECK"
else
  echo "❌ No Strava connection found for this user"
  echo "Response: $CONNECTION_CHECK"
  echo ""
  echo "⚠️  The user needs to reconnect to Strava in the app"
  exit 1
fi

echo ""
echo ""

# 2. Check if activities exist
echo "2️⃣ Checking Strava activities in database..."
ACTIVITIES_CHECK=$(curl -s -X GET \
  "${SUPABASE_URL}/rest/v1/strava_activities?user_id=eq.${USER_ID}&select=id,strava_activity_id,activity_name,start_date&limit=5" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}")

ACTIVITY_COUNT=$(echo "$ACTIVITIES_CHECK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data) if isinstance(data, list) else 0)" 2>/dev/null || echo "0")

if [ "$ACTIVITY_COUNT" -gt 0 ]; then
  echo "✅ Found $ACTIVITY_COUNT activities (showing first 5):"
  echo "$ACTIVITIES_CHECK" | python3 -m json.tool 2>/dev/null || echo "$ACTIVITIES_CHECK"
else
  echo "❌ No activities found in database"
  echo "Response: $ACTIVITIES_CHECK"
  echo ""
  echo "⚠️  Activities need to be synced"
fi

echo ""
echo ""

# 3. Check unified_activities view
echo "3️⃣ Checking unified_activities view..."
UNIFIED_CHECK=$(curl -s -X GET \
  "${SUPABASE_URL}/rest/v1/unified_activities?user_id=eq.${USER_ID}&provider=eq.strava&select=id,name,provider,start_time&limit=5" \
  -H "apikey: ${SERVICE_ROLE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}")

UNIFIED_COUNT=$(echo "$UNIFIED_CHECK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data) if isinstance(data, list) else 0)" 2>/dev/null || echo "0")

if [ "$UNIFIED_COUNT" -gt 0 ]; then
  echo "✅ Found $UNIFIED_COUNT Strava activities in unified_activities view:"
  echo "$UNIFIED_CHECK" | python3 -m json.tool 2>/dev/null || echo "$UNIFIED_CHECK"
else
  echo "⚠️  No Strava activities in unified_activities view"
  echo "   This might mean:"
  echo "   1. The view doesn't include strava_activities"
  echo "   2. Activities haven't been synced yet"
  echo "Response: $UNIFIED_CHECK"
fi

echo ""
echo ""

# 4. Offer to trigger sync
echo "4️⃣ Trigger historical sync?"
read -p "Do you want to trigger the historical sync now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "🔄 Triggering Strava historical sync..."
  SYNC_RESPONSE=$(curl -s -X POST \
    "${SUPABASE_URL}/functions/v1/strava-historical-sync" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"user_id\": \"${USER_ID}\"}")
  
  echo "Response:"
  echo "$SYNC_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$SYNC_RESPONSE"
  
  echo ""
  echo "✅ Sync triggered! Check Supabase logs for details."
  echo "   Wait 10-30 seconds, then run this script again to verify activities were stored."
else
  echo "⏭️  Skipping sync"
fi

echo ""
echo "============================================================================"
echo "DIAGNOSTIC COMPLETE"
echo "============================================================================"

