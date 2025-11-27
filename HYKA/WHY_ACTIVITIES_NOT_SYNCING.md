# Why Activities Aren't Automatically Syncing to Supabase

## Expected Behavior

**Activities SHOULD sync automatically when:**
1. User creates/upload activity in Garmin Connect
2. Garmin sends webhook (PING or PUSH) to your edge function
3. Edge function processes and stores in Supabase
4. Activities appear in database immediately

**"Sync with Device" button SHOULD NOT be needed** for new activities - only for historical data.

---

## Why Activities Might Not Be Syncing

### 1. **Webhooks Not Configured in Garmin Developer Portal**

**Check:**
- Go to Garmin Developer Portal → Endpoint Configuration
- Verify webhook URLs are correct:
  - Activity PING: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-ping`
  - Activity PUSH: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push`
- Verify webhooks are **enabled** (not "on hold")
- Verify webhook type is correct (PING vs PUSH)

**Fix:**
- Configure webhooks in Garmin Developer Portal
- Use PUSH webhooks for faster delivery (data included, no fetch needed)

---

### 2. **Webhooks Not Being Received**

**Check Supabase Logs:**
- Go to Supabase Dashboard → Edge Functions → Logs
- Check `garmin-activity-ping` or `garmin-activity-push` logs
- Look for:
  - "📦 Garmin PUSH received" or "🔔 Garmin PING received"
  - Any errors in processing

**If no webhooks received:**
- Webhook URLs might be wrong
- Garmin might not be sending webhooks
- Network/firewall blocking webhooks

**Fix:**
- Verify webhook URLs in Garmin Developer Portal
- Test webhook endpoint manually (send test request)
- Check Supabase function logs for errors

---

### 3. **Activities Being Filtered Out**

**Current Filter:**
- Only Running/Hiking/Walking activities are stored
- Other types (Cycling, Swimming, etc.) are filtered out

**Check:**
- Look at webhook logs: "⏭️ Skipping activity type: Cycling"
- Verify activity type in Garmin Connect matches filter

**Fix:**
- If you need other activity types, update filter in:
  - `garmin-activity-push/index.ts`
  - `garmin-activity-pull/index.ts`

---

### 4. **Webhook Processing Errors**

**Common Issues:**
- Missing `garminUserId` in webhook payload
- Missing `callbackUrl` in PING webhooks
- Token expiration (should auto-refresh)
- Database errors (RLS policies, missing tables)

**Check:**
- Look for error logs in edge function logs
- Check for "❌ Missing garminUserId" or "❌ Missing callbackUrl"
- Verify `garmin_connections` table has valid tokens

**Fix:**
- Check edge function logs for specific errors
- Verify database schema and RLS policies
- Ensure tokens are valid (check expiration)

---

### 5. **Webhook Handler Not Forwarding to Store**

**Flow Check:**
- PING → `garmin-activity-ping` → `garmin-activity-pull` → `garmin-activity-store`
- PUSH → `garmin-activity-push` → `garmin-activity-store`

**Check:**
- Verify `garmin-activity-store` is being called
- Check logs for "💾 Garmin Activity Store started"
- Verify store function is storing data successfully

**Fix:**
- Check edge function logs for store function calls
- Verify store function is working (test manually)

---

### 6. **Database Storage Issues**

**Check:**
- Verify `garmin_activities` table exists
- Check RLS policies allow inserts
- Verify `garmin_user_id` matches between webhook and connection

**Fix:**
- Check database schema
- Verify RLS policies
- Check for foreign key constraints

---

## Diagnostic Steps

### Step 1: Check Webhook Configuration
```bash
# In Garmin Developer Portal, verify:
- Webhook URLs are correct
- Webhooks are enabled (not "on hold")
- Webhook type matches (PING vs PUSH)
```

### Step 2: Check Supabase Logs
```bash
# In Supabase Dashboard:
1. Go to Edge Functions → Logs
2. Filter by: garmin-activity-ping OR garmin-activity-push
3. Look for recent webhook invocations
4. Check for errors
```

### Step 3: Test Webhook Manually
```bash
# Send test webhook to verify endpoint works
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-id",
    "activities": [{
      "summaryId": "12345",
      "activityType": "Running",
      "startTimeInSeconds": 1234567890
    }]
  }'
```

### Step 4: Check Database
```sql
-- Check if activities are in database
SELECT COUNT(*) FROM garmin_activities WHERE user_id = 'YOUR_USER_ID';

-- Check recent activities
SELECT * FROM garmin_activities 
WHERE user_id = 'YOUR_USER_ID' 
ORDER BY start_time_seconds DESC 
LIMIT 10;

-- Check webhook invocations (if logged)
SELECT * FROM garmin_backfill_requests 
WHERE user_id = 'YOUR_USER_ID' 
ORDER BY created_at DESC;
```

### Step 5: Verify Activity Types
```sql
-- Check what activity types are in Garmin Connect
-- (This requires checking Garmin Connect directly or webhook logs)

-- In webhook logs, look for:
-- "Activity types received: [Running, Cycling, ...]"
-- "⏭️ Skipping activity type: Cycling"
```

---

## Most Likely Issues

### 1. **Webhooks Not Configured**
- Webhook URLs not set in Garmin Developer Portal
- Webhooks disabled or "on hold"

### 2. **Webhooks Not Being Received**
- Wrong URLs
- Network issues
- Garmin not sending webhooks

### 3. **Activities Filtered Out**
- Activity type not Running/Hiking/Walking
- Filter too restrictive

### 4. **Webhook Processing Errors**
- Missing required fields
- Token issues
- Database errors

---

## Solution: Remove "Sync with Device" Dependency

**The app should work like this:**

1. **User connects Garmin** → OAuth flow → Webhooks configured
2. **User creates activity in Garmin Connect** → Webhook sent automatically
3. **Activity appears in Supabase** → App reads from Supabase
4. **No manual sync needed** for new activities

**"Sync with Device" should only be for:**
- Initial historical data (first connection)
- Manual refresh of recent activities (if webhooks delayed)
- Troubleshooting (checking sync status)

---

## Next Steps

1. **Verify webhook configuration** in Garmin Developer Portal
2. **Check Supabase logs** for webhook invocations
3. **Test webhook manually** to verify endpoint works
4. **Check activity types** - ensure they match filter
5. **Remove "Sync with Device" button** or make it optional
6. **Add webhook status indicator** in app (showing last sync time)

