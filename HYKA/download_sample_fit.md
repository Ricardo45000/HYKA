# Option 2: Download Sample FIT File and Upload

## Quick Start

```bash
# Make script executable
chmod +x upload_sample_fit.sh

# Run with activity ID
./upload_sample_fit.sh 21194868043
```

## What the Script Does

1. **Looks up the activity** in the database to get the UUID
2. **Creates a minimal sample FIT file** (if Node.js is available)
3. **Converts FIT file** to base64 array format for Supabase
4. **Uploads FIT file** to `garmin_fit_files` table
5. **Triggers FIT processor** to extract samples

## Requirements

- **Node.js** installed (for creating/processing FIT files)
- **jq** installed (for JSON parsing)
- **curl** installed (for API calls)
- Activity must already exist in `garmin_activities` table

## Alternative: Use Real FIT File

If you have a real FIT file from Garmin:

1. **Place it in the project directory** as `sample_activity.fit`
2. **Run the script** - it will use your file instead of creating one

## Manual Steps (If Script Fails)

### 1. Get Activity UUID

```bash
curl -X GET "https://gvfhtiljkybbrbxoyqsq.supabase.co/rest/v1/garmin_activities?garmin_activity_id=eq.21194868043&select=id" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### 2. Convert FIT File to Array

```javascript
// Using Node.js
const fs = require('fs');
const data = fs.readFileSync('sample_activity.fit');
console.log(JSON.stringify(Array.from(data)));
```

### 3. Upload to Database

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/rest/v1/garmin_fit_files" \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "activity_id": "ACTIVITY_UUID",
    "file_data": [ARRAY_FROM_STEP_2],
    "file_size_bytes": FILE_SIZE
  }'
```

### 4. Trigger Processor

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-fit-processor" \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -d '{
    "activity_id": "ACTIVITY_UUID",
    "fit_file_data": [ARRAY_FROM_STEP_2]
  }'
```

## Download Sample FIT Files

Garmin provides example FIT files:
- https://developer.garmin.com/fit/example-file/

You can download one of these and use it for testing.

## Notes

- The minimal FIT file created by the script is very basic
- For realistic testing, use a real FIT file from a Garmin activity
- Make sure the activity exists before running the script
- The script will fail if the activity doesn't exist in the database

