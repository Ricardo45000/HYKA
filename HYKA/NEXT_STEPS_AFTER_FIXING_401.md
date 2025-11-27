# Next Steps After Fixing 401 Errors

## ✅ What You Just Did
- Made Garmin webhook functions public/anonymous in Supabase Dashboard
- Functions should now accept webhooks from Garmin without authentication

## 🔍 Step 1: Verify Webhooks Are Working

### Check Supabase Logs
1. Go to **Supabase Dashboard → Edge Functions → Logs**
2. Filter by:
   - `garmin-health-webhook`
   - `garmin-activity-push`
   - `garmin-activity-ping`
3. Look for:
   - ✅ **200 OK** responses (success!)
   - ❌ **401 Unauthorized** (still blocked - check function settings)
   - ❌ **500 Internal Server Error** (function code issue)

### What to Look For
- Recent webhook invocations (last few minutes/hours)
- Status codes should be **200** (not 401)
- Check for any error messages in the logs

## 🧪 Step 2: Test the Status Checker

### In the App
1. Open the HYKA app
2. Navigate to Race Plan view
3. Tap **"Check Sync Status"** button
4. Review the results:
   - If working: "✅ Sync is working! Found X recent activities..."
   - If issues: "⚠️ No recent activities found..." with recommendations

### What It Checks
- Garmin connection status
- Recent activities in database (last 24 hours)
- Backfill request status
- Webhook configuration

## 📊 Step 3: Verify Activities Are Syncing

### Check Database
Run this SQL query in Supabase Dashboard → SQL Editor:

```sql
-- Check recent activities
SELECT 
  id,
  activity_type,
  start_time_seconds,
  distance_meters,
  created_at
FROM garmin_activities
WHERE user_id = 'YOUR_USER_ID'
ORDER BY start_time_seconds DESC
LIMIT 10;
```

### Check Health Metrics
```sql
-- Check recent health metrics
SELECT 
  id,
  timestamp,
  fitness_age,
  vo2_max,
  created_at
FROM garmin_health_metrics
WHERE user_id = 'YOUR_USER_ID'
ORDER BY timestamp DESC
LIMIT 10;
```

## 🎯 Step 4: Test Automatic Sync

### Create a Test Activity
1. **In Garmin Connect:**
   - Record a short activity (walk/run)
   - Or manually add an activity
   - Wait 2-5 minutes for webhook to arrive

2. **Check Supabase:**
   - Look for the activity in `garmin_activities` table
   - Should appear automatically (no manual sync needed!)

3. **Check App:**
   - Activities should appear in the app
   - No need to tap "Sync with Device"

## 🔧 Step 5: Monitor Webhook Delivery

### Expected Behavior
- **New activities** → Garmin sends webhook → Appears in database automatically
- **Health updates** → Garmin sends webhook → Appears in database automatically
- **No manual sync needed** for new data

### If Activities Still Don't Appear

1. **Check Webhook Logs:**
   - Are webhooks being received? (200 OK)
   - Are there any errors in the logs?

2. **Check Activity Types:**
   - Only **Running/Hiking/Walking** activities are stored
   - Other types (Cycling, Swimming, etc.) are filtered out
   - Check logs for: "⏭️ Skipping activity type: Cycling"

3. **Check Garmin Connection:**
   - Is the connection still active?
   - Are permissions revoked?
   - Use status checker in app

4. **Check Webhook Configuration:**
   - Verify URLs in Garmin Developer Portal
   - Ensure webhooks are **enabled** (not "on hold")
   - Check that URLs match your Supabase functions

## 🚀 Step 6: Remove "Sync with Device" Dependency

Since activities should sync automatically, the "Sync with Device" button is now:
- **Optional** - for manual refresh or troubleshooting
- **Not required** - for new activities (they sync automatically)

The button has been renamed to **"Check Sync Status"** to reflect its diagnostic purpose.

## 📝 Step 7: Enable Additional Health Endpoints (Optional)

Based on your Garmin Developer Portal screenshot, you can enable more health data:

### Currently Enabled:
- ✅ Health Snapshot
- ✅ User Metrics

### Can Enable (if needed):
- Body Compositions
- Dailies
- Epochs
- HRV Summary
- Pulse Ox
- Respiration
- Skin Temperature
- Sleeps
- Stress
- Blood Pressure

**Note:** You'll need to update the webhook URLs in Garmin Developer Portal to point to `garmin-health-webhook` for these endpoints.

## ✅ Success Criteria

You'll know everything is working when:

1. ✅ Webhooks return **200 OK** (not 401)
2. ✅ Activities appear in database automatically
3. ✅ Health metrics appear in database automatically
4. ✅ Status checker shows recent activities
5. ✅ No manual "Sync with Device" needed for new data

## 🐛 Troubleshooting

### If webhooks still return 401:
- Double-check function settings in Supabase Dashboard
- Verify "Require Authentication" is disabled
- Try the CLI command: `supabase functions update garmin-health-webhook --no-verify-jwt`

### If activities don't appear:
- Check webhook logs for errors
- Verify activity types (only Running/Hiking/Walking)
- Check Garmin connection status
- Use status checker for diagnostics

### If health metrics don't appear:
- Verify health webhooks are enabled in Garmin Developer Portal
- Check webhook logs for `garmin-health-webhook`
- Verify `garmin_health_metrics` table exists

---

**Next:** Wait a few minutes, then check Supabase logs to see if webhooks are arriving successfully!

