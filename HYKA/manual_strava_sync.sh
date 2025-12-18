#!/bin/bash

# Manual Strava Historical Sync
# Usage: ./manual_strava_sync.sh USER_ID

USER_ID="${1}"
SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.jP0v7Xp6q_YPY2mdC0kiFfQM6xHWGZ2ty9fk7zmOcXs"
SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"

if [ -z "$USER_ID" ]; then
  echo "Usage: ./manual_strava_sync.sh USER_ID"
  echo "Example: ./manual_strava_sync.sh b7e9e717-1cad-4dc2-83de-4e563ce0c672"
  exit 1
fi

echo "🔄 Triggering Strava historical sync for user: $USER_ID"
echo ""

SYNC_RESPONSE=$(curl -s -X POST \
  "${SUPABASE_URL}/functions/v1/strava-historical-sync" \
  -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"user_id\": \"${USER_ID}\"}")

echo "Response:"
echo "$SYNC_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$SYNC_RESPONSE"

echo ""
echo "✅ Sync triggered! Check Supabase Dashboard → Edge Functions → Logs for details."

