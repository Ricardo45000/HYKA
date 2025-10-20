# Garmin Backend Architecture - Deployment Checklist

## Overview

Complete checklist for deploying the new Garmin backend architecture.

## ✅ Phase 1: Database Setup

### 1.1 Run Database Schema

```sql
-- Run this in Supabase SQL Editor
\i garmin_backend_schema.sql
```

**Verify**:
```sql
-- Check tables exist
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename LIKE 'garmin%';

-- Expected output:
-- garmin_connections
-- garmin_activities
-- garmin_activity_samples
```

### 1.2 Insert Initial Pull Token

```sql
-- Get Pull Token from Garmin Developer Portal
-- Then update in Supabase:
SELECT update_garmin_pull_token('CPT1763250098.9HZ__7xckH4'); -- REPLACE WITH YOUR TOKEN
```

**Verify**:
```sql
SELECT * FROM app_config WHERE key = 'garmin_pull_token';
```

## ✅ Phase 2: Deploy Edge Functions

### 2.1 Login to Supabase CLI

```bash
supabase login
```

### 2.2 Deploy All Functions

```bash
# Deploy webhook receivers
supabase functions deploy garmin-activity-ping
supabase functions deploy garmin-activity-push

# Deploy data fetcher
supabase functions deploy garmin-activity-fetch

# Deploy hourly sync
supabase functions deploy garmin-hourly-sync
```

### 2.3 Verify Deployment

```bash
supabase functions list
```

**Expected output**:
```
Function Name              Version    Created At
garmin-activity-ping       1          2025-11-16 ...
garmin-activity-push       1          2025-11-16 ...
garmin-activity-fetch      1          2025-11-16 ...
garmin-hourly-sync         1          2025-11-16 ...
```

## ✅ Phase 3: Configure Garmin Developer Portal

### 3.1 Get Webhook URLs

Your URLs are:
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push
```

### 3.2 Configure Webhooks

1. Go to https://developerportal.garmin.com/
2. Select your application
3. Navigate to "Endpoint Configuration"
4. Add endpoints:
   - **Activities**: `garmin-activity-ping` (PING type)
   - **Activity Details**: `garmin-activity-push` (PUSH type)
5. Enable both endpoints
6. Save configuration

**Verify**:
- Both endpoints show as "Enabled"
- Test buttons return 200 OK (if available)

## ✅ Phase 4: Set Up Cron Job

### 4.1 Enable pg_cron

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

### 4.2 Schedule Hourly Sync

```sql
SELECT cron.schedule(
    'garmin-hourly-sync',
    '0 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-hourly-sync',
        headers := jsonb_build_object(
            'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY_HERE',  -- GET FROM SUPABASE DASHBOARD
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);
```

**IMPORTANT**: Replace `YOUR_SERVICE_ROLE_KEY_HERE` with your actual service role key:
1. Go to Supabase Dashboard
2. Settings → API
3. Copy `service_role` (secret) key

**Verify**:
```sql
SELECT * FROM cron.job WHERE jobname = 'garmin-hourly-sync';
```

## ✅ Phase 5: iOS App Updates

All iOS changes are already complete! ✅

- ✅ `GarminAPIClient.swift` - Removed activity fetching
- ✅ `GarminConfig.swift` - Removed Pull Token
- ✅ `RacePlanView.swift` - Removed "Sync with device" button
- ✅ `WorkoutDataFetchingService.swift` - Stubbed Garmin cases

**No further iOS changes needed!**

## ✅ Phase 6: Testing

### 6.1 Test OAuth Connection

1. Open HYKA iOS app
2. Go to Profile → Connect Garmin
3. Complete OAuth authorization
4. Check database:

```sql
SELECT * FROM garmin_connections ORDER BY created_at DESC LIMIT 1;
```

**Expected**: Row with your `user_id` and `garmin_user_id`

### 6.2 Test Activity Sync

1. Sync your Garmin watch (or wait for existing activity)
2. Wait 2-5 minutes for webhook
3. Check database:

```sql
SELECT * FROM garmin_activities ORDER BY created_at DESC LIMIT 5;
```

**Expected**: Your recent activities appear

### 6.3 Test Samples

```sql
SELECT COUNT(*) FROM garmin_activity_samples 
WHERE activity_id = (SELECT id FROM garmin_activities ORDER BY created_at DESC LIMIT 1);
```

**Expected**: Count > 0 (GPS/HR samples for latest activity)

### 6.4 Test Edge Function Manually

```bash
curl -X POST 'https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping' \
  -H 'Content-Type: application/json' \
  -d '{"userId": "test_user_id"}'
```

**Expected**: 200 OK response

### 6.5 Check Edge Function Logs

1. Go to Supabase Dashboard
2. Edge Functions → Logs
3. Select `garmin-activity-ping`
4. Verify logs show webhook received

## ✅ Phase 7: Monitoring Setup

### 7.1 Create Monitoring Views

```sql
-- Already created in garmin_backend_schema.sql
SELECT * FROM garmin_sync_health;
```

### 7.2 Set Up Daily Pull Token Update Reminder

Choose one:

**Option A**: Calendar reminder
- Set daily reminder at 9 AM
- Task: Update Garmin Pull Token

**Option B**: Email reminder
- Use email automation service
- Send daily at 9 AM

**Option C**: Manual check
- Check Pull Token daily when starting work

### 7.3 Monitor Sync Health

```sql
-- Run this daily or weekly
SELECT 
    sync_status,
    COUNT(*) as user_count
FROM garmin_sync_health
GROUP BY sync_status;

-- Expected output:
-- sync_status | user_count
-- Healthy     | 95
-- Warning     | 3
-- Stale       | 2
```

## ✅ Phase 8: Documentation

All documentation is complete! ✅

- ✅ `GARMIN_BACKEND_ARCHITECTURE.md` - Full architecture overview
- ✅ `garmin_backend_schema.sql` - Database schema with comments
- ✅ `GARMIN_WEBHOOK_SETUP_GUIDE.md` - Webhook configuration
- ✅ `garmin_hourly_sync_setup.sql` - Cron job setup
- ✅ This file (`GARMIN_DEPLOYMENT_CHECKLIST.md`)

## ✅ Phase 9: Rollback Plan (If Needed)

If something goes wrong, here's how to rollback:

### 9.1 Disable Webhooks

1. Go to Garmin Developer Portal
2. Disable all webhook endpoints
3. This stops new data from flowing

### 9.2 Disable Cron Job

```sql
SELECT cron.unschedule('garmin-hourly-sync');
```

### 9.3 Keep Database Tables

**DO NOT** drop tables - they contain user data!

### 9.4 iOS App Still Works

iOS app will continue to work (OAuth still functional), just no new activity data will flow.

## ✅ Phase 10: Post-Deployment

### 10.1 First Week Monitoring

- Check Edge Function logs daily
- Monitor sync health: `SELECT * FROM garmin_sync_health;`
- Update Pull Token daily
- Watch for errors in cron job: `SELECT * FROM cron.job_run_details;`

### 10.2 First Month

- Analyze sync success rate
- Monitor database growth
- Optimize queries if needed
- Consider adding indexes if queries are slow

### 10.3 Ongoing Maintenance

**Daily**:
- Update Pull Token from Garmin Developer Portal

**Weekly**:
- Check sync health: `SELECT * FROM garmin_sync_health;`
- Review Edge Function logs for errors

**Monthly**:
- Analyze database storage usage
- Review sync success rates
- Check for users needing to reconnect

## Troubleshooting

### Issue: Webhooks Not Working

**Symptoms**: No activities appearing in database

**Checks**:
1. Edge Functions deployed? `supabase functions list`
2. Webhooks enabled in Garmin Portal?
3. Pull Token current? `SELECT * FROM app_config WHERE key = 'garmin_pull_token';`
4. Any errors in logs?

**Fix**:
- Test webhook manually with curl
- Check Edge Function logs
- Verify webhook URL is correct

### Issue: Cron Job Not Running

**Symptoms**: `last_sync_at` not updating

**Checks**:
1. pg_cron enabled? `SELECT * FROM pg_extension WHERE extname = 'pg_cron';`
2. Cron job exists? `SELECT * FROM cron.job WHERE jobname = 'garmin-hourly-sync';`
3. Service role key correct in cron job?

**Fix**:
```sql
-- Check execution history
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'garmin-hourly-sync')
ORDER BY start_time DESC 
LIMIT 10;
```

### Issue: 401 Unauthorized Errors

**Symptoms**: All API calls fail with 401

**Cause**: Access tokens expired (24 hour validity)

**Fix**:
- User needs to reconnect Garmin in app
- Implement token refresh logic (use `refresh_token`)

### Issue: Pull Token Expired

**Symptoms**: "InvalidPullTokenException failure"

**Fix**:
1. Get new Pull Token from Garmin Developer Portal
2. Update: `SELECT update_garmin_pull_token('NEW_TOKEN');`

## Success Metrics

After deployment, you should see:

✅ **Immediate (Day 1)**:
- [ ] Edge Functions deployed and responding
- [ ] Webhooks configured in Garmin Portal
- [ ] Cron job scheduled and running
- [ ] Test activity synced successfully

✅ **Short Term (Week 1)**:
- [ ] All connected users receiving activity data
- [ ] Sync health shows > 90% "Healthy" status
- [ ] No critical errors in logs
- [ ] Pull Token updated daily

✅ **Long Term (Month 1)**:
- [ ] Consistent sync success rate
- [ ] Users report activities appearing automatically
- [ ] Database growing steadily
- [ ] No complaints about missing data

## Summary

### What Changed

**Before**:
- iOS app → Garmin APIs → Supabase
- Manual "Sync with device" button
- Pull Token in iOS app

**After**:
- iOS app → Supabase ← Edge Functions ← Garmin webhooks
- Automatic sync (no user action needed)
- Pull Token in backend only

### Benefits

✅ **Security**: Pull Token never exposed to client
✅ **Automatic**: Data flows without user action
✅ **Scalable**: Backend handles all API calls
✅ **Compliant**: Follows official Garmin architecture

### Next Steps

1. ✅ Deploy all components (database, Edge Functions, webhooks, cron)
2. ✅ Test with real Garmin account
3. ✅ Monitor for first week
4. ✅ Set up daily Pull Token update process
5. ✅ Roll out to users

---

**Questions or Issues?**

Refer to:
- `GARMIN_BACKEND_ARCHITECTURE.md` - Architecture overview
- `GARMIN_WEBHOOK_SETUP_GUIDE.md` - Webhook configuration
- Edge Function logs in Supabase Dashboard
- `garmin_sync_health` view for monitoring

