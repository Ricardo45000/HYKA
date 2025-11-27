# How to Use the Webhook Status Checker

## Overview

The webhook status checker helps diagnose why activities aren't automatically syncing from Garmin to Supabase. It checks:
- ✅ Garmin connection status
- ✅ Recent activities in database
- ✅ Backfill request status
- ✅ Webhook configuration
- ✅ Provides recommendations for fixing issues

---

## How to Use in the App

### Step 1: Open the App
1. Launch the HYKA app
2. Navigate to the Race Plan view (where you see your race plans)

### Step 2: Find the Button
- Look for the **"Check Sync Status"** button in the profile/device section
- It should be next to where your connected Garmin device is shown

### Step 3: Tap the Button
- Tap **"Check Sync Status"**
- The button will show "Checking..." while it runs

### Step 4: Review the Results
The app will show one of two outcomes:

#### ✅ **If Sync is Working:**
```
✅ Sync is working! Found X recent activities in database. 
Activities are syncing automatically via webhooks.
```

#### ⚠️ **If Issues Detected:**
```
⚠️ No recent activities found. Possible issues:

1. No recent activities found in database
2. Check if webhooks are configured in Garmin Developer Portal
3. Check Supabase Edge Function logs for webhook invocations
4. Verify activity types match filter (Running/Hiking/Walking only)
...
```

---

## What the Status Checker Does

### 1. **Checks Garmin Connection**
- Verifies you have a Garmin account connected
- Checks connection date
- Checks if permissions were revoked

### 2. **Checks Recent Activities**
- Looks for activities in the last 24 hours
- Shows count of recent activities
- Shows the latest activity details

### 3. **Checks Backfill Requests**
- Shows recent backfill requests
- Shows pending vs completed requests
- Identifies stuck requests (pending > 24 hours)

### 4. **Provides Recommendations**
- Suggests fixes based on what it finds
- Points to specific issues (webhook config, activity types, etc.)

---

## Manual Testing (via Terminal)

You can also test the status checker directly via curl:

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/garmin-webhook-status \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "user_id": "YOUR_USER_ID"
  }'
```

**Response Example:**
```json
{
  "success": true,
  "diagnostics": {
    "connection": {
      "exists": true,
      "garmin_user_id": "3a0c1dcd-b337-4cc4-be69-e56efeb3f360",
      "connected_at": "2025-11-18T20:12:30.461Z",
      "last_sync_at": "2025-11-20T10:30:00.000Z",
      "permission_revoked": false,
      "days_since_connection": 2
    },
    "activities": {
      "recent_count": 3,
      "has_recent_activities": true,
      "latest_activity": {
        "id": "12345",
        "type": "Running",
        "start_time": "2025-11-20T08:00:00.000Z",
        "created_at": "2025-11-20T08:05:00.000Z"
      }
    },
    "backfill_requests": {
      "recent_count": 2,
      "pending_count": 0,
      "completed_count": 2,
      "latest_request": {
        "status": "completed",
        "created_at": "2025-11-20T09:00:00.000Z",
        "age_hours": 1
      }
    },
    "webhook_configuration": {
      "ping_url": "https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-ping",
      "push_url": "https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push",
      "health_url": "https://YOUR_PROJECT.supabase.co/functions/v1/garmin-health-webhook",
      "note": "Verify these URLs are configured in Garmin Developer Portal → Endpoint Configuration"
    },
    "recommendations": []
  },
  "duration": "45ms"
}
```

---

## Common Issues and Fixes

### Issue 1: "No recent activities found"
**Possible Causes:**
- Webhooks not configured in Garmin Developer Portal
- Webhooks not being received
- Activities filtered out (wrong activity type)

**Fix:**
1. Go to Garmin Developer Portal → Endpoint Configuration
2. Verify webhook URLs are correct
3. Check Supabase Edge Function logs for webhook invocations
4. Verify activity types (only Running/Hiking/Walking are stored)

---

### Issue 2: "Garmin permissions have been revoked"
**Fix:**
1. Reconnect Garmin account in the app
2. Re-authorize permissions

---

### Issue 3: "Backfill request pending for X hours"
**Possible Causes:**
- Webhooks not arriving
- Garmin not processing the request
- Network issues

**Fix:**
1. Check Supabase Edge Function logs
2. Verify webhook URLs in Garmin Developer Portal
3. Check if Garmin is sending webhooks (look for PING/PUSH invocations)

---

### Issue 4: "No Garmin connection found"
**Fix:**
1. Connect your Garmin account in the app
2. Complete OAuth flow

---

## Next Steps After Diagnosis

### If Webhooks Are Not Configured:
1. Go to Garmin Developer Portal
2. Navigate to Endpoint Configuration
3. Add webhook URLs:
   - Activity PING: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-ping`
   - Activity PUSH: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push`
   - Health: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-health-webhook`
4. Enable webhooks (not "on hold")

### If Webhooks Are Configured But Not Arriving:
1. Check Supabase Edge Function logs
2. Look for webhook invocations in logs
3. Verify webhook URLs are correct
4. Test webhook endpoint manually (send test request)

### If Activities Are Being Filtered:
1. Check activity types in Garmin Connect
2. Only Running/Hiking/Walking activities are stored
3. If you need other types, update filter in edge functions

---

## Expected Behavior

**When Everything Works:**
- Activities automatically sync when created in Garmin Connect
- No manual "Sync with Device" needed
- Activities appear in database within minutes
- Status checker shows recent activities

**When There Are Issues:**
- Status checker identifies the problem
- Provides specific recommendations
- Points to logs or configuration to check

---

## Summary

The webhook status checker is a diagnostic tool that helps you understand why activities aren't syncing automatically. Use it when:
- Activities aren't appearing in the app
- You want to verify webhook configuration
- You need to troubleshoot sync issues

**Remember:** Activities should sync automatically via webhooks. The "Check Sync Status" button is for diagnostics, not for manual syncing.

