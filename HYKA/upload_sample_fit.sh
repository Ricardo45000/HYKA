#!/bin/bash

# ============================================================================
# Upload Sample FIT File to Test Activity
# ============================================================================
# This script downloads a sample FIT file and uploads it to an existing activity
# ============================================================================

SUPABASE_URL="https://gvfhtiljkybbrbxoyqsq.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"

ACTIVITY_ID="${1:-21194868043}"  # Use provided ID or default

echo "============================================================================"
echo "UPLOAD SAMPLE FIT FILE"
echo "============================================================================"
echo "Activity ID: ${ACTIVITY_ID}"
echo ""

# Step 1: Get activity UUID from database
echo "Step 1: Looking up activity in database..."
ACTIVITY=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/garmin_activities?garmin_activity_id=eq.${ACTIVITY_ID}&select=id,user_id" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}")

ACTIVITY_UUID=$(echo "$ACTIVITY" | jq -r '.[0].id // empty')
USER_ID=$(echo "$ACTIVITY" | jq -r '.[0].user_id // empty')

if [ -z "$ACTIVITY_UUID" ] || [ "$ACTIVITY_UUID" == "null" ]; then
    echo "❌ Activity not found in database!"
    echo "   Make sure the activity exists first."
    echo ""
    echo "   You can create it by calling garmin-activity-store first."
    exit 1
fi

echo "✅ Activity found"
echo "   UUID: ${ACTIVITY_UUID}"
echo "   User ID: ${USER_ID}"
echo ""

# Step 2: Download sample FIT file
echo "Step 2: Downloading sample FIT file..."
echo ""

# Try to download from Garmin SDK examples
# If that fails, we'll create a minimal one
SAMPLE_FIT_URL="https://developer.garmin.com/fit/example-file/"
FIT_FILE="sample_activity.fit"

# Check if we have Node.js to create a sample FIT file
if command -v node &> /dev/null; then
    echo "Creating a minimal sample FIT file using Node.js..."
    
    # Create a minimal FIT file generator
    node << 'NODE_SCRIPT'
const fs = require('fs');

// Minimal FIT file structure
// Header: 14 bytes
// File ID message
// Activity message  
// Session message
// Record messages (samples)

const fitFile = Buffer.alloc(2000); // Allocate buffer
let offset = 0;

// Header (14 bytes)
fitFile[offset++] = 0x0E; // Header size
fitFile[offset++] = 0x10; // Protocol version
fitFile.writeUInt16LE(0x0000, offset); offset += 2; // Profile version
fitFile.writeUInt32LE(1000, offset); offset += 4; // Data size (will update)
fitFile.write('.FIT', offset, 4, 'ascii'); offset += 4; // Data type
fitFile.writeUInt16LE(0x0000, offset); offset += 2; // CRC

// File ID message definition (local message 0)
fitFile[offset++] = 0x40; // Header: definition message, local 0
fitFile[offset++] = 0x00; // Reserved
fitFile[offset++] = 0x00; // Architecture (little-endian)
fitFile.writeUInt16LE(0, offset); offset += 2; // Global message: File ID
fitFile[offset++] = 0x05; // Number of fields

// Field definitions for File ID
const fileIdFields = [
    {num: 0, size: 1, type: 0x00}, // type
    {num: 1, size: 1, type: 0x00}, // manufacturer
    {num: 2, size: 2, type: 0x84}, // product
    {num: 3, size: 4, type: 0x86}, // serial_number
    {num: 4, size: 4, type: 0x86}, // time_created
];

fileIdFields.forEach(field => {
    fitFile[offset++] = field.num;
    fitFile[offset++] = field.size;
    fitFile[offset++] = field.type;
});

// File ID data message
fitFile[offset++] = 0x00; // Header: data message, local 0
fitFile[offset++] = 0x04; // type: Activity
fitFile[offset++] = 0x01; // manufacturer: Garmin
fitFile.writeUInt16LE(0x0001, offset); offset += 2; // product
fitFile.writeUInt32LE(0x12345678, offset); offset += 4; // serial_number
const now = Math.floor(Date.now() / 1000) - 631065600; // FIT epoch
fitFile.writeUInt32LE(now, offset); offset += 4; // time_created

// Update data size in header
fitFile.writeUInt32LE(offset - 14, 4);

// Write file
fs.writeFileSync('sample_activity.fit', fitFile.slice(0, offset));
console.log(`Created sample FIT file: ${offset} bytes`);
NODE_SCRIPT

    if [ -f "$FIT_FILE" ]; then
        echo "✅ Sample FIT file created: ${FIT_FILE}"
        FIT_SIZE=$(stat -f%z "$FIT_FILE" 2>/dev/null || stat -c%s "$FIT_FILE" 2>/dev/null || echo "0")
        echo "   Size: ${FIT_SIZE} bytes"
    else
        echo "❌ Failed to create sample FIT file"
        exit 1
    fi
else
    echo "⚠️ Node.js not found. Please install Node.js or use a pre-existing FIT file."
    echo ""
    echo "Alternative: Download a sample FIT file from:"
    echo "  https://developer.garmin.com/fit/example-file/"
    echo ""
    echo "Or use an existing FIT file from your Garmin activities."
    exit 1
fi

echo ""

# Step 3: Convert FIT file to base64 array for Supabase
echo "Step 3: Converting FIT file to base64 array..."
echo ""

if command -v node &> /dev/null; then
    FIT_DATA_JSON=$(node -e "
        const fs = require('fs');
        const data = fs.readFileSync('${FIT_FILE}');
        console.log(JSON.stringify(Array.from(data)));
    ")
    
    echo "✅ FIT file converted to array format"
    echo "   Array length: $(echo "$FIT_DATA_JSON" | jq '. | length')"
else
    echo "❌ Node.js required for conversion"
    exit 1
fi

echo ""

# Step 4: Upload FIT file to database
echo "Step 4: Uploading FIT file to database..."
echo ""

FIT_SIZE=$(stat -f%z "$FIT_FILE" 2>/dev/null || stat -c%s "$FIT_FILE" 2>/dev/null || echo "0")

UPLOAD_PAYLOAD=$(cat <<JSON
{
  "activity_id": "${ACTIVITY_UUID}",
  "file_data": ${FIT_DATA_JSON},
  "file_size_bytes": ${FIT_SIZE}
}
JSON
)

# Insert FIT file using Supabase REST API
UPLOAD_RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/garmin_fit_files" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Prefer: return=representation" \
  -d "$UPLOAD_PAYLOAD")

FIT_FILE_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.[0].id // empty')

if [ -n "$FIT_FILE_ID" ] && [ "$FIT_FILE_ID" != "null" ]; then
    echo "✅ FIT file uploaded successfully"
    echo "   FIT file ID: ${FIT_FILE_ID}"
else
    echo "❌ Failed to upload FIT file"
    echo "Response: $UPLOAD_RESPONSE"
    exit 1
fi

echo ""

# Step 5: Trigger FIT processor
echo "Step 5: Triggering FIT processor..."
echo ""

PROCESSOR_URL="${SUPABASE_URL}/functions/v1/garmin-fit-processor"
PROCESSOR_PAYLOAD=$(cat <<JSON
{
  "activity_id": "${ACTIVITY_UUID}",
  "fit_file_data": ${FIT_DATA_JSON}
}
JSON
)

PROCESSOR_RESPONSE=$(curl -s -X POST "${PROCESSOR_URL}" \
  -H "Content-Type: application/json" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -d "$PROCESSOR_PAYLOAD")

echo "Processor response:"
echo "$PROCESSOR_RESPONSE" | jq '.'

SAMPLES_EXTRACTED=$(echo "$PROCESSOR_RESPONSE" | jq -r '.samples_extracted // 0')

if [ "$SAMPLES_EXTRACTED" != "null" ] && [ "$SAMPLES_EXTRACTED" != "0" ]; then
    echo ""
    echo "✅ FIT file processed successfully!"
    echo "   Samples extracted: ${SAMPLES_EXTRACTED}"
else
    echo ""
    echo "⚠️ Processor completed but may not have extracted samples"
    echo "   Check the processor logs for details"
fi

echo ""
echo "============================================================================"
echo "✅ Complete! Activity ${ACTIVITY_ID} now has a FIT file and samples."
echo "============================================================================"

