# Debug: Activities Not Appearing in Supabase

## Checklist

### 1. Check Webhook is Receiving Requests

**Check Supabase Logs:**
- Go to Supabase Dashboard → Edge Functions → `garmin-activity-ping` → Logs
- Look for: `🔔 Garmin PING received`
- Should see 200 OK (not 401)

**If 401:**
- Update webhook URL in Garmin Developer Portal to include `?apikey=YOUR_ANON_KEY`

### 2. Check Pull Function is Called

**Check Logs:**
- Edge Functions → `garmin-activity-pull` → Logs
- Look for: `🔄 Pulling activity from Garmin...`
- Should see activity data being fetched

**If empty:**
- Check if `callbackUrl` is being passed correctly
- Verify Pull Token is valid (expires every 24h)

### 3. Check Store Function is Called

**Check Logs:**
- Edge Functions → `garmin-activity-store` → Logs
- Look for: `💾 Garmin Activity Store started`
- Should see: `✅ Found HYKA user: <user_id>`
- Should see: `✅ Activity stored: <activity_id>`

**Common Issues:**

#### Issue A: "No HYKA user found for Garmin user"
**Cause:** `garmin_user_id` not stored in `garmin_connections` table

**Fix:**
1. Check `garmin_connections` table in Supabase
2. Verify `garmin_user_id` was stored during OAuth
3. Check `garmin-token-exchange` function stored it correctly

#### Issue B: "No garminUserId provided"
**Cause:** PING webhook doesn't include `userId`

**Fix:**
1. Check Garmin webhook payload
2. Update `garmin-activity-ping` to extract `userId` from callbackUrl or body

#### Issue C: Activity stored but not visible
**Cause:** RLS (Row Level Security) blocking access

**Fix:**
1. Check RLS policies are correct
2. Verify service role key is used in store function
3. Check `unified_activities` view includes Garmin activities

### 4. Check Database Tables

**Run in Supabase SQL Editor:**

```sql
-- Check if tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('garmin_activities', 'garmin_activity_samples', 'garmin_connections');

-- Check if activities exist
SELECT COUNT(*) FROM garmin_activities;

-- Check if connection exists
SELECT user_id, garmin_user_id, created_at 
FROM garmin_connections;

-- Check unified view
SELECT COUNT(*) FROM unified_activities WHERE source_table = 'garmin_activities';
```

### 5. Check RLS Policies

**Verify policies exist:**

```sql
-- Check policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename IN ('garmin_activities', 'garmin_activity_samples', 'garmin_connections');
```

**Should see:**
- `Service role full access to garmin_activities`
- `Service role full access to garmin_activity_samples`
- `Users can view own garmin activities`

### 6. Test End-to-End Flow

**Manual Test:**

1. **Trigger webhook manually:**
```bash
curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY \
  -H "Content-Type: application/json" \
  -H "User-Agent: Garmin Health API" \
  -d '{
    "summaryId": "12345",
    "userId": "YOUR_GARMIN_USER_ID",
    "callbackUrl": "https://apis.garmin.com/wellness-api/rest/activityDetails/12345?token=PULL_TOKEN"
  }'
```

2. **Check logs** for each function in sequence:
   - `garmin-activity-ping` → should forward to pull
   - `garmin-activity-pull` → should fetch activity
   - `garmin-activity-store` → should store in DB

3. **Check database:**
```sql
SELECT * FROM garmin_activities ORDER BY created_at DESC LIMIT 5;
```

---

## Quick Fixes

### Fix 1: Ensure garmin_user_id is Stored

**Check `garmin-token-exchange` function:**
- Should store `garmin_user_id` in `garmin_connections` table
- Should call `/rest/user/id` endpoint to get Garmin user ID

### Fix 2: Update Webhook URL

**In Garmin Developer Portal:**
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY
```

### Fix 3: Verify Pull Token

**Check `app_config` table:**
```sql
SELECT value FROM app_config WHERE key = 'garmin_pull_token';
```

**Update if expired:**
```sql
SELECT update_garmin_pull_token('NEW_TOKEN_HERE');
```

---

## Expected Flow

1. ✅ User uploads activity to Garmin Connect
2. ✅ Garmin sends PING to `garmin-activity-ping` (200 OK)
3. ✅ PING forwards to `garmin-activity-pull` with callbackUrl
4. ✅ Pull function fetches activity from Garmin API
5. ✅ Pull function calls `garmin-activity-store` with data
6. ✅ Store function finds user from `garmin_user_id`
7. ✅ Store function inserts into `garmin_activities` table
8. ✅ Activity appears in `unified_activities` view
9. ✅ iOS app queries `unified_activities` view

---

## Debug Commands

**Check recent activities:**
```sql
SELECT 
  garmin_activity_id,
  activity_name,
  activity_type,
  start_time,
  distance_meters,
  created_at
FROM garmin_activities
ORDER BY created_at DESC
LIMIT 10;
```

**Check connection:**
```sql
SELECT 
  gc.user_id,
  gc.garmin_user_id,
  gc.created_at,
  COUNT(ga.id) as activity_count
FROM garmin_connections gc
LEFT JOIN garmin_activities ga ON ga.user_id = gc.user_id
GROUP BY gc.id;
```

**Check webhook logs:**
- Supabase Dashboard → Edge Functions → Logs
- Filter by function name
- Look for errors or warnings

