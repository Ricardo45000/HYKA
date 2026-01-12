# Debugging Notification Issues

## Your Device Tokens

You have 2 device tokens registered:
1. **User:** `fc600af9-2926-4b86-b841-25a25d17c10c`
   - Device: `1ee8c1007a5cfdfcb623a4e65fb8dd2ba7c03e100f800e31a9f99ea607468310`
2. **User:** `84b13928-a931-4841-9289-bf2ab30cb07d` ✅ (This is the one you're testing)
   - Device: `70cb4b0a8e53d2110334fc385204844882fab37547f365b49eb46adbab86b96a`

## Step 1: Check Supabase Logs

Go to **Supabase Dashboard → Edge Functions → `garmin-activity-notify` → Logs**

Look for these messages:

### ✅ Success indicators:
- `📱 Garmin Activity Notification Service started`
- `🔍 Looking up device tokens for user: 84b13928-a931-4841-9289-bf2ab30cb07d`
- `📱 Found 1 device(s) for push notifications`
- `✅ Push notification sent to device: 70cb4b0a...`

### ❌ Error indicators:
- `ℹ️ APNs not configured - skipping push notifications`
  - **Fix:** Set APNs secrets in Supabase
- `❌ APNs error: 403` or `❌ APNs error: 401`
  - **Fix:** Check APNs key configuration
- `❌ APNs error: 410`
  - **Fix:** Device token is invalid (app uninstalled or token expired)
- `❌ Error processing APNs key`
  - **Fix:** APNS_KEY_CONTENT is malformed

## Step 2: Verify APNs Configuration

Check if these secrets are set in Supabase:

1. Go to **Supabase Dashboard → Settings → Edge Functions → Secrets**
2. Verify these exist:
   - `APNS_KEY_ID` - Your APNs key ID (e.g., `ABC123XYZ`)
   - `APNS_TEAM_ID` - Your Apple Team ID (e.g., `DEF456UVW`)
   - `APNS_KEY_CONTENT` - Your APNs private key (full PEM content)
   - `APNS_BUNDLE_ID` - Optional (defaults to `app.hyka.com`)

### If missing, set them:

```bash
cd supabase
npx supabase secrets set APNS_KEY_ID=your_key_id --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_TEAM_ID=your_team_id --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_KEY_CONTENT="$(cat /path/to/AuthKey_ABC123XYZ.p8)" --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

## Step 3: Test with Debug Script

Run the debug script to see detailed output:

```bash
chmod +x debug_notification.sh
export SUPABASE_SERVICE_ROLE_KEY='your-key'
./debug_notification.sh 84b13928-a931-4841-9289-bf2ab30cb07d
```

## Step 4: Common Issues

### Issue 1: "APNs not configured"
**Solution:** Set all APNs secrets in Supabase

### Issue 2: "APNs error: 403 Forbidden"
**Possible causes:**
- Wrong APNs key ID or Team ID
- Key doesn't have push notification permissions
- Bundle ID mismatch

**Solution:**
- Verify key ID and Team ID match your Apple Developer account
- Ensure the key has "Apple Push Notifications service (APNs)" enabled
- Check bundle ID matches your app

### Issue 3: "APNs error: 410 Gone"
**Solution:** Device token is invalid. User may have:
- Uninstalled the app
- Token expired
- Need to re-register device token

### Issue 4: Notification sent but not received
**Check:**
1. Device has internet connection
2. App has notification permissions enabled
3. Device is not in Do Not Disturb mode
4. Check device notification settings

## Step 5: Manual Test

Try invoking the function again with this exact payload:

```json
{
  "user_id": "84b13928-a931-4841-9289-bf2ab30cb07d",
  "activity_id": "test-manual-123",
  "activity_name": "Test Run",
  "activity_type": "Running",
  "distance_meters": 5000,
  "duration_seconds": 1800
}
```

Then immediately check the logs to see what happened.

## Quick Check Commands

### Check if device token exists:
```sql
SELECT * FROM user_devices 
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d' 
AND push_enabled = true;
```

### Check recent notification attempts:
Go to **Supabase Dashboard → Edge Functions → garmin-activity-notify → Logs**
Filter by timestamp to see your recent invocation.


