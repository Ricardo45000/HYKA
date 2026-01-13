# Garmin Webhook Flow - How Health Data Arrives

## 🔄 Automatic Webhook Flow (Real-Time)

### When Garmin Syncs:

1. **Your Garmin watch syncs** with Garmin Connect (via phone app or computer)
2. **Garmin processes the data** (steps, sleep, heart rate, etc.)
3. **Garmin sends webhooks** to your `garmin-health-webhook` endpoint
4. **Webhook function receives data** and stores it in `garmin_health_metrics` table
5. **Data appears in Supabase** automatically - no manual action needed!

### What Triggers Webhooks:

✅ **Daily Health Metrics** (dailies)
- Steps, calories, heart rate
- Triggered: After watch sync, usually once per day

✅ **Sleep Data** (sleeps)
- Sleep duration, stages, score
- Triggered: After sleep tracking completes

✅ **Stress Details** (stressDetails)
- Stress levels throughout the day
- Triggered: Periodically during the day

✅ **Body Composition** (bodyComposition)
- Body fat, BMI, weight
- Triggered: When you sync a scale or manually enter data

✅ **User Metrics** (userMetrics)
- VO2 Max, Fitness Age
- Triggered: When these metrics are updated (usually weekly/monthly)

✅ **Health Snapshot** (healthSnapshot)
- Overall health summary
- Triggered: Periodically

### Timeline:

- **Watch Sync** → Garmin Connect (immediate)
- **Garmin Processing** → 1-5 minutes
- **Webhook Sent** → 1-10 minutes after sync
- **Data in Supabase** → Immediately after webhook received

---

## 🔧 Manual Sync (On-Demand)

The `garmin-health-sync` function is for **manual backfills** or when you want to pull historical data:

### When to Use Manual Sync:

- ✅ First-time setup (pull last 30 days of data)
- ✅ After reconnecting Garmin account
- ✅ If webhooks missed some data
- ✅ Testing/debugging

### How Manual Sync Works:

1. You call `garmin-health-sync` Edge Function
2. Function requests backfill from Garmin API
3. Garmin returns **202 Accepted** (queued)
4. Garmin then sends webhooks with the requested data
5. Webhooks are processed by `garmin-health-webhook`
6. Data stored in Supabase

**Note**: Even manual syncs trigger webhooks! The backfill API just tells Garmin "send me data for these dates" and Garmin sends it via webhooks.

---

## 📊 Data Flow Diagram

```
┌─────────────┐
│ Garmin Watch│
│   (Sync)    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Garmin Connect  │
│   (Processes)   │
└──────┬──────────┘
       │
       │ (Automatic Webhook)
       ▼
┌─────────────────────────────┐
│ garmin-health-webhook       │
│ (Supabase Edge Function)    │
└──────┬──────────────────────┘
       │
       │ (Stores Data)
       ▼
┌─────────────────────────────┐
│ garmin_health_metrics       │
│ (Supabase Table)            │
└─────────────────────────────┘
```

---

## ✅ Summary

**Automatic (Real-Time)**:
- ✅ Watch syncs → Webhooks sent → Data in Supabase
- ✅ No manual action needed
- ✅ Happens every time your watch syncs
- ✅ Usually 1-10 minutes after sync

**Manual (On-Demand)**:
- ✅ Call `garmin-health-sync` function
- ✅ Requests historical data
- ✅ Garmin sends webhooks with requested data
- ✅ Use for backfills or first-time setup

---

## 🔍 How to Verify It's Working

### Check Webhook Logs:
1. Go to: [Supabase Dashboard → Edge Functions → garmin-health-webhook → Logs](https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions/garmin-health-webhook/logs)
2. Look for: `🏥 Garmin Health Webhook received`
3. Should see logs after each watch sync

### Check Database:
```sql
SELECT 
    metric_date,
    steps,
    active_calories,
    resting_heart_rate,
    sleep_duration_seconds,
    updated_at
FROM garmin_health_metrics
WHERE user_id = 'your-user-id'
ORDER BY updated_at DESC
LIMIT 10;
```

### Expected Frequency:
- **Daily metrics**: Once per day (after morning sync)
- **Sleep data**: Once per day (after sleep tracking)
- **Stress data**: Multiple times per day
- **User metrics**: Weekly/monthly (when updated)

---

## ⚠️ Troubleshooting

### No Webhooks Arriving?

1. **Check Garmin Developer Portal**:
   - Webhooks enabled for your app?
   - Webhook URL correct? (`https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook`)

2. **Check `garmin_user_id`**:
   - Must be saved in `garmin_connections` table
   - Webhooks match by `garmin_user_id`
   - If NULL, reconnect Garmin account

3. **Check Function Logs**:
   - Are webhooks arriving but failing?
   - Look for error messages

4. **Verify Watch Sync**:
   - Is your watch actually syncing?
   - Check Garmin Connect app for recent syncs

---

## 🎯 Best Practices

1. **Let webhooks handle real-time data** - Don't manually sync daily
2. **Use manual sync only for**:
   - First-time setup
   - After reconnecting account
   - Debugging missing data
3. **Monitor webhook logs** - Check weekly to ensure they're arriving
4. **Keep `garmin_user_id` saved** - Critical for webhook matching
