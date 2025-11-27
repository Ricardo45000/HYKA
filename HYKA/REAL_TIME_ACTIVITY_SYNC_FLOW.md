# Real-Time Activity Sync Flow

## When You Complete an Activity on Garmin

### Step-by-Step Flow:

1. **You finish activity on Garmin device**
   - Activity is saved to Garmin Connect
   - Usually happens within seconds to minutes after you stop the activity

2. **Garmin sends webhook to Supabase** (Automatic)
   - Garmin automatically sends a webhook to your configured endpoint
   - Webhook type: **PING** (notification) or **PUSH** (full data)
   - Endpoint: `garmin-activity-push` or `garmin-activity-ping`
   - **Timing**: Usually within 1-5 minutes after activity is saved

3. **Supabase Edge Function processes webhook** (Automatic)
   - `garmin-activity-push` receives the activity data
   - Filters activities (only Running/Hiking/Walking)
   - Stores in `garmin_activities` table
   - Fetches details (GPS samples, FIT file) if needed
   - **Timing**: Usually completes in 1-10 seconds

4. **Activity appears in Supabase database** (Automatic)
   - Stored in `garmin_activities` table
   - GPS samples in `garmin_activity_samples` table
   - FIT file in `garmin_fit_files` table
   - **Timing**: Available immediately after webhook processing

5. **App reads from Supabase** (When app is opened/refreshed)
   - App queries `garmin_activities` table
   - Uses `SupabaseService.fetchGarminActivities()`
   - **Timing**: Depends on when you open/refresh the app

## Current Implementation

### ✅ What Works Automatically:
- **Garmin → Supabase**: Fully automatic via webhooks
- **Webhook processing**: Automatic (no manual intervention needed)
- **Database storage**: Automatic

### ⚠️ What Requires App Action:
- **App display**: App needs to be opened/refreshed to see new activities
- **No real-time push notifications**: App doesn't automatically refresh when new activities arrive

## How to See New Activities in App

### Option 1: Open/Refresh App
- Open the app
- Navigate to the screen that shows activities
- Activities will be fetched from Supabase

### Option 2: Pull to Refresh (if implemented)
- Pull down to refresh the activity list
- App queries Supabase for new activities

### Option 3: Background Refresh (if implemented)
- iOS can refresh app in background
- But this requires app to be running or iOS to trigger it

## Timeline Example

**Scenario**: You finish a run at 2:00 PM

- **2:00 PM**: Activity saved to Garmin Connect
- **2:01 PM**: Garmin sends webhook to Supabase
- **2:01 PM**: Supabase processes and stores activity (1-10 seconds)
- **2:01 PM**: Activity available in Supabase database ✅
- **2:05 PM**: You open the app → Activity appears ✅

**Total time**: ~1-5 minutes from activity completion to Supabase, then instant when you open the app

## Verification

### Check if Webhooks Are Working:

1. **Check Supabase Logs**:
   - Go to Edge Functions → Logs
   - Filter by `garmin-activity-push` or `garmin-activity-ping`
   - Look for recent webhook invocations (should see 200 OK)

2. **Check Database**:
   ```sql
   SELECT * FROM garmin_activities 
   WHERE user_id = 'YOUR_USER_ID' 
   ORDER BY start_time_seconds DESC 
   LIMIT 5;
   ```

3. **Check App**:
   - Open app
   - Navigate to activities/workouts screen
   - Should see new activities

## Potential Issues

### If Activities Don't Appear:

1. **Webhook not configured**:
   - Check Garmin Developer Portal → Endpoint Configuration
   - Verify webhook URLs are correct and enabled

2. **Webhook not arriving**:
   - Check Supabase Edge Function logs
   - Look for 401 errors (function not public)
   - Look for webhook invocations

3. **Activity filtered out**:
   - Only Running/Hiking/Walking activities are stored
   - Other types (Cycling, Swimming, etc.) are filtered out
   - Check logs for "⏭️ Skipping activity type"

4. **App not refreshing**:
   - App needs to query Supabase to see new activities
   - No automatic real-time updates (unless implemented)

## Summary

✅ **Yes, Supabase will automatically get the activity** via webhooks (1-5 minutes after completion)

✅ **Yes, your app will show it** when you open/refresh the app

⚠️ **No automatic real-time push** - App needs to be opened or refreshed to see new activities

---

**The flow is automatic from Garmin → Supabase, but the app needs to query Supabase to display new activities.**

