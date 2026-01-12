# Debugging: No Users in user_devices Table

## Why Device Tokens Aren't Being Registered

The device token registration requires **three things** to happen in order:

1. ✅ **User must be logged in** (have a user ID)
2. ✅ **Notification permissions granted** (user authorized push notifications)
3. ✅ **Device token received** from iOS

If any of these are missing, the token won't be saved to `user_devices`.

---

## Step-by-Step Debugging

### Step 1: Check if User is Logged In

The device token registration only happens when:
- User signs in (`signIn` method)
- User signs up (`signUp` method)
- OR app launches with stored user ID in UserDefaults

**Check in Xcode console:**
```
📱 Device token received, will register when user logs in
📱 Found stored user ID, registering device token
```

**If you see:** `📱 No user ID found, device token will be registered on next login`
- **Fix:** User needs to log in first

### Step 2: Check Notification Permissions

**Check in Xcode console:**
```
✅ Push notification authorization granted
```

**If you see:** `⚠️ Push notification authorization denied`
- **Fix:** User needs to grant notification permissions in Settings

### Step 3: Check Device Token Registration

**Check in Xcode console:**
```
📱 Device token received: <token>
✅ Device token saved to Supabase
```

**If you see:** `❌ Error saving device token: <error>`
- **Fix:** Check the error message - likely a Supabase connection or permission issue

---

## Common Issues & Fixes

### Issue 1: User Not Logged In

**Symptoms:**
- No entries in `user_devices` table
- Console shows: `📱 No user ID found`

**Fix:**
1. Make sure user is logged in
2. Check that `hyka.user.id` is stored in UserDefaults:
   ```swift
   // In Xcode debugger, run:
   po UserDefaults.standard.string(forKey: "hyka.user.id")
   ```
3. If nil, user needs to sign in again

### Issue 2: Notification Permissions Not Granted

**Symptoms:**
- No device token received
- Console shows: `❌ Failed to register for remote notifications`

**Fix:**
1. Go to iOS Settings → Your App → Notifications
2. Enable notifications
3. Or request permissions in app:
   ```swift
   await PushNotificationService.shared.requestAuthorization()
   ```

### Issue 3: Supabase Connection Error

**Symptoms:**
- Console shows: `❌ Error saving device token: <error>`
- Error might mention Supabase connection

**Fix:**
1. Check Supabase client is initialized
2. Check network connection
3. Verify Supabase URL and keys are correct
4. Check Supabase logs for errors

### Issue 4: App Not Built with New Bundle ID

**Symptoms:**
- Device token received but wrong bundle ID
- APNs errors about bundle ID mismatch

**Fix:**
1. Verify Xcode Bundle Identifier is `app.hyka.com`
2. Clean build folder (Shift+Cmd+K)
3. Rebuild and run
4. Uninstall old app, install new one

---

## Manual Testing Steps

### Test 1: Check Current State

1. **Open app on device**
2. **Check Xcode console** for these messages:
   - `📱 Device token received...`
   - If YES → token is being received
   - If NO → check notification permissions

3. **Check if user is logged in:**
   - Look for: `📱 Found stored user ID...`
   - Or: `📱 No user ID found...`

### Test 2: Force Token Registration

If user is logged in but token not registered:

1. **Sign out and sign back in:**
   - This triggers `registerDeviceTokenForUser` in `SessionManager`

2. **Or manually trigger:**
   ```swift
   // In Xcode debugger or add temporary code:
   if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
      let userId = UUID(uuidString: UserDefaults.standard.string(forKey: "hyka.user.id") ?? "") {
       await appDelegate.registerDeviceTokenForUser(userId)
   }
   ```

### Test 3: Check Supabase Directly

Run this SQL in Supabase SQL Editor:

```sql
-- Check if any tokens exist
SELECT COUNT(*) as token_count FROM user_devices;

-- Check table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'user_devices';

-- Check if user exists
SELECT id, email FROM auth.users LIMIT 5;
```

---

## Quick Fix: Force Re-registration

If nothing is working, try this:

1. **Delete app from device** (uninstall completely)
2. **Rebuild and install** with new bundle ID (`app.hyka.com`)
3. **Sign in** to the app
4. **Grant notification permissions** when prompted
5. **Check console** for:
   ```
   📱 Device token received: <token>
   ✅ Device token saved to Supabase
   ```
6. **Verify in Supabase:**
   ```sql
   SELECT * FROM user_devices ORDER BY created_at DESC;
   ```

---

## Code Flow Reference

Here's how device token registration works:

```
App Launch
  ↓
AppDelegate.didFinishLaunching
  ↓
application.registerForRemoteNotifications()
  ↓
iOS generates device token
  ↓
AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken
  ↓
Check UserDefaults for "hyka.user.id"
  ↓
If found → Register token immediately
If not found → Store in pendingDeviceToken
  ↓
User signs in
  ↓
SessionManager.signIn/signUp
  ↓
Call appDelegate.registerDeviceTokenForUser(userId)
  ↓
PushNotificationService.registerDeviceToken
  ↓
saveDeviceTokenToSupabase
  ↓
Upsert to user_devices table
```

---

## Verification Checklist

- [ ] User is logged in (check console for user ID)
- [ ] Notification permissions granted (check Settings)
- [ ] Device token received (check console)
- [ ] Token saved to Supabase (check console for success message)
- [ ] Verified in database (run SQL query)
- [ ] App built with correct bundle ID (`app.hyka.com`)
- [ ] Supabase client initialized correctly
- [ ] Network connection working

---

## Still Not Working?

If tokens still aren't registering:

1. **Check Supabase table permissions:**
   ```sql
   -- Verify table exists and has correct structure
   SELECT * FROM user_devices LIMIT 1;
   ```

2. **Check RLS (Row Level Security) policies:**
   - Go to Supabase Dashboard → Authentication → Policies
   - Make sure users can INSERT into `user_devices` table

3. **Add debug logging:**
   - Add `print()` statements in `saveDeviceTokenToSupabase`
   - Check what error is being thrown

4. **Test with curl:**
   ```bash
   # Test if you can insert manually
   curl -X POST 'https://gvfhtiljkybbrbxoyqsq.supabase.co/rest/v1/user_devices' \
     -H "apikey: YOUR_ANON_KEY" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "user_id": "test-user-id",
       "device_token": "test-token",
       "device_type": "ios",
       "push_enabled": true
     }'
   ```
