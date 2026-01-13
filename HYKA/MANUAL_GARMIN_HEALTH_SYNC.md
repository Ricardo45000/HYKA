# Manual Garmin Health Sync Guide

## ✅ Yes, You Can Manually Trigger Health Sync!

There are **3 ways** to manually sync your Garmin health data:

---

## Method 1: Via Supabase Dashboard (Easiest)

### Steps:

1. **Go to Supabase Dashboard**:
   - [Edge Functions → garmin-health-sync](https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions/garmin-health-sync)

2. **Click "Invoke Function"**

3. **Send this JSON body**:
```json
{
  "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
  "days_back": 1
}
```

4. **Click "Invoke"**

5. **Check the response** - Should see:
```json
{
  "success": true,
  "results": {
    "dailies": { "status": 202, "message": "Backfill accepted" },
    "sleeps": { "status": 202, "message": "Backfill accepted" },
    ...
  }
}
```

6. **Wait 1-10 minutes** - Garmin will send webhooks with the data

---

## Method 2: Via Terminal Script

### Using the Script I Created:

```bash
# Set your Supabase anon key (get from Supabase Dashboard → Settings → API)
export SUPABASE_ANON_KEY='your_anon_key_here'

# Run the sync script
./sync_garmin_health_now.sh fc600af9-2926-4b86-b841-25a25d17c10c 1
```

**Parameters:**
- First parameter: Your user ID (`fc600af9-2926-4b86-b841-25a25d17c10c`)
- Second parameter: Days back (default: 1, use `30` for last month)

---

## Method 3: Via curl Command

```bash
curl -X POST \
  "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-sync" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
    "days_back": 1
  }'
```

**Get your Supabase Anon Key:**
- Go to: [Supabase Dashboard → Settings → API](https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/settings/api)
- Copy the `anon` `public` key

---

## Method 4: From iOS App (Future Enhancement)

Currently, the app doesn't have a "Sync Now" button, but you could add one! The sync would call the same `garmin-health-sync` Edge Function.

---

## What Happens When You Sync?

1. **Function requests backfill** from Garmin API
2. **Garmin returns 202 Accepted** (queued)
3. **Garmin processes the request** (1-5 minutes)
4. **Garmin sends webhooks** to `garmin-health-webhook`
5. **Webhook function stores data** in `garmin_health_metrics` table
6. **Data appears in Supabase** ✅

---

## How to Verify Data Arrived

### Check Database:

Run this SQL in Supabase SQL Editor:

```sql
SELECT 
    metric_date,
    steps,
    active_calories,
    resting_heart_rate,
    sleep_duration_seconds,
    sleep_score,
    updated_at
FROM garmin_health_metrics
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
ORDER BY updated_at DESC
LIMIT 10;
```

### Check Webhook Logs:

1. Go to: [Edge Functions → garmin-health-webhook → Logs](https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions/garmin-health-webhook/logs)
2. Look for: `🏥 Garmin Health Webhook received`
3. Should see logs within 1-10 minutes after sync

---

## When to Use Manual Sync

✅ **Use manual sync when:**
- First-time setup (pull last 30 days)
- After reconnecting Garmin account
- If webhooks missed some data
- Testing/debugging
- Want to force a sync right now

❌ **Don't need manual sync for:**
- Daily automatic syncing (webhooks handle this)
- Real-time data (webhooks are automatic)

---

## Sync Parameters

### `days_back` Parameter:

- **`1`**: Last 24 hours (fastest, good for testing)
- **`7`**: Last week
- **`30`**: Last month (good for first-time setup)
- **`90`**: Last 3 months (slower, more data)

**Note**: Larger `days_back` values take longer to process and may trigger more webhooks.

---

## Troubleshooting

### Issue: "Token refresh failed"

**Solution**: Reconnect your Garmin account in the app:
1. Profile → Connect with your wearables
2. Disconnect Garmin
3. Reconnect Garmin

### Issue: "No Garmin connection found"

**Solution**: Make sure you've connected Garmin in the app first.

### Issue: Sync succeeds but no data appears

**Check:**
1. Wait 5-10 minutes (Garmin needs time to send webhooks)
2. Check webhook logs for errors
3. Verify `garmin_user_id` is saved in `garmin_connections` table

---

## Quick Reference

**Your User ID**: `fc600af9-2926-4b86-b841-25a25d17c10c`

**Sync Function URL**: 
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-sync
```

**Webhook Function URL**:
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook
```

---

## Next Steps

1. **Try Method 1** (Supabase Dashboard) - Easiest way to test
2. **Wait 5-10 minutes** for webhooks to arrive
3. **Check database** to verify data appeared
4. **Set up automatic webhooks** in Garmin Developer Portal for ongoing syncing
