#!/bin/bash

# ============================================================================
# Create Test Garmin Connection
# ============================================================================
# This script creates a Garmin connection using a pull token
# Note: Pull tokens are temporary and may not work for webhooks
# For production, use OAuth 2.0 access token from the iOS app
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.YourServiceRoleKeyHere"

# Configuration
USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"
GARMIN_USER_ID="ae3cd04a-b8d6-4803-b7ed-7213c975c258"
PULL_TOKEN="CPT1765205332.zBOz2YkuCk'A"
TOKEN_EXPIRES_AT="2025-12-08T14:48:52.241166972Z"

echo "============================================================================"
echo "Creating Test Garmin Connection"
echo "============================================================================"
echo "HYKA User ID: ${USER_ID}"
echo "Garmin User ID: ${GARMIN_USER_ID}"
echo "Token expires: ${TOKEN_EXPIRES_AT}"
echo ""

# Create connection using Supabase REST API
CONNECTION_DATA=$(cat <<JSON
{
  "user_id": "${USER_ID}",
  "garmin_user_id": "${GARMIN_USER_ID}",
  "access_token": "${PULL_TOKEN}",
  "refresh_token": null,
  "token_expires_at": "${TOKEN_EXPIRES_AT}",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"
}
JSON
)

echo "Creating connection..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${SUPABASE_URL}/rest/v1/garmin_connections" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "$CONNECTION_DATA")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${HTTP_STATUS}"
echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
echo ""

# Verify connection was created
echo "Verifying connection..."
VERIFY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_connections?garmin_user_id=eq.${GARMIN_USER_ID}&select=*" \
  -H "apikey: ${SERVICE_KEY}" \
  -H "Authorization: Bearer ${SERVICE_KEY}")

echo "$VERIFY" | jq '.[0] | {user_id, garmin_user_id, has_token: (.access_token != null), token_expires_at, created_at}'

echo ""
echo "============================================================================"
if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Connection created successfully!"
    echo ""
    echo "⚠️  IMPORTANT NOTES:"
    echo "1. Pull tokens are TEMPORARY and expire on ${TOKEN_EXPIRES_AT}"
    echo "2. Pull tokens may NOT work for webhooks (they're for direct API calls)"
    echo "3. For production, connect Garmin via the iOS app to get a proper OAuth token"
    echo ""
    echo "You can now test the flow with:"
    echo "  ./test_garmin_full_flow.sh"
else
    echo "❌ Failed to create connection"
    echo "Check the error message above"
fi
echo "============================================================================"

