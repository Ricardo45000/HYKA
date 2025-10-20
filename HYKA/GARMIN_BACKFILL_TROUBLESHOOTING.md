# Garmin Backfill Troubleshooting Guide

## Why You Don't Have Historical Data

The Garmin backfill process is **asynchronous** and involves multiple steps. Here's how to diagnose why data isn't appearing:

---

## Step 1: Check if Backfill Requests Were Sent

### Check `garmin_backfill_requests` table in Supabase:

```sql
SELECT 
  id,
  user_id,
  summary_start_time_seconds,
  summary_end_time_seconds,
  status,
  created_at,
  completed_at
FROM garmin_backfill_requests
WHERE user_id = 'YOUR_USER_ID'
ORDER BY created_at DESC;
```

**Expected Results:**
- ✅ **Status = 'pending'**: Request was sent to Garmin, waiting for processing
- ✅ **Status = 'completed'**: Activities were received via webhooks
- ❌ **Status = 'failed'**: Request failed (check logs)
- ❌ **No rows**: Backfill requests weren't sent

---

## Step 2: Verify Webhook Configuration

**Critical**: Garmin can only send webhooks if the webhook URLs are configured in the Garmin Developer Portal.

### Required Webhook URLs:

1. **Activity PING Webhook**:
   ```
   https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
   ```

2. **Activity PUSH Webhook** (optional, but recommended):
   ```
   https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push
   ```

3. **Permission Webhook** (for permission changes):
   ```
   https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook
   ```

### How to Configure:

1. Go to [Garmin Developer Portal](https://developerportal.garmin.com/)
2. Navigate to your app → **Endpoint Configuration**
3. Add the webhook URLs above
4. Save and wait for Garmin to verify (can take a few minutes)

**⚠️ Without webhooks configured, Garmin cannot send activity data!**

---

## Step 3: Check if Webhooks Are Being Received

### Check Supabase Edge Function Logs:

1. Go to Supabase Dashboard → **Edge Functions** → **Logs**
2. Check logs for:
   - `garmin-activity-ping` - Should show "🔔 Garmin PING received"
   - `garmin-activity-pull` - Should show "📥 Garmin Activity Pull started"
   - `garmin-activity-store` - Should show "💾 Storing activity..."

**If you see no webhook logs:**
- Webhooks are not configured in Garmin Developer Portal
- OR Garmin hasn't processed the backfill requests yet

---

## Step 4: Check if Activities Are Being Stored

### Check `garmin_activities` table:

```sql
SELECT 
  id,
  user_id,
  activity_name,
  activity_type,
  start_time,
  created_at
FROM garmin_activities
WHERE user_id = 'YOUR_USER_ID'
ORDER BY start_time DESC
LIMIT 10;
```

**If table is empty:**
- Activities haven't been received via webhooks yet
- OR webhook processing failed (check logs)

---

## Step 5: Understanding the Backfill Timeline

**Important**: Garmin backfill is **asynchronous** and can take time:

1. **Backfill Request Sent** (immediate)
   - Your app calls `garmin-activity-backfill`
   - Garmin returns `202 Accepted`
   - Status: `pending` in `garmin_backfill_requests`

2. **Garmin Processing** (can take minutes to hours)
   - Garmin processes the backfill request
   - Finds activities in the date range
   - Prepares webhook notifications

3. **Webhooks Sent** (when ready)
   - Garmin sends PING webhooks for each activity
   - Your Edge Functions receive and process them
   - Activities are stored in `garmin_activities`

4. **Data Available** (after webhooks processed)
   - Activities appear in `garmin_activities` table
   - iOS app can fetch and display them

**Typical Timeline:**
- Small date ranges (1-7 days): 5-15 minutes
- Medium date ranges (30 days): 15-60 minutes
- Large date ranges (90 days): 1-3 hours

---

## Step 6: Manual Verification

### Test if Webhooks Are Working:

1. **Create a new activity** in Garmin Connect (sync your watch)
2. **Check logs** for `garmin-activity-ping` - should receive webhook within 1-2 minutes
3. **Check `garmin_activities`** table - new activity should appear

**If new activities work but backfill doesn't:**
- Backfill requests may not have been accepted by Garmin
- OR Garmin is still processing the backfill requests

---

## Step 7: Common Issues and Solutions

### Issue 1: "Connection array is empty"
**Solution**: Use Supabase client instead of REST API (already fixed in code)

### Issue 2: "Date range exceeds 30 days"
**Solution**: Use 29-day chunks (already fixed in code)

### Issue 3: "Start time before connection date"
**Solution**: Calculate dates forward from connection date (already fixed in code)

### Issue 4: No webhooks received
**Solution**: 
- Verify webhook URLs are configured in Garmin Developer Portal
- Check that webhook URLs are publicly accessible (no auth required)
- Wait for Garmin to process backfill requests (can take time)

### Issue 5: Webhooks received but no activities stored
**Solution**: 
- Check `garmin-activity-pull` logs for errors
- Check `garmin-activity-store` logs for errors
- Verify access_token is valid (not expired)

---

## Step 8: Force Re-sync

If backfill isn't working, you can:

1. **Delete old backfill requests** (to allow re-requesting):
   ```sql
   DELETE FROM garmin_backfill_requests
   WHERE user_id = 'YOUR_USER_ID' AND status = 'failed';
   ```

2. **Re-trigger backfill** from iOS app:
   - Click "Sync with Garmin" button
   - This will send new backfill requests

3. **Check logs** to see if requests are accepted (202 status)

---

## Quick Diagnostic Checklist

- [ ] Backfill requests exist in `garmin_backfill_requests` table
- [ ] Backfill requests have status = 'pending' (not 'failed')
- [ ] Webhook URLs are configured in Garmin Developer Portal
- [ ] Webhook URLs are publicly accessible (test with curl)
- [ ] Edge Function logs show webhook activity
- [ ] Activities exist in `garmin_activities` table
- [ ] Access token is valid (not expired)

---

## Next Steps

1. **Check `garmin_backfill_requests` table** - Are requests pending?
2. **Verify webhook configuration** - Are URLs set in Garmin Developer Portal?
3. **Check Edge Function logs** - Are webhooks being received?
4. **Wait for processing** - Garmin backfill can take time (especially for large date ranges)

If all checks pass but data still isn't appearing, the issue is likely:
- Garmin is still processing the backfill requests (wait longer)
- OR webhook URLs are not correctly configured in Garmin Developer Portal

