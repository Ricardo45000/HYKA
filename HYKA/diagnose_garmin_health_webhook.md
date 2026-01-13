# Diagnose Garmin Health Webhook - No Logs Issue

## Problem
Webhooks are registered in Garmin Developer Portal, but no logs appear when watch syncs.

## Most Likely Causes

### 1. Garmin Doesn't Send Webhooks for Every Sync ⚠️ **MOST COMMON**

**Garmin only sends health webhooks when health data CHANGES**, not for every sync:
- If your watch synced but no new health metrics were recorded → **No webhook sent**
- Health webhooks are **event-driven**, not sync-driven
- **Solution**: Wait for actual health events (new sleep session, new daily summary, etc.)

### 2. Health Data Comes Via Activity Webhook

Garmin may send health data (`dailies`) bundled with activity webhooks instead of dedicated health webhooks.

**Check**: Supabase Dashboard → Edge Functions → `garmin-activity-push` → Logs
- Look for: `🏥 Processing Health Data: dailies`
- If you see this, health data is coming through activity webhook, not health webhook

### 3. Webhook Delay

Garmin may delay health webhooks:
- Not real-time (can be minutes or hours after sync)
- Health data is processed in batches
- **Solution**: Wait 1-2 hours after sync, then check logs

### 4. Garmin User ID Mismatch

The webhook receives a Garmin user ID but can't find a match in your database.

**Diagnosis Steps**:
1. Check Supabase logs for: `⚠️ No HYKA user found for Garmin user: <id>`
2. Query your database:
   ```sql
   SELECT user_id, garmin_user_id FROM garmin_connections;
   ```
3. Verify `garmin_user_id` is not NULL
4. If NULL, the OAuth connection didn't fetch/save the Garmin user ID

**Fix**: Reconnect Garmin account to ensure `garmin_user_id` is saved

### 5. Webhook Not Actually Being Called

Even though registered, Garmin might not be sending webhooks due to:
- Webhook URL not verified/activated
- Garmin requires webhook verification first
- Network/firewall blocking Garmin's servers

**Diagnosis**: 
- Check if ANY logs exist in `garmin-health-webhook` (even empty/test requests)
- If zero logs = Garmin is not calling the endpoint at all

## Immediate Solutions

### Solution 1: Manual Health Sync (Get Today's Data Now)

Use the manual sync to get today's health data immediately:

```bash
# Via Supabase Dashboard
# Edge Functions → garmin-health-sync → Invoke with:
{
  "user_id": "YOUR_USER_UUID",
  "days_back": 1
}
```

### Solution 2: Check Activity Webhook Logs

Health data might be coming through `garmin-activity-push`:
- Check logs for that function
- Look for `dailies` in the payload

### Solution 3: Verify Garmin User ID

1. Check if `garmin_user_id` exists in `garmin_connections`:
   ```sql
   SELECT user_id, garmin_user_id FROM garmin_connections WHERE user_id = 'YOUR_USER_UUID';
   ```
2. If `garmin_user_id` is NULL, reconnect Garmin to fetch it

## Testing

Run the test script:
```bash
./test_garmin_health_webhook.sh
```

This will:
- Test if the webhook endpoint is accessible
- Send a test payload
- Provide diagnostic steps

## Expected Behavior

**Normal Flow**:
1. Watch syncs → Garmin processes health data
2. **IF** new health metrics exist → Garmin sends webhook
3. Webhook arrives → Logs show: `🏥 Garmin Health Webhook received`
4. Data stored in `garmin_health_metrics` table

**If No Webhook**:
- No new health data was recorded during sync
- OR health data comes via activity webhook
- OR webhook is delayed (check logs later)

## Next Steps

1. **Immediate**: Use manual sync to get today's data
2. **Short-term**: Check `garmin-activity-push` logs for health data
3. **Long-term**: Monitor logs over 24 hours to see when webhooks actually arrive
4. **Verify**: Ensure `garmin_user_id` is saved in database
