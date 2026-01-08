# Fixing "DeviceTokenNotForTopic" Error

## The Problem

You're seeing this error:
```
ERROR: APNs error: 400 - {"reason": "DeviceTokenNotForTopic"}
ERROR: Bundle ID: app.hyka.com
ERROR: Device token: 1ee8c100...07468310
```

**What this means:**
- Your device tokens were registered with the **old bundle ID** (`com.hyka.app`)
- But notifications are being sent with the **new bundle ID** (`app.hyka.com`)
- APNs rejects them because the token doesn't match the topic (bundle ID)

## The Solution

Device tokens are **tied to the bundle ID**. After changing the bundle ID, you **must** re-register all device tokens.

### Step 1: Delete Old Device Tokens

You have two options:

#### Option A: Delete All Tokens (Recommended)

Run this SQL in your Supabase SQL Editor:

```sql
-- Delete all device tokens - users will re-register automatically
DELETE FROM user_devices;
```

#### Option B: Delete Tokens for Specific Users

If you want to be more selective:

```sql
-- Replace with actual user IDs from the error logs
DELETE FROM user_devices 
WHERE user_id IN (
  'fc600af9-2926-4b86-6841-25a25d17c10c',
  '84b13928-a931-4841-9289-bf2ab30cb07d'
);
```

Or use the SQL file:
```bash
# Connect to Supabase and run:
psql <your-connection-string> < fix_device_tokens_bundle_id.sql
```

### Step 2: Users Re-register Tokens

**This happens automatically!** When users open the updated app:

1. The app detects it needs to register for push notifications
2. It requests a new device token from iOS
3. The new token is registered with the **new bundle ID** (`app.hyka.com`)
4. The token is saved to Supabase `user_devices` table

**No action needed from users** - just opening the app is enough.

### Step 3: Verify New Tokens

After users open the app, check Supabase:

```sql
SELECT 
  user_id,
  device_token,
  device_type,
  push_enabled,
  created_at
FROM user_devices
ORDER BY created_at DESC;
```

You should see:
- ✅ New tokens with recent `created_at` timestamps
- ✅ `push_enabled = true`
- ✅ `device_type = 'ios'`

### Step 4: Test Notifications

Try sending a test notification:

```bash
./diagnose_notification.sh
```

Or use the Supabase Dashboard:
1. Go to **Edge Functions** → `garmin-activity-notify`
2. Click **Invoke**
3. Check logs - should see `✅ Push notification sent to device`

---

## Why This Happens

**Device tokens are bundle ID-specific:**
- Token registered with `com.hyka.app` → Only works with `com.hyka.app`
- Token registered with `app.hyka.com` → Only works with `app.hyka.com`

When you change the bundle ID:
- Old tokens become invalid for the new bundle ID
- APNs returns `DeviceTokenNotForTopic` error
- Solution: Delete old tokens, register new ones

---

## Prevention

After changing bundle IDs in the future:
1. Delete old device tokens immediately
2. Update app with new bundle ID
3. Users open app → tokens auto-register
4. Notifications work again

---

## Quick Fix Script

If you want to automate this, you can create a Supabase Edge Function or use the SQL file provided.

**Manual fix (fastest):**
1. Go to Supabase Dashboard → SQL Editor
2. Run: `DELETE FROM user_devices;`
3. Tell users to open the app (or wait for them to do it naturally)
4. Test notifications

---

## Important Notes

- ⚠️ **Old tokens won't work** - Don't try to keep them
- ✅ **Re-registration is automatic** - Users just need to open the app
- ✅ **No data loss** - Only device tokens are deleted, not user data
- ✅ **Happens once** - After re-registration, everything works normally

---

## Verification Checklist

- [ ] Deleted old device tokens from `user_devices` table
- [ ] Verified bundle ID in Xcode is `app.hyka.com`
- [ ] Verified `APNS_BUNDLE_ID` secret in Supabase is `app.hyka.com`
- [ ] Users opened the updated app (new tokens registered)
- [ ] New tokens appear in `user_devices` table
- [ ] Test notification sent successfully
- [ ] No more `DeviceTokenNotForTopic` errors in logs
