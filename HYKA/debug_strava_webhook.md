# Debugging Strava Webhook Issues

## Your Current Setup

- **Strava Connection:**
  - `strava_athlete_id`: 107848938
  - `user_id`: 84b13928-a931-4841-9289-bf2ab30cb07d
  - Connection exists in database ✅

## Step 1: Verify Webhook Subscription Exists

Run this command to check if Strava has your webhook registered:

```bash
curl -X GET "https://www.strava.com/api/v3/push_subscriptions?client_id=184009&client_secret=9a26e7dac6c7e7aa6182bd5f00cc2a40554a3a45"
```

**Expected Response:**
```json
[
  {
    "id": 123456,
    "callback_url": "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook",
    "created_at": "2025-12-08T..."
  }
]
```

**If empty array `[]`:**
- Webhook subscription doesn't exist
- Run: `./create_strava_webhook.sh`

## Step 2: Deploy Updated Webhook Function

The webhook function has been updated to fix type matching. Deploy it:

```bash
cd supabase
npx supabase functions deploy strava-activity-webhook --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
```

## Step 3: Test Webhook Verification

Test that Strava can reach your webhook:

```bash
curl -X GET "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-activity-webhook?hub.mode=subscribe&hub.verify_token=strava-webhook-verify-token-2025&hub.challenge=test123"
```

**Expected Response:**
```json
{"hub.challenge":"test123"}
```

## Step 4: Create a Test Activity

1. **Record a short activity on Strava** (even 1 minute walk works)
2. **OR** create a manual activity in Strava app/web

## Step 5: Check Supabase Logs

Go to: **Supabase Dashboard → Edge Functions → `strava-activity-webhook` → Logs**

**Look for:**
1. `📥 Strava Activity Webhook started` - Webhook received
2. `📨 Webhook payload:` - Full payload from Strava
3. `📋 Parsed webhook event:` - Should show `owner_id: 107848938`
4. `🔍 Looking up connection for athlete_id: 107848938`
5. `✅ Found connection:` - Should show your user_id
6. `➡️ Forwarding activity to strava-activity-store`
7. `✅ Forwarded successfully`

**If you see:**
- `❌ Strava connection not found for athlete: 107848938`
  - Check database: `SELECT * FROM strava_connections WHERE strava_athlete_id = 107848938;`
  - Verify the `strava_athlete_id` matches exactly (no spaces, correct type)

- `⏭️ Skipping event (not activity creation)`
  - The event type is not `activity` or aspect is not `create`
  - This is normal for updates/deletes

- No logs at all
  - Webhook subscription might not exist
  - Strava might not be sending events
  - Check Step 1 again

## Step 6: Check Database

After creating an activity, verify it's stored:

```sql
SELECT 
  id, 
  user_id, 
  strava_activity_id, 
  name, 
  start_date, 
  distance_meters,
  duration_seconds
FROM strava_activities 
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
ORDER BY start_date DESC 
LIMIT 5;
```

## Common Issues

### Issue 1: Webhook Subscription Doesn't Exist

**Solution:**
```bash
./create_strava_webhook.sh
```

### Issue 2: Type Mismatch (Fixed)

The webhook was converting `ownerId` to string, but database stores as integer. **This has been fixed** in the latest version.

### Issue 3: Webhook Not Receiving Events

**Possible causes:**
1. Webhook subscription not verified (Strava sends GET request first)
2. Activity created before webhook was set up
3. Activity imported from another service (not created on Strava)

**Solution:**
- Create a NEW activity after webhook is set up
- Make sure it's a recorded activity, not imported

### Issue 4: Connection Not Found

**Check:**
```sql
SELECT strava_athlete_id, user_id FROM strava_connections;
```

The `owner_id` from webhook must **exactly match** `strava_athlete_id` in database.

## Quick Test Script

Run the test script:

```bash
chmod +x test_strava_webhook.sh
./test_strava_webhook.sh
```

This will:
1. Check if webhook subscription exists
2. Test webhook verification endpoint
3. Show your connection details


