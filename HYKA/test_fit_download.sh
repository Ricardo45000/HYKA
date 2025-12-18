#!/bin/bash

# ============================================================================
# Test FIT File Download for Existing Activity
# ============================================================================
# This script manually triggers FIT file download for an existing Garmin activity
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

GARMIN_USER_ID="ae3cd04a-b8d6-4803-b7ed-7213c975c258"
ACTIVITY_ID="${1:-21194868043}"  # Use provided ID or default

echo "============================================================================"
echo "TEST FIT FILE DOWNLOAD"
echo "============================================================================"
echo "Activity ID: ${ACTIVITY_ID}"
echo ""

# Step 1: Trigger store function to download FIT file
echo "Step 1: Triggering garmin-activity-store to download FIT file..."
echo ""

STORE_URL="${SUPABASE_URL}/functions/v1/garmin-activity-store"
PAYLOAD=$(cat <<JSON
{
  "garminUserId": "${GARMIN_USER_ID}",
  "summary": {
    "summaryId": "${ACTIVITY_ID}",
    "activityId": "${ACTIVITY_ID}",
    "activityName": "Test Activity",
    "activityType": "running"
  }
}
JSON
)

echo "Payload:"
echo "$PAYLOAD" | jq '.'
echo ""

RESPONSE=$(curl -s -X POST "${STORE_URL}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "$PAYLOAD")

echo "Response:"
echo "$RESPONSE" | jq '.'
echo ""

# Step 2: Wait a moment
echo "Waiting 3 seconds..."
sleep 3
echo ""

# Step 3: Check if FIT file was downloaded
echo "Step 2: Checking if FIT file was downloaded..."
echo ""

# Get activity UUID
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,has_fit_file" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
HAS_FIT_FILE=$(echo "$ACTIVITY" | jq -r '.[0].has_fit_file // false')

if [ -n "$ACTIVITY_UUID" ] && [ "$ACTIVITY_UUID" != "null" ]; then
    echo "✅ Activity found in database"
    echo "   UUID: ${ACTIVITY_UUID}"
    echo "   Has FIT file: ${HAS_FIT_FILE}"
    echo ""
    
    # Check FIT file
    FIT_FILE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=id,file_size_bytes,created_at" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}")
    
    FIT_COUNT=$(echo "$FIT_FILE" | jq '. | length' 2>/dev/null || echo "0")
    
    if [ "$FIT_COUNT" -gt 0 ]; then
        FIT_SIZE=$(echo "$FIT_FILE" | jq -r '.[0].file_size_bytes // 0')
        echo "✅ FIT file found!"
        echo "   Size: ${FIT_SIZE} bytes"
        echo ""
        
        # Check samples
        SAMPLE_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id" \
          -H "apikey: ${ANON_KEY}" \
          -H "Authorization: Bearer ${ANON_KEY}" | jq '. | length' 2>/dev/null || echo "0")
        
        echo "📊 Activity Samples: ${SAMPLE_COUNT}"
        
        if [ "$SAMPLE_COUNT" -eq 0 ]; then
            echo ""
            echo "⚠️ FIT file exists but no samples extracted yet."
            echo "   The FIT processor should run automatically."
            echo "   If samples don't appear, check the garmin-fit-processor logs."
        else
            echo "✅ Samples extracted successfully!"
        fi
    else
        echo "❌ No FIT file found in database"
        echo ""
        echo "Possible reasons:"
        echo "  1. FIT file not available yet (404 from Garmin)"
        echo "  2. OAuth token doesn't have permission"
        echo "  3. Activity doesn't have a FIT file (manual entry)"
        echo ""
        echo "Check the Edge Function logs for details."
    fi
else
    echo "❌ Activity not found in database"
    echo "   Make sure the activity ID is correct and the webhook was received."
fi

echo ""
echo "============================================================================"

