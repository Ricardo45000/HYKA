# Strava Webhook Limitations & Troubleshooting

## ⚠️ Important: Why Your Friend's Activity Didn't Trigger

**Strava webhooks only trigger for activities created by users who have connected their Strava account to your app.**

### How It Works:

1. **User connects Strava to HYKA** → Their `strava_athlete_id` is stored in `strava_connections` table
2. **User creates an activity on Strava** → Strava sends a webhook to your endpoint
3. **Webhook looks up the connection** → Finds the user by matching `owner_id` (from webhook) with `strava_athlete_id` (in database)
4. **Activity is stored** → Activity is saved and notification is sent

### Why Your Friend's Activity Didn't Trigger:

- ❌ Your friend hasn't connected their Strava account to HYKA
- ❌ No connection record exists in `strava_connections` for your friend's `strava_athlete_id`
- ❌ The webhook receives the event but can't find a matching user → Returns 404

## Authorization Callback Domain vs Webhook URL

These are **different** and serve different purposes:

- **Authorization Callback Domain**: `gvfhtiljkybbrbxoyqsq.supabase.co`
  - Used for OAuth redirects during login
  - Set in Strava Developer Portal → Settings → Authorization Callback Domain

- **Webhook URL**: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook`
  - Used for activity event notifications
  - Created via API (not in Developer Portal UI)

Both are correct! They just serve different purposes.

## How to Test the Webhook

### Step 1: Verify Webhook is Set Up

```bash
curl -X GET "https://www.strava.com/api/v3/push_subscriptions?client_id=184009&client_secret=9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45"
```

You should see a webhook subscription with your callback URL.

### Step 2: Test with Your Own Activity

1. **Make sure you've connected your Strava account in the HYKA app**
2. **Create a test activity on Strava** (record a short run/walk)
3. **Check Supabase Edge Function logs** for:
   - `📥 Strava Activity Webhook started`
   - `📨 Webhook payload:`
   - `✅ Forwarded successfully`

### Step 3: Check Database

After creating an activity, verify it's stored:

```sql
SELECT * FROM strava_activities 
WHERE user_id = 'your-user-id' 
ORDER BY start_date DESC 
LIMIT 5;
```

## Troubleshooting

### Webhook Not Receiving Events

1. **Check webhook subscription exists:**
   ```bash
   ./check_strava_webhook.sh
   ```

2. **Check Supabase logs:**
   - Go to Supabase Dashboard → Edge Functions → `strava-activity-webhook` → Logs
   - Look for verification requests (GET) and activity events (POST)

3. **Verify Edge Function is deployed:**
   ```bash
   cd supabase
   npx supabase functions deploy strava-activity-webhook --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
   ```

### Webhook Receives Events But No Activity Stored

1. **Check if connection exists:**
   ```sql
   SELECT * FROM strava_connections WHERE user_id = 'your-user-id';
   ```

2. **Verify `strava_athlete_id` matches:**
   - The `owner_id` from the webhook must match `strava_athlete_id` in your database
   - Check Supabase logs for: `❌ Strava connection not found for athlete: [ID]`

3. **Check `strava-activity-store` logs:**
   - The webhook forwards to `strava-activity-store`
   - Check those logs for errors

### Friend's Activity Still Not Working

**This is expected behavior!** Strava webhooks are user-specific. For your friend's activities to trigger:

1. Your friend must connect their Strava account to HYKA
2. Your friend must create the activity (not import it)
3. The activity must be created after the connection is established

## Alternative: Polling for Activities

If you need to track friends' activities, you would need to:
1. Have each friend connect their account
2. OR implement a polling mechanism (not recommended - rate limits)
3. OR use Strava's "Following" API (if available)

But for V1, the webhook approach (user-specific) is the standard and recommended method.


