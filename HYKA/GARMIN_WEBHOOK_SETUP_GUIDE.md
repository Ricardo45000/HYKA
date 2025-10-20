# Garmin Webhook Configuration Guide

## Overview

This guide shows how to configure Garmin Developer Portal to send activity notifications to your Supabase Edge Functions.

## Prerequisites

- ✅ Supabase project set up
- ✅ Edge Functions deployed (`garmin-activity-ping`, `garmin-activity-push`, `garmin-activity-fetch`)
- ✅ Database schema created (`garmin_backend_schema.sql`)
- ✅ Garmin Developer account with app configured for OAuth 2.0

## Step 1: Deploy Edge Functions

First, deploy all Edge Functions to Supabase:

```bash
# Login to Supabase
supabase login

# Deploy webhook receivers
supabase functions deploy garmin-activity-ping
supabase functions deploy garmin-activity-push
supabase functions deploy garmin-activity-fetch
supabase functions deploy garmin-hourly-sync

# Verify deployment
supabase functions list
```

## Step 2: Get Your Edge Function URLs

Your webhook URLs will be:

```
https://YOUR_PROJECT_ID.supabase.co/functions/v1/garmin-activity-ping
https://YOUR_PROJECT_ID.supabase.co/functions/v1/garmin-activity-push
```

Replace `YOUR_PROJECT_ID` with your actual Supabase project ID.

Example:
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
```

## Step 3: Configure Garmin Developer Portal

### 3.1 Login to Garmin Developer Portal

1. Go to https://developerportal.garmin.com/
2. Sign in with your Garmin account
3. Select your application

### 3.2 Navigate to Endpoint Configuration

1. Click on your app name
2. Go to **"Endpoint Configuration"** or **"Webhook Configuration"** section
3. You should see a list of available endpoints

### 3.3 Configure Activity Endpoints

Configure the following endpoints:

#### **Activities Endpoint** (PING)

- **Name**: Activities
- **URL**: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/garmin-activity-ping`
- **Method**: POST
- **Type**: PING (notification only)
- **Description**: Receives notifications when new activities are uploaded

#### **Activity Details Endpoint** (PUSH - Optional)

- **Name**: Activity Details
- **URL**: `https://YOUR_PROJECT_ID.supabase.co/functions/v1/garmin-activity-push`
- **Method**: POST
- **Type**: PUSH (includes activity data)
- **Description**: Receives activity summaries directly

### 3.4 Enable Endpoints

1. Check the "Enable" checkbox for each endpoint
2. Click **"Save"** or **"Update"**

### 3.5 Test Endpoints (Optional)

Some Garmin Developer Portals have a "Test" button:

1. Click **"Test"** next to each endpoint
2. Verify you receive a response
3. Check Supabase Edge Function logs for incoming requests

## Step 4: Update Pull Token Daily

Pull Tokens expire every 24 hours. Set up a reminder to update them daily.

### 4.1 Get New Pull Token

1. Go to Garmin Developer Portal
2. Navigate to **"API Pull Token"** or **"Wellness API"** section
3. Generate a new Pull Token
4. Copy the token (format: `CPT1234567890.randomstring`)

### 4.2 Update in Supabase

Option A: SQL Editor

```sql
SELECT update_garmin_pull_token('CPT1234567890.randomstring');
```

Option B: Via API

```bash
curl -X POST 'https://YOUR_PROJECT_ID.supabase.co/rest/v1/rpc/update_garmin_pull_token' \
  -H 'apikey: YOUR_ANON_KEY' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"new_token": "CPT1234567890.randomstring"}'
```

### 4.3 Automate Pull Token Updates (Advanced)

You can set up a daily reminder or automation:

1. **Calendar Reminder**: Set daily reminder at specific time
2. **Automation Script**: Create script that updates token from Garmin API
3. **Manual Process**: Update manually each morning

**Note**: Garmin does not provide an API to automatically get Pull Tokens. They must be manually copied from the Developer Portal.

## Step 5: Set Up Hourly Cron Job

Run the SQL commands in `garmin_hourly_sync_setup.sql`:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hourly sync
SELECT cron.schedule(
    'garmin-hourly-sync',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/garmin-hourly-sync',
        headers := jsonb_build_object(
            'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);
```

**Important**: Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key from Supabase Dashboard → Settings → API.

## Step 6: Test the Integration

### 6.1 Connect Garmin in iOS App

1. Open HYKA app
2. Go to Profile → Connect Garmin
3. Complete OAuth 2.0 authorization
4. App should save connection to Supabase

### 6.2 Verify Connection in Database

```sql
SELECT * FROM garmin_connections ORDER BY created_at DESC LIMIT 1;
```

You should see your connection with `garmin_user_id` populated.

### 6.3 Sync Your Watch

1. Go for a run/hike/walk with your Garmin watch
2. Wait for watch to sync with Garmin Connect app
3. Wait a few minutes for webhook to trigger

### 6.4 Check Activities in Database

```sql
SELECT * FROM garmin_activities ORDER BY created_at DESC LIMIT 10;
```

You should see your recent activity!

### 6.5 Check Edge Function Logs

1. Go to Supabase Dashboard
2. Navigate to Edge Functions → Logs
3. Select `garmin-activity-ping` or `garmin-activity-fetch`
4. Look for log entries showing webhook received and activity fetched

## Troubleshooting

### Webhook Not Receiving Data

**Problem**: Edge Function not being called

**Solutions**:
1. Verify webhook URL is correct in Garmin Developer Portal
2. Check Edge Function is deployed: `supabase functions list`
3. Check Garmin Developer Portal shows endpoint as "Enabled"
4. Test endpoint manually with curl:

```bash
curl -X POST 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/garmin-activity-ping' \
  -H 'Content-Type: application/json' \
  -d '{"userId": "test_user"}'
```

### Pull Token Expired

**Problem**: Activities not being fetched, logs show "InvalidPullTokenException"

**Solutions**:
1. Get new Pull Token from Garmin Developer Portal
2. Update in Supabase: `SELECT update_garmin_pull_token('NEW_TOKEN');`
3. Verify update: `SELECT * FROM app_config WHERE key = 'garmin_pull_token';`

### 401 Unauthorized Errors

**Problem**: All API calls return 401

**Solutions**:
1. Access token may have expired (valid for 24 hours)
2. User needs to disconnect and reconnect Garmin
3. Check `expires_at` in `garmin_connections` table
4. Implement token refresh logic (use `refresh_token`)

### No garmin_user_id in Database

**Problem**: garmin_connections has NULL garmin_user_id

**Solutions**:
1. This means `fetchUserId()` wasn't called during OAuth
2. User needs to reconnect Garmin
3. Verify `DeviceOAuthManager` calls `client.fetchUserId()` after token exchange

### Hourly Sync Not Running

**Problem**: Cron job not executing

**Solutions**:
1. Check if pg_cron is enabled: `SELECT * FROM pg_extension WHERE extname = 'pg_cron';`
2. Verify cron job exists: `SELECT * FROM cron.job WHERE jobname = 'garmin-hourly-sync';`
3. Check execution history: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`
4. Check service role key is correct in cron job SQL

## Monitoring

### Check Sync Health

```sql
SELECT * FROM garmin_sync_health ORDER BY hours_since_sync DESC;
```

### Check Recent Activities

```sql
SELECT 
    user_id,
    activity_name,
    activity_type,
    start_time,
    distance_meters / 1000 AS distance_km,
    total_elevation_gain_meters AS elevation_m
FROM garmin_activities
ORDER BY start_time DESC
LIMIT 20;
```

### Check Webhook Execution

```sql
SELECT 
    jobname,
    status,
    return_message,
    start_time,
    end_time
FROM cron.job_run_details
WHERE jobname = 'garmin-hourly-sync'
ORDER BY start_time DESC
LIMIT 10;
```

## Summary

✅ **Setup Checklist**:

1. ✅ Deploy Edge Functions
2. ✅ Configure webhooks in Garmin Developer Portal
3. ✅ Set up Pull Token (update daily)
4. ✅ Create cron job for hourly sync
5. ✅ Test with real Garmin activity
6. ✅ Monitor logs and database

✅ **Daily Maintenance**:

- Update Pull Token from Garmin Developer Portal
- Check sync health: `SELECT * FROM garmin_sync_health;`
- Review Edge Function logs for errors

✅ **User Experience**:

- Users connect Garmin in app (one-time)
- Data flows automatically (no manual sync needed)
- Activities appear in app within minutes of Garmin sync

---

**Need Help?**

- Check Edge Function logs in Supabase Dashboard
- Review `GARMIN_BACKEND_ARCHITECTURE.md` for architecture overview
- Check Garmin Developer Portal documentation

