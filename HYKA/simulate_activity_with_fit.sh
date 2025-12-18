#!/bin/bash

# ============================================================================
# Simulate Activity with FIT File
# ============================================================================
# This script creates a test activity and optionally downloads/uses a FIT file
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"
SERVICE_KEY="YOUR_SERVICE_ROLE_KEY_HERE"  # You'll need to add this

USER_ID="fc600af9-2926-4b86-b841-25a25d17c10c"
GARMIN_ACTIVITY_ID="TEST_$(date +%s)"  # Unique test ID

echo "============================================================================"
echo "SIMULATE ACTIVITY WITH FIT FILE"
echo "============================================================================"
echo "User ID: ${USER_ID}"
echo "Test Activity ID: ${GARMIN_ACTIVITY_ID}"
echo ""

# Option 1: Use existing activity that has FIT file available
echo "OPTION 1: Use Existing Activity"
echo "--------------------------------"
echo "If you have an existing activity with a FIT file, we can:"
echo "1. Download the FIT file from Garmin"
echo "2. Store it in the database"
echo "3. Trigger the FIT processor"
echo ""

# Option 2: Create test activity and use sample FIT file
echo "OPTION 2: Create Test Activity with Sample FIT"
echo "-----------------------------------------------"
echo "We can create a minimal test activity and use a sample FIT file"
echo ""

read -p "Enter existing Garmin activity ID to test (or press Enter to create new test activity): " EXISTING_ACTIVITY_ID

if [ -n "$EXISTING_ACTIVITY_ID" ]; then
    echo ""
    echo "Using existing activity: ${EXISTING_ACTIVITY_ID}"
    echo ""
    echo "Step 1: Trigger FIT download for this activity..."
    
    # Call store function to download FIT file
    STORE_URL="${SUPABASE_URL}/functions/v1/garmin-activity-store"
    PAYLOAD=$(cat <<JSON
{
  "garminUserId": "ae3cd04a-b8d6-4803-b7ed-7213c975c258",
  "summary": {
    "summaryId": "${EXISTING_ACTIVITY_ID}",
    "activityId": "${EXISTING_ACTIVITY_ID}",
    "activityName": "Test Activity",
    "activityType": "running"
  }
}
JSON
)
    
    echo "Calling store function..."
    RESPONSE=$(curl -s -X POST "${STORE_URL}" \
      -H "Content-Type: application/json" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}" \
      -d "$PAYLOAD")
    
    echo "$RESPONSE" | jq '.'
    
    echo ""
    echo "Step 2: Check if FIT file was downloaded..."
    sleep 5
    
    # Get activity UUID
    ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${EXISTING_ACTIVITY_ID}&select=id" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}")
    
    ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
    
    if [ -n "$ACTIVITY_UUID" ] && [ "$ACTIVITY_UUID" != "null" ]; then
        echo "Activity UUID: ${ACTIVITY_UUID}"
        
        # Check FIT file
        FIT_FILE=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=id,file_size_bytes" \
          -H "apikey: ${ANON_KEY}" \
          -H "Authorization: Bearer ${ANON_KEY}")
        
        FIT_COUNT=$(echo "$FIT_FILE" | jq '. | length' 2>/dev/null || echo "0")
        echo "FIT files: ${FIT_COUNT}"
        
        if [ "$FIT_COUNT" -gt 0 ]; then
            echo "✅ FIT file found!"
            
            # Check samples
            SAMPLE_COUNT=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activity_samples?activity_id=eq.${ACTIVITY_UUID}&select=id" \
              -H "apikey: ${ANON_KEY}" \
              -H "Authorization: Bearer ${ANON_KEY}" | jq '. | length' 2>/dev/null || echo "0")
            echo "Samples: ${SAMPLE_COUNT}"
            
            if [ "$SAMPLE_COUNT" -eq 0 ]; then
                echo ""
                echo "FIT file exists but no samples. Triggering FIT processor..."
                
                # Get FIT file data
                FIT_DATA=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_fit_files?activity_id=eq.${ACTIVITY_UUID}&select=file_data" \
                  -H "apikey: ${ANON_KEY}" \
                  -H "Authorization: Bearer ${ANON_KEY}")
                
                # Trigger processor
                PROCESSOR_URL="${SUPABASE_URL}/functions/v1/garmin-fit-processor"
                PROCESSOR_PAYLOAD=$(cat <<JSON
{
  "activity_id": "${ACTIVITY_UUID}",
  "fit_file_data": $(echo "$FIT_DATA" | jq '.[0].file_data')
}
JSON
)
                
                echo "Triggering processor..."
                curl -s -X POST "${PROCESSOR_URL}" \
                  -H "Content-Type: application/json" \
                  -H "apikey: ${ANON_KEY}" \
                  -H "Authorization: Bearer ${ANON_KEY}" \
                  -d "$PROCESSOR_PAYLOAD" | jq '.'
            fi
        else
            echo "❌ No FIT file found. The 404 error means it's not available yet."
            echo "Wait a few minutes and try again, or check if Garmin sent another webhook."
        fi
    fi
else
    echo ""
    echo "To create a test activity, you would need to:"
    echo "1. Create activity in database"
    echo "2. Download a sample FIT file (from Garmin or use a test file)"
    echo "3. Store it"
    echo "4. Process it"
    echo ""
    echo "This is complex - better to use an existing activity."
fi

echo ""
echo "============================================================================"

