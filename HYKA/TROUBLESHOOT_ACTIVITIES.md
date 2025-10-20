# Troubleshoot: Activities Not Appearing in Supabase

## Quick Diagnostic

Run this SQL query in Supabase SQL Editor:

```sql
-- Check everything at once
SELECT 
  'Connections' as check_type,
  COUNT(*) as count
FROM garmin_connections
UNION ALL
SELECT 
  'Activities' as check_type,
  COUNT(*) as count
FROM garmin_activities
UNION ALL
SELECT 
  'Samples' as check_type,
  COUNT(*) as count
FROM garmin_activity_samples;
```

---

## Common Issues & Fixes

### Issue 1: No Connection in Database

**Symptom:** `garmin_connections` table is empty

**Check:**
```sql
SELECT * FROM garmin_connections;
```

**Fix:**
1. Ensure OAuth flow completed successfully
2. Check if iOS app stores connection after token exchange
3. Verify `garmin_user_id` is fetched from `/rest/user/id` endpoint
4. Check iOS app logs for connection storage errors

---

### Issue 2: Connection Exists But No Activities

**Symptom:** Connection exists but `garmin_activities` is empty

**Check:**
```sql
SELECT 
  gc.user_id,
  gc.garmin_user_id,
  gc.last_sync_at,
  COUNT(ga.id) as activity_count
FROM garmin_connections gc
LEFT JOIN garmin_activities ga ON ga.user_id = gc.user_id
GROUP BY gc.id;
```

**Possible Causes:**

#### A. Webhook Not Receiving Requests (401 Error)
- **Check:** Supabase Edge Functions → `garmin-activity-ping` → Logs
- **Fix:** Update webhook URL in Garmin Developer Portal:
  ```
  https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY
  ```

#### B. Webhook Receiving But Not Processing
- **Check:** Look for `🔔 Garmin PING received` in logs
- **Check:** Look for `⚠️ No garminUserId provided` or `⚠️ No HYKA user found`
- **Fix:** Ensure `garmin_user_id` is stored correctly in `garmin_connections`

#### C. Pull Function Failing
- **Check:** Edge Functions → `garmin-activity-pull` → Logs
- **Look for:** `❌ Summary fetch failed` or `❌ Store function failed`
- **Fix:** Check Pull Token is valid (expires every 24h)

#### D. Store Function Failing
- **Check:** Edge Functions → `garmin-activity-store` → Logs
- **Look for:** `⚠️ No HYKA user found for Garmin user: <id>`
- **Fix:** Ensure `garmin_user_id` matches between connection and webhook

---

### Issue 3: Activities Stored But Not Visible

**Symptom:** Activities in `garmin_activities` but not in `unified_activities` view

**Check:**
```sql
-- Compare counts
SELECT 
  'garmin_activities' as source,
  COUNT(*) as count
FROM garmin_activities
UNION ALL
SELECT 
  'unified_activities (Garmin)' as source,
  COUNT(*) as count
FROM unified_activities
WHERE source_table = 'garmin_activities';
```

**Fix:**
1. Check `unified_activities` view definition
2. Verify RLS policies allow access
3. Check if view needs to be refreshed

---

### Issue 4: Wrong garmin_user_id

**Symptom:** Webhook has different `userId` than stored in `garmin_connections`

**Check:**
```sql
SELECT garmin_user_id FROM garmin_connections;
```

**Then check webhook logs:**
- Look for `Garmin User ID:` in `garmin-activity-ping` logs
- Compare with database value

**Fix:**
1. Re-authenticate with Garmin
2. Ensure `/rest/user/id` endpoint is called during OAuth
3. Verify `garmin_user_id` is stored correctly

---

## Step-by-Step Debugging

### Step 1: Check Webhook is Configured

1. Go to Garmin Developer Portal
2. Check webhook URL includes anon key:
   ```
   https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY
   ```
3. Verify webhook is enabled

### Step 2: Check Connection Exists

```sql
SELECT 
  user_id,
  garmin_user_id,
  created_at,
  last_sync_at
FROM garmin_connections;
```

**If empty:**
- OAuth flow didn't complete
- iOS app didn't store connection
- Check iOS app logs

### Step 3: Trigger Test Activity

1. Upload a test activity to Garmin Connect
2. Wait 1-2 minutes
3. Check Supabase Edge Function logs

### Step 4: Check Logs in Order

1. **`garmin-activity-ping`** logs:
   - Should see: `🔔 Garmin PING received`
   - Should see: `Garmin User ID: <id>`
   - Should return: `200 OK`

2. **`garmin-activity-pull`** logs:
   - Should see: `📥 Garmin Activity Pull started`
   - Should see: `✅ Summary fetched`
   - Should see: `✅ Store function completed`

3. **`garmin-activity-store`** logs:
   - Should see: `💾 Garmin Activity Store started`
   - Should see: `✅ Found HYKA user: <user_id>`
   - Should see: `✅ Activity stored with ID: <id>`

### Step 5: Check Database

```sql
SELECT 
  garmin_activity_id,
  activity_name,
  activity_type,
  start_time,
  created_at
FROM garmin_activities
ORDER BY created_at DESC
LIMIT 5;
```

---

## Manual Test

Test the webhook manually:

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin Health API" \
  -d '{
    "summaryId": "12345",
    "userId": "YOUR_GARMIN_USER_ID",
    "callbackUrl": "https://apis.garmin.com/wellness-api/rest/activityDetails/12345?token=PULL_TOKEN"
  }'
```

**Replace:**
- `YOUR_ANON_KEY` - from Supabase Dashboard
- `YOUR_GARMIN_USER_ID` - from `garmin_connections` table
- `PULL_TOKEN` - current Pull Token from Garmin Developer Portal

**Expected:** 200 OK response

---

## Most Likely Issues

Based on your setup, the most likely issues are:

1. **Webhook URL missing anon key** (401 error) - ✅ Fixed in code, need to update Garmin portal
2. **garmin_user_id not stored** - Check if iOS app stores it after OAuth
3. **garmin_user_id mismatch** - Webhook sends different ID than stored
4. **Pull Token expired** - Update in `app_config` table

---

## Next Steps

1. ✅ Run `check_garmin_activities.sql` to see current state
2. ✅ Check Supabase Edge Function logs for errors
3. ✅ Update webhook URL in Garmin Developer Portal with anon key
4. ✅ Verify `garmin_user_id` is stored in `garmin_connections`
5. ✅ Upload test activity and monitor logs

