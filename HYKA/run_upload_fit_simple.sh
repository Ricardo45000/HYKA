#!/bin/bash

# Simplified version - step by step execution

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"
ACTIVITY_ID="21194868043"

echo "Step 1: Looking up activity..."
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,user_id" -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}")

echo "$ACTIVITY" | jq '.'

ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')

if [ -z "$ACTIVITY_UUID" ] || [ "$ACTIVITY_UUID" == "null" ]; then
    echo "Activity not found. Creating it first..."
    curl -X POST "${SUPABASE_URL}/functions/v1/garmin-activity-store" \
      -H "Content-Type: application/json" \
      -H "apikey: ${ANON_KEY}" \
      -H "Authorization: Bearer ${ANON_KEY}" \
      -d "{\"garminUserId\":\"ae3cd04a-b8d6-4803-b7ed-7213c975c258\",\"summary\":{\"summaryId\":\"${ACTIVITY_ID}\",\"activityId\":\"${ACTIVITY_ID}\"}}"
    sleep 2
    ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id" -H "apikey: ${ANON_KEY}" -H "Authorization: Bearer ${ANON_KEY}")
    ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
fi

echo "Activity UUID: $ACTIVITY_UUID"

if [ -z "$ACTIVITY_UUID" ] || [ "$ACTIVITY_UUID" == "null" ]; then
    echo "Failed to get activity UUID"
    exit 1
fi

echo ""
echo "Step 2: Creating sample FIT file..."
node -e "
const fs = require('fs');
const fitFile = Buffer.alloc(2000);
let offset = 0;
fitFile[offset++] = 0x0E;
fitFile[offset++] = 0x10;
fitFile.writeUInt16LE(0x0000, offset); offset += 2;
fitFile.writeUInt32LE(1000, offset); offset += 4;
fitFile.write('.FIT', offset, 4, 'ascii'); offset += 4;
fitFile.writeUInt16LE(0x0000, offset); offset += 2;
fitFile[offset++] = 0x40;
fitFile[offset++] = 0x00;
fitFile[offset++] = 0x00;
fitFile.writeUInt16LE(0, offset); offset += 2;
fitFile[offset++] = 0x05;
const fields = [[0,1,0],[1,1,0],[2,2,0x84],[3,4,0x86],[4,4,0x86]];
fields.forEach(f => { fitFile[offset++] = f[0]; fitFile[offset++] = f[1]; fitFile[offset++] = f[2]; });
fitFile[offset++] = 0x00;
fitFile[offset++] = 0x04;
fitFile[offset++] = 0x01;
fitFile.writeUInt16LE(0x0001, offset); offset += 2;
fitFile.writeUInt32LE(0x12345678, offset); offset += 4;
const now = Math.floor(Date.now() / 1000) - 631065600;
fitFile.writeUInt32LE(now, offset); offset += 4;
fitFile.writeUInt32LE(offset - 14, 4);
fs.writeFileSync('sample_activity.fit', fitFile.slice(0, offset));
console.log('Created: ' + offset + ' bytes');
"

echo ""
echo "Step 3: Converting to array..."
FIT_DATA=$(node -e "const fs = require('fs'); const data = fs.readFileSync('sample_activity.fit'); console.log(JSON.stringify(Array.from(data)));")
FIT_SIZE=$(stat -f%z sample_activity.fit 2>/dev/null || stat -c%s sample_activity.fit 2>/dev/null || echo "100")

echo "Step 4: Uploading FIT file..."
curl -X POST "${SUPABASE_URL}/rest/v1/garmin_fit_files" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Prefer: return=representation" \
  -d "{\"activity_id\":\"${ACTIVITY_UUID}\",\"file_data\":${FIT_DATA},\"file_size_bytes\":${FIT_SIZE}}" | jq '.'

echo ""
echo "Step 5: Triggering processor..."
curl -X POST "${SUPABASE_URL}/functions/v1/garmin-fit-processor" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "{\"activity_id\":\"${ACTIVITY_UUID}\",\"fit_file_data\":${FIT_DATA}}" | jq '.'

echo ""
echo "Done!"

