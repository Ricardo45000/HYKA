# Garmin Manual FIT File Upload

## How It Works

When you upload a FIT file directly to Garmin Connect:
1. ✅ Garmin processes the file
2. ✅ Creates an activity in your Garmin account
3. ✅ Triggers the same webhook as recorded activities
4. ✅ Webhook sends both `summary` and `file` payloads
5. ✅ Activity should be stored in your database

## What to Expect

### Webhook Flow:
1. **Summary Payload** (first) - Contains activity data
2. **File Payload** (second) - Contains FIT file download URL

### Activity Data:
- Manual uploads are marked with `isWebUpload: true` in the summary
- All the same data fields are available (distance, duration, HR, etc.)
- FIT file should be available for download

## Checking if It Worked

### 1. Check Supabase Logs
Go to: **Supabase Dashboard → Edge Functions → `garmin-activity-store` → Logs**

Look for:
- `📥 Request body keys: [ "garminUserId", "userId", "summary", "file", "details" ]`
- `✅ Activity stored`
- `✅ Downloaded FIT file`

### 2. Check Database
```sql
SELECT 
  garmin_activity_id,
  activity_name,
  activity_type,
  distance_meters,
  duration_seconds,
  has_fit_file,
  created_at
FROM garmin_activities 
WHERE user_id = 'your-user-id'
ORDER BY created_at DESC 
LIMIT 5;
```

### 3. Check FIT File
```sql
SELECT 
  gff.activity_id,
  gff.file_size_bytes,
  gff.created_at,
  ga.activity_name
FROM garmin_fit_files gff
JOIN garmin_activities ga ON ga.id = gff.activity_id
WHERE ga.user_id = 'your-user-id'
ORDER BY gff.created_at DESC 
LIMIT 5;
```

## Troubleshooting

### Activity Not Appearing?

1. **Check webhook is configured:**
   - Go to Garmin Developer Portal
   - Verify webhook URL is set correctly
   - Check webhook is active

2. **Check logs for errors:**
   - Look for 401/403 errors (token issues)
   - Look for database errors
   - Look for missing data warnings

3. **Verify connection exists:**
   ```sql
   SELECT * FROM garmin_connections 
   WHERE user_id = 'your-user-id';
   ```

### FIT File Not Downloaded?

1. **Check callbackURL in logs:**
   - Should see `callbackURL` in file payload
   - Should see "Using direct download URL"

2. **Check for 400/401 errors:**
   - May need to wait 1-5 minutes for FIT file to be ready
   - Garmin may send another webhook when FIT is ready

3. **Manual retry:**
   - Wait a few minutes after upload
   - Check if FIT file is available in Garmin Connect
   - If yes, manually trigger the store function with activity ID

## Manual Upload vs Recorded Activity

| Feature | Manual Upload | Recorded Activity |
|---------|--------------|-------------------|
| Webhook Triggered | ✅ Yes | ✅ Yes |
| Summary Payload | ✅ Yes | ✅ Yes |
| File Payload | ✅ Yes | ✅ Yes |
| FIT File Available | ✅ Yes | ✅ Yes |
| `isWebUpload` Flag | `true` | `false` |
| Processing Time | May take longer | Usually faster |

## Next Steps

After uploading:
1. **Wait 1-2 minutes** for Garmin to process
2. **Check Supabase logs** for webhook activity
3. **Verify activity in database** with all data fields
4. **Check FIT file** was downloaded and processed
5. **Verify activity samples** were extracted (if FIT processor ran)

If it doesn't work, check the logs and share what you see!


