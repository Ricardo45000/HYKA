# Deploy and Test FIT File Fetching

## Step 1: Deploy Updated Function

The backfill function has been updated to:
- ✅ Automatically refresh expired tokens
- ✅ Reduced minimum range check (1 minute instead of 1 hour)

Deploy it:
```bash
supabase functions deploy garmin-activity-backfill
```

## Step 2: Test Backfill

After deployment, test with:
```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-backfill" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"userId": "fc600af9-2926-4b86-b841-25a25d17c10c"}'
```

**Expected response:**
- `202 Accepted` - Garmin accepted the backfill request
- OR `409 Conflict` - Date range already requested
- OR `400` - Garmin rejected (check error message)

## Step 3: How FIT Files Are Fetched

FIT files are **NOT** fetched directly by the backfill function. Here's the flow:

1. **Backfill Request** → Garmin accepts (202)
2. **Garmin Processes** → Finds activities in date range (15-60 minutes)
3. **Garmin Sends Webhooks** → Each activity gets a webhook with `callbackUrl`
4. **Webhook Triggers Pull** → `garmin-activity-ping` receives webhook
5. **Pull Function Fetches** → `garmin-activity-pull` uses `callbackUrl` to fetch:
   - Summary: `GET callbackUrl`
   - Details: `GET callbackUrl/details`
   - **FIT File: `GET callbackUrl/file`** ← This is what stores the FIT file
6. **Store Function Saves** → `garmin-activity-store` saves FIT file to `garmin_fit_files` table

## Step 4: Check for FIT Files

After webhooks arrive (15-60 minutes after backfill), check the database:

```sql
SELECT 
    id,
    user_id,
    garmin_activity_id,
    file_size_bytes,
    created_at
FROM garmin_fit_files
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
ORDER BY created_at DESC;
```

## Step 5: Monitor Webhooks

Check Supabase Edge Function logs for:
- `garmin-activity-ping` - Should receive webhooks
- `garmin-activity-pull` - Should fetch FIT files
- `garmin-activity-store` - Should store FIT files

Look for log messages like:
- `✅ FIT file fetched: { size: X, sizeMB: Y }`
- `💾 Storing FIT file...`

## Timeline

```
T+0s:    Trigger backfill → 202 Accepted
T+1m:    Garmin starts processing
T+15-60m: Garmin sends webhooks (one per activity)
T+15-60m: Pull function fetches FIT files
T+15-60m: FIT files stored in database ✅
```

## Important Notes

- **FIT files are fetched automatically** - No manual action needed
- **Timing depends on Garmin** - Can take 15-60 minutes for webhooks
- **Each activity gets its own webhook** - FIT files arrive gradually
- **Not all activities have FIT files** - Only activities with GPS/track data

