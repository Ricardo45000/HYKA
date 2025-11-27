# Fixed: Connection Date Check in Direct Fetch

## Problem

When requesting 90 days, the function tried to fetch dates before the user's connection date (October 26, 2025). Garmin rejected 59 chunks with 400 errors because you can't backfill before the connection date.

## Solution

Updated `garmin-activity-direct-fetch` to:
1. **Check connection date** from `garmin_connections` table
2. **Automatically adjust** start date to be at least the connection date
3. **Skip invalid chunks** that would be before connection date

## What Changed

The function now:
- Fetches `connected_at` from the database
- Compares requested start date with connection date
- Adjusts start date if it's before connection date
- Only requests chunks from connection date forward

## Redeploy Required

After redeploying, the function will automatically:
- Only request dates from connection date forward
- Avoid 400 errors for dates before connection
- Show adjusted date range in logs

## Test After Redeployment

```bash
# This will now automatically adjust to connection date
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-direct-fetch" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
    "days_ago": 90
  }'
```

**Expected behavior:**
- Will only request ~31 days (from Oct 26 to Nov 26)
- Will skip the 59 days before connection date
- Will show adjusted date range in response

## Current Status

From the previous test:
- ✅ **31 chunks** (Oct 26 - Nov 26) should have been accepted
- ❌ **59 chunks** (Aug 28 - Oct 25) were rejected (before connection)

After redeployment, it will automatically skip those 59 chunks and only request the valid 31 days.

