# Notification Updates Required After Bundle ID Change

## ✅ What's Already Updated in Code

The code has been updated automatically:
- ✅ Supabase Edge Function default bundle ID: `app.hyka.com` (line 12 in `garmin-activity-notify/index.ts`)
- ✅ iOS app will automatically use the bundle ID from Xcode project settings
- ✅ Device token registration code doesn't need changes (uses system bundle ID)

---

## 🔴 What YOU Must Update Manually

### 1. **Update Supabase Secret (CRITICAL)**

The `APNS_BUNDLE_ID` secret in Supabase must match your new bundle ID:

```bash
cd supabase
npx supabase login  # If not already logged in
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

**Why this matters:** APNs uses this bundle ID to verify that notifications are being sent to the correct app. If it doesn't match, you'll get `BadDeviceToken` errors.

**Verify it's set:**
```bash
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS_BUNDLE_ID
```

---

### 2. **Register Bundle ID in Apple Developer Portal (CRITICAL)**

You **must** register `app.hyka.com` in Apple Developer Portal with **Push Notifications enabled**:

1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Sign in with your **organizational account**
3. Click **+** to create new App ID
4. **Bundle ID:** `app.hyka.com`
5. **Enable:** ✅ **Push Notifications** capability (this is critical!)
6. Click **Continue** → **Register**

**Why this matters:** APNs won't work unless the bundle ID is registered and Push Notifications capability is enabled.

---

### 3. **Update Xcode Bundle Identifier**

1. Open Xcode
2. Select your project → Target → **Signing & Capabilities**
3. **Bundle Identifier:** Change to `app.hyka.com`
4. **Team:** Select your organizational team
5. Xcode should automatically create/update the provisioning profile

**Why this matters:** The app's actual bundle ID must match what's registered in Apple Developer Portal and what's in Supabase.

---

### 4. **Re-register Device Tokens (REQUIRED)**

**Important:** Device tokens are tied to the bundle ID. After changing the bundle ID:

1. **Old tokens will stop working** - They were registered with `com.hyka.app`
2. **New tokens must be registered** - With the new bundle ID `app.hyka.com`

**What happens automatically:**
- When users open the updated app, it will automatically register a new device token
- The new token will be stored in Supabase `user_devices` table
- Old tokens can be deleted (they won't work anyway)

**To clean up old tokens (optional):**
```sql
-- Connect to your Supabase database
-- Delete old device tokens (they won't work with new bundle ID anyway)
DELETE FROM user_devices 
WHERE device_token IN (
  SELECT device_token FROM user_devices 
  WHERE created_at < NOW() - INTERVAL '1 day'
);
```

**Or let them expire naturally** - They'll just fail when you try to send notifications.

---

### 5. **Verify APNs Key is Valid for New Bundle ID**

Your APNs key should work with the new bundle ID as long as:
- ✅ It's created under your **organizational account**
- ✅ The **Team ID** matches your organizational Team ID
- ✅ The bundle ID `app.hyka.com` is registered in Apple Developer Portal

**If you created a new APNs key:**
- Make sure to update `APNS_KEY_ID` and `APNS_KEY_CONTENT` in Supabase secrets

---

## 🔍 How to Verify Everything is Working

### Step 1: Check Supabase Secrets
```bash
cd supabase
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
```

Should show:
- `APNS_BUNDLE_ID` = `app.hyka.com` ✅
- `APNS_TEAM_ID` = Your organizational Team ID ✅
- `APNS_KEY_ID` = Your APNs key ID ✅
- `APNS_KEY_CONTENT` = (hidden, but should be set) ✅
- `APNS_ENVIRONMENT` = `development` or `production` ✅

### Step 2: Test Device Token Registration
1. Build and run the app on a device
2. Check Supabase `user_devices` table for new token
3. Verify the token is registered with the new bundle ID

### Step 3: Test Push Notification
```bash
./diagnose_notification.sh
```

Or manually test:
1. Go to Supabase Dashboard → Edge Functions → `garmin-activity-notify` → Invoke
2. Check logs for errors
3. Should see: `✅ Push notification sent to device`

---

## ⚠️ Common Issues After Bundle ID Change

### Issue: "BadDeviceToken" Error

**Cause:** Bundle ID mismatch or old device token

**Fix:**
1. Verify `APNS_BUNDLE_ID` in Supabase matches `app.hyka.com`
2. Verify bundle ID in Xcode matches `app.hyka.com`
3. Re-register device token (delete old one, open app to get new one)

### Issue: "403 Forbidden" Error

**Cause:** Bundle ID not registered in Apple Developer Portal or Push Notifications not enabled

**Fix:**
1. Register `app.hyka.com` in Apple Developer Portal
2. Enable Push Notifications capability
3. Wait a few minutes for changes to propagate

### Issue: "No device tokens found"

**Cause:** Old tokens were deleted or new tokens not registered yet

**Fix:**
1. Open the app on device (will auto-register new token)
2. Check `user_devices` table in Supabase
3. Verify `push_enabled = true`

---

## 📋 Quick Checklist

- [ ] Updated `APNS_BUNDLE_ID` secret in Supabase to `app.hyka.com`
- [ ] Registered `app.hyka.com` in Apple Developer Portal (organizational account)
- [ ] Enabled Push Notifications capability for the bundle ID
- [ ] Updated Bundle Identifier in Xcode to `app.hyka.com`
- [ ] Selected organizational team in Xcode
- [ ] Built and ran app to register new device tokens
- [ ] Verified new tokens appear in Supabase `user_devices` table
- [ ] Tested push notification (should work now!)

---

## Summary

**For notifications to work, you need to:**

1. ✅ **Update Supabase secret:** `APNS_BUNDLE_ID=app.hyka.com`
2. ✅ **Register bundle ID** in Apple Developer Portal with Push Notifications
3. ✅ **Update Xcode** bundle identifier to `app.hyka.com`
4. ✅ **Re-register device tokens** (automatic when users open updated app)

The code is already updated - you just need to configure the services and re-register tokens!
