#!/bin/bash

# ============================================================================
# Comprehensive Garmin Activity Flow Test
# ============================================================================
# Tests: Push → Store → FIT Download → Samples → Notification
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

ACTIVITY_ID="21193470552"
GARMIN_USER_ID="ae3cd04a-b8d6-4803-b7ed-7213c975c258"
USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"

echo "============================================================================"
echo "GARMIN ACTIVITY FLOW TEST"
echo "============================================================================"
echo "Activity ID: ${ACTIVITY_ID}"
echo "Garmin User ID: ${GARMIN_USER_ID}"
echo "HYKA User ID: ${USER_ID}"
echo ""

# Step 1: Check Garmin Connection
echo "STEP 1: Checking Garmin Connection..."
echo "----------------------------------------"
CONNECTION=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_connections?garmin_user_id=eq.${GARMIN_USER_ID}&select=user_id,garmin_user_id,access_token,created_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

CONNECTION_COUNT=$(echo "$CONNECTION" | jq '. | length' 2>/dev/null || echo "0")

if [ "$CONNECTION_COUNT" -eq 0 ]; then
    echo "⚠️ Connection not visible via REST API (likely RLS policy)"
    echo ""
    echo "Note: Edge Functions use service role key and can see the connection"
    echo "even if REST API queries are blocked by RLS."
    echo ""
    echo "Proceeding with test - Edge Functions should be able to access it..."
    echo ""
else
    echo "✅ Connection found:"
    echo "$CONNECTION" | jq '.[0] | {user_id, garmin_user_id, has_token: (.access_token != null)}'
    echo ""
fi

# Step 2: Send Push
echo "STEP 2: Sending Activity Push..."
echo "----------------------------------------"
PUSH_URL="${SUPABASE_URL}/functions/v1/garmin-activity-push"
CALLBACK_URL="https://connectapi.garmin.com/activity-service/activity/${ACTIVITY_ID}/file/fit"

PUSH_PAYLOAD=$(cat <<JSON
{
  "activityFiles": [
    {
      "userId": "${GARMIN_USER_ID}",
      "summaryId": "${ACTIVITY_ID}",
      "activityId": "${ACTIVITY_ID}",
      "activityType": "running",
      "callbackUrl": "${CALLBACK_URL}",
      "fileType": "fit",
      "startTimeInSeconds": 1765108616
    }
  ]
}
JSON
)

PUSH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${PUSH_URL}" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin-Connect" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "$PUSH_PAYLOAD")

PUSH_HTTP_STATUS=$(echo "$PUSH_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PUSH_BODY=$(echo "$PUSH_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: ${PUSH_HTTP_STATUS}"
echo "$PUSH_BODY" | jq '.' 2>/dev/null || echo "$PUSH_BODY"
echo ""

if [ "$PUSH_HTTP_STATUS" != "200" ]; then
    echo "❌ Push failed"
    exit 1
fi

# Step 3: Wait for Processing
echo "STEP 3: Waiting for processing (30 seconds)..."
echo "----------------------------------------"
echo "This allows time for:"
echo "- Activity data fetching from Garmin API"
echo "- FIT file download"
echo "- FIT file storage"
echo "- FIT processor to extract samples"
echo ""
sleep 30

# Step 4: Check Activity
echo "STEP 4: Checking Stored Activity..."
echo "----------------------------------------"
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=*" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

ACTIVITY_COUNT=$(echo "$ACTIVITY" | jq '. | length' 2>/dev/null || echo "0")

if [ "$ACTIVITY_COUNT" -eq 0 ]; then
    echo "❌ Activity not found in database"
    echo ""
    echo "Possible issues:"
    echo "1. Store function failed (check Supabase logs)"
    echo "2. Connection lookup failed"
    echo "3. Activity data fetch failed"
    echo ""
    exit 1
else
    echo "✅ Activity found:"
    ACTIVITY_DATA=$(echo "$ACTIVITY" | jq '.[0]')
    echo "$ACTIVITY_DATA" | jq '{id, garmin_activity_id, activity_name, activity_type, distance_meters, duration_seconds, average_heart_rate, has_fit_file, created_at}'
    
    ACTIVITY_UUID=$(echo "$ACTIVITY_DATA" | jq -r '.id')
    DISTANCE=$(echo "$ACTIVITY_DATA" | jq -r '.distance_meters // 0')
    DURATION=$(echo "$ACTIVITY_DATA" | jq -r '.duration_seconds // 0')
    HAS_FIT=$(echo "$ACTIVITY_DATA" | jq -r '.has_fit_file // false')
    
    echo ""
    if [ "$DISTANCE" = "0" ] || [ "$DISTANCE" = "null" ]; then
        echo "⚠️ Distance is 0 - activity data may not have been fetched"
    fi
    
    if [ "$DURATION" = "0" ] || [ "$DURATION" = "null" ]; then
        echo "⚠️ Duration is 0 - activity data may not have been fetched"
    fi
    
    if [ "$HAS_FIT" = "false" ]; then
        echo "⚠️ FIT file not marked as processed yet"
    fi
    echo ""
fi

# Step 5: Check FIT File
echo "STEP 5: Checking FIT File..."
echo "----------------------------------------"
FIT_FILE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=id,file_size_bytes,created_at" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

FIT_COUNT=$(echo "$FIT_FILE" | jq '. | length' 2>/dev/null || echo "0")

if [ "$FIT_COUNT" -eq 0 ]; then
    echo "❌ FIT file not found"
    echo ""
    echo "Possible issues:"
    echo "1. FIT file download failed (check store function logs)"
    echo "2. Access token expired/invalid"
    echo "3. Garmin API endpoint issue"
    echo ""
else
    echo "✅ FIT file found:"
    echo "$FIT_FILE" | jq '.[0]'
    FIT_SIZE=$(echo "$FIT_FILE" | jq -r '.[0].file_size_bytes // 0')
    echo ""
    if [ "$FIT_SIZE" -gt 0 ]; then
        echo "   File size: ${FIT_SIZE} bytes"
    else
        echo "   ⚠️ File size is 0"
    fi
    echo ""
fi

# Step 6: Check Samples
echo "STEP 6: Checking Activity Samples..."
echo "----------------------------------------"
SAMPLES=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id,timestamp_seconds,sample_time,latitude,longitude,heart_rate,speed_mps&limit=5&order=timestamp_seconds.asc" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

SAMPLE_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" | jq '. | length' 2>/dev/null || echo "0")

if [ "$SAMPLE_COUNT" -eq 0 ]; then
    echo "❌ No samples found"
    echo ""
    echo "Possible issues:"
    echo "1. FIT processor not triggered"
    echo "2. FIT file parsing failed"
    echo "3. Samples not extracted correctly"
    echo ""
else
    echo "✅ Samples found: ${SAMPLE_COUNT} total"
    echo ""
    echo "First 5 samples:"
    echo "$SAMPLES" | jq '.'
    echo ""
fi

# Step 7: Summary
echo "============================================================================"
echo "TEST SUMMARY"
echo "============================================================================"
echo "✅ Connection: $([ "$CONNECTION_COUNT" -gt 0 ] && echo "Found" || echo "Missing")"
echo "✅ Push: $([ "$PUSH_HTTP_STATUS" = "200" ] && echo "Success" || echo "Failed")"
echo "✅ Activity: $([ "$ACTIVITY_COUNT" -gt 0 ] && echo "Stored" || echo "Missing")"
echo "✅ FIT File: $([ "$FIT_COUNT" -gt 0 ] && echo "Stored" || echo "Missing")"
echo "✅ Samples: $([ "$SAMPLE_COUNT" -gt 0 ] && echo "Extracted ($SAMPLE_COUNT)" || echo "Missing")"
echo ""

if [ "$DISTANCE" != "0" ] && [ "$DISTANCE" != "null" ] && [ "$DURATION" != "0" ] && [ "$DURATION" != "null" ]; then
    DISTANCE_KM=$(echo "scale=1; $DISTANCE / 1000" | bc)
    DURATION_MIN=$(echo "scale=0; $DURATION / 60" | bc)
    PACE_DECIMAL=$(echo "scale=2; $DURATION / 60 / ($DISTANCE / 1000)" | bc)
    PACE_MIN=$(echo "$PACE_DECIMAL" | cut -d. -f1)
    PACE_SEC=$(echo "scale=0; ($PACE_DECIMAL - $PACE_MIN) * 60" | bc | cut -d. -f1)
    PACE_SEC=$(printf "%02d" $PACE_SEC)
    
    echo "📊 Activity Metrics:"
    echo "   Distance: ${DISTANCE_KM} km"
    echo "   Duration: ${DURATION_MIN} minutes"
    echo "   Pace: ${PACE_MIN}:${PACE_SEC} m/km"
    echo ""
    echo "✅ Notification should show:"
    echo "   Title: \"Distance: ${DISTANCE_KM} km - Pace: ${PACE_MIN}:${PACE_SEC} m/km\""
    echo "   Body: \"Check your HYKA digital twin for your upcoming event\""
else
    echo "⚠️ Activity data incomplete - notification may show 0.0 km"
fi
echo ""
echo "============================================================================"
echo "Check Supabase Edge Function logs for detailed processing information:"
echo "https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/logs/edge-functions"
echo "============================================================================"

