# How to Simulate an Activity with FIT File

## Option 1: Use Existing Activity (Recommended)

If you have an existing Garmin activity (like `21194868043`), you can manually trigger the FIT file download:

```bash
# Make script executable
chmod +x test_fit_download.sh

# Run with activity ID
./test_fit_download.sh 21194868043
```

This will:
1. Call `garmin-activity-store` to download the FIT file
2. Check if the FIT file was stored
3. Check if samples were extracted

## Option 2: Download Sample FIT File

You can download a sample FIT file from the internet and manually upload it:

1. **Download a sample FIT file:**
   ```bash
   # Example: Download from a public repository
   curl -o sample_activity.fit "https://raw.githubusercontent.com/garmin/fit-sdk/main/Examples/cpp/Activity.fit"
   ```

2. **Convert to base64:**
   ```bash
   # Convert FIT file to base64 array (for Supabase)
   node -e "const fs = require('fs'); const data = fs.readFileSync('sample_activity.fit'); console.log(JSON.stringify(Array.from(data)))" > fit_data.json
   ```

3. **Create activity and upload FIT file:**
   - Create the activity in `garmin_activities` table
   - Insert the FIT file data into `garmin_fit_files` table
   - Trigger `garmin-fit-processor` with the activity ID and FIT data

## Option 3: Use Garmin's Test Data

Garmin provides test FIT files in their SDK:
- https://developer.garmin.com/fit/example-file/

You can download one of these and use it for testing.

## Option 4: Create Minimal FIT File Programmatically

For testing, you could create a minimal FIT file with:
- Header (14 bytes)
- File ID message
- Activity message
- Session message
- Record messages (samples)

However, this is complex. Better to use Option 1 or 2.

## Quick Test Script

I've created `test_fit_download.sh` which:
- Takes an activity ID as parameter
- Calls the store function to download FIT file
- Checks if FIT file was stored
- Checks if samples were extracted

Usage:
```bash
./test_fit_download.sh 21194868043
```

## Manual SQL Approach

If you want to manually insert a FIT file:

1. **Get FIT file as byte array:**
   ```bash
   # Read FIT file and convert to PostgreSQL bytea format
   xxd -p sample_activity.fit | tr -d '\n' | sed 's/\(..\)/\\x\1/g' > fit_hex.txt
   ```

2. **Insert into database:**
   ```sql
   -- First, get the activity UUID
   SELECT id FROM garmin_activities WHERE garmin_activity_id = '21194868043';
   
   -- Then insert FIT file (replace ACTIVITY_UUID and fit_hex_data)
   INSERT INTO garmin_fit_files (activity_id, file_data, file_size_bytes)
   VALUES (
     'ACTIVITY_UUID',
     decode('fit_hex_data', 'hex'),
     (SELECT length(decode('fit_hex_data', 'hex')))
   );
   
   -- Trigger processor
   -- Call garmin-fit-processor Edge Function with activity_id and file_data
   ```

## Recommended Approach

**For testing, use Option 1:**
1. Wait 5-10 minutes after creating activity in Garmin
2. Run `./test_fit_download.sh ACTIVITY_ID`
3. Check the results

This tests the full flow without needing to manually create FIT files.

