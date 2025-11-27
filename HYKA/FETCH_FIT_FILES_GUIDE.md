# How to Fetch FIT Files from Garmin

## Process Overview

FIT files are fetched automatically when Garmin sends webhooks. Here's the flow:

1. **Trigger Backfill** → Garmin processes historical data
2. **Garmin Sends Webhooks** → Each webhook includes a `callbackUrl`
3. **Pull Function Fetches Data** → Uses `callbackUrl` to get summary, details, and FIT file
4. **Store Function Saves** → FIT file is stored in `garmin_fit_files` table

## Step 1: Trigger Backfill (Get Webhooks)

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-backfill" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "fc600af9-2926-4b86-b841-25a25d17c10c"
  }'
```

**Note:** This requires a valid Garmin access token. If you get "Token is not active", you need to refresh the token first.

## Step 2: Wait for Webhooks

After triggering backfill:
- Garmin processes the request (15-60 minutes for 29 days)
- Garmin sends webhooks to `garmin-activity-ping` or `garmin-activity-push`
- Each webhook contains a `callbackUrl` with a temporary Pull Token

## Step 3: Pull Function Automatically Fetches FIT Files

When a webhook arrives:
1. `garmin-activity-ping` receives webhook with `callbackUrl`
2. Calls `garmin-activity-pull` with the `callbackUrl`
3. Pull function fetches:
   - Summary: `GET callbackUrl`
   - Details: `GET callbackUrl/details`
   - **FIT File: `GET callbackUrl/file`** ← This is what you want!
4. `garmin-activity-store` saves everything including FIT file

## Manual Test (If You Have a Real callbackUrl)

If you have a real `callbackUrl` from a Garmin webhook:

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-pull" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "callbackUrl": "https://apis.garmin.com/wellness-api/rest/activities/REAL_ID/pull?token=REAL_TOKEN",
    "garminUserId": "3a0c1dcd-b337-4cc4-be69-e56efeb3f360",
    "summaryId": REAL_SUMMARY_ID
  }'
```

## Check Stored FIT Files

Query the database to see stored FIT files:

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

## Current Issue

Your Garmin access token is expired. You need to:

1. **Refresh the token** (reconnect Garmin in the app)
2. **Then trigger backfill** to get webhooks
3. **Webhooks will automatically fetch FIT files**

