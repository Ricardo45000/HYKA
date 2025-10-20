# Complete Garmin OAuth 2.0 Setup Guide

## ✅ Solution: No OAuth 1.0a Required!

Since Garmin no longer supports OAuth 1.0a for new applications, we'll use **OAuth 2.0 PKCE** for everything.

## What You Need

1. ✅ **OAuth 2.0 PKCE Application** (already created)
   - Client ID: `695055f8-9786-4fda-a3a7-f7c2e88382f0`
   - Client Secret: Already in Supabase Edge Function

2. ✅ **Supabase Edge Functions**
   - `garmin-token-exchange` - Already deployed
   - `garmin-sync-all-users` - New function for periodic sync

3. ✅ **Database**
   - `oauth_connections` table (stores OAuth 2.0 tokens)
   - `workouts` table (stores activities)

## Setup Steps

### Step 1: Create OAuth 2.0 Application (If Not Done)

1. Go to https://developerportal.garmin.com/
2. Navigate to **My Apps**
3. Create new app with:
   - **OAuth Version**: OAuth 2.0 PKCE
   - **Application Type**: Mobile Application
   - **Redirect URI**: `com.hyka.app://garmin/callback`

### Step 2: Deploy Sync Function

```bash
supabase functions deploy garmin-sync-all-users
```

### Step 3: Set Up Cron Job

In Supabase SQL Editor, run:

```sql
-- Create cron job to sync Garmin activities every 6 hours
SELECT cron.schedule(
  'sync-garmin-activities',
  '0 */6 * * *', -- Every 6 hours
  $$
  SELECT
    net.http_post(
      url := 'https://[your-project-ref].supabase.co/functions/v1/garmin-sync-all-users',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb
    ) AS request_id;
  $$
);
```

Replace `[your-project-ref]` with your Supabase project reference.

### Step 4: Test Manual Sync

```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/garmin-sync-all-users \
  -H "Content-Type: application/json"
```

## How It Works

1. **User connects Garmin** via iOS app (OAuth 2.0 PKCE)
2. **Tokens stored** in `oauth_connections` table
3. **Cron job runs** every 6 hours
4. **Sync function** fetches new activities for all users
5. **Activities stored** in `workouts` table
6. **iOS app** syncs with Supabase to get new activities

## Manual Sync from iOS

Your existing "Sync with Garmin" button already works! It:
- Uses OAuth 2.0 PKCE tokens
- Fetches activities from Garmin
- Stores in Supabase

## Advantages of This Approach

✅ **No OAuth 1.0a required**
✅ **Works with current Garmin Developer Portal**
✅ **Automatic background sync**
✅ **Manual sync still available**
✅ **Uses existing OAuth 2.0 setup**

## Monitoring

### Check Cron Job

```sql
SELECT * FROM cron.job WHERE jobname = 'sync-garmin-activities';
```

### View Sync Logs

```bash
supabase functions logs garmin-sync-all-users
```

### Check Synced Activities

```sql
SELECT 
  COUNT(*) as total_activities,
  COUNT(DISTINCT user_id) as users_with_activities,
  MAX(created_at) as last_sync
FROM workouts 
WHERE provider = 'garmin';
```

## Troubleshooting

### No Activities Syncing

1. Check if users have valid OAuth tokens:
   ```sql
   SELECT user_id, 
          LEFT(access_token, 20) as token_preview,
          expires_at
   FROM oauth_connections 
   WHERE provider = 'garmin';
   ```

2. Check sync function logs for errors

3. Verify OAuth tokens are not expired

### Token Refresh Needed

If tokens expire, you'll need to:
1. Implement token refresh in the sync function
2. Or have users reconnect Garmin

## Next Steps

1. ✅ Deploy `garmin-sync-all-users` function
2. ✅ Set up cron job
3. ✅ Test manual sync
4. ✅ Monitor logs
5. ✅ Verify activities are being stored

## Summary

**You don't need OAuth 1.0a!** Use OAuth 2.0 PKCE (which you already have) with periodic server-side syncing. This is simpler and works with Garmin's current API.

