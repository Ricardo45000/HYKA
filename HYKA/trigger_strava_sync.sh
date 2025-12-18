#!/bin/bash

# Trigger Strava Historical Sync
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-historical-sync" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.jP0v7Xp6q_YPY2mdC0kiFfQM6xHWGZ2ty9fk7zmOcXs" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "b7e9e717-1cad-4dc2-83de-4e563ce0c672"}'

echo ""
echo "✅ Strava historical sync triggered. Check Supabase logs for results."

