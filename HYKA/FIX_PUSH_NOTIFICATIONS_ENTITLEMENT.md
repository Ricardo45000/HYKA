# Fix: "no valid aps-environment entitlement" Error

## The Problem

You're seeing this error:
```
❌ Failed to register for remote notifications: Error Domain=NSCocoaErrorDomain Code=3000 
"no valid "aps-environment" entitlement string found for application"
```

**What this means:**
- Your app doesn't have the **Push Notifications capability** enabled
- iOS requires this entitlement to generate device tokens
- Without it, `registerForRemoteNotifications()` will always fail

---

## The Solution

You need to enable Push Notifications capability in Xcode.

### Step 1: Enable Push Notifications in Xcode

1. **Open your project in Xcode**

2. **Select your project** in the Project Navigator (top item, blue icon)

3. **Select your target** (HYKA) in the main editor

4. **Go to "Signing & Capabilities" tab**

5. **Click "+ Capability"** (top left, next to "Signing & Capabilities")

6. **Search for "Push Notifications"** and double-click it

7. **Verify it appears** in the capabilities list with a checkmark ✅

### Step 2: Verify Entitlements File

After adding the capability, Xcode should automatically update `HYKA.entitlements`:

1. **Check the entitlements file** - it should now contain:
   ```xml
   <key>aps-environment</key>
   <string>development</string>
   ```
   Or for production:
   ```xml
   <key>aps-environment</key>
   <string>production</string>
   ```

2. **If it's not there**, manually add it to `HYKA.entitlements`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>aps-environment</key>
       <string>development</string>
   </dict>
   </plist>
   ```

### Step 3: Verify Bundle ID is Registered

Make sure `app.hyka.com` is registered in Apple Developer Portal with Push Notifications:

1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list)
2. Find `app.hyka.com`
3. Verify **Push Notifications** capability is enabled
4. If not, edit it and enable Push Notifications

### Step 4: Clean and Rebuild

1. **Clean Build Folder:**
   - Menu: **Product** → **Clean Build Folder**
   - Or press: **Shift + Cmd + K**

2. **Delete Derived Data** (optional but recommended):
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

3. **Rebuild:**
   - Menu: **Product** → **Build**
   - Or press: **Cmd + B**

4. **Run on device:**
   - Make sure you're running on a **real device** (not simulator)
   - Simulators don't support push notifications

### Step 5: Verify It Works

After rebuilding, check Xcode console:

**Before (Error):**
```
❌ Failed to register for remote notifications: no valid "aps-environment" entitlement
```

**After (Success):**
```
📱 Device token received, will register when user logs in
📱 Found stored user ID, registering device token
✅ Device token saved to Supabase
```

---

## Environment Settings

The `aps-environment` value depends on your build:

- **`development`** - For debug builds, development testing
- **`production`** - For TestFlight, App Store, release builds

**Xcode usually sets this automatically:**
- Debug builds → `development`
- Release builds → `production`

**You can verify in Xcode:**
1. Select your target
2. Go to **Build Settings**
3. Search for "Code Signing Entitlements"
4. Make sure `HYKA.entitlements` is listed

---

## Troubleshooting

### Issue: Capability Not Available

**If you can't add Push Notifications capability:**

1. **Check Team is selected:**
   - Signing & Capabilities → Team dropdown
   - Must have a team selected

2. **Check Bundle ID is registered:**
   - Bundle ID must exist in Apple Developer Portal
   - Must have Push Notifications enabled

3. **Check provisioning profile:**
   - Xcode should create/update automatically
   - If not, go to Apple Developer Portal → Profiles
   - Create new profile with Push Notifications enabled

### Issue: Still Getting Error After Adding Capability

1. **Verify entitlements file is in build:**
   - Target → Build Settings → Code Signing Entitlements
   - Should be: `HYKA/HYKA.entitlements` (or your path)

2. **Check file is in project:**
   - Make sure `HYKA.entitlements` is in your Xcode project
   - Should be visible in Project Navigator

3. **Clean and rebuild:**
   - Sometimes Xcode needs a clean build to pick up entitlements

4. **Check provisioning profile:**
   - Xcode → Preferences → Accounts
   - Select your team → Download Manual Profiles
   - Or create new profile in Apple Developer Portal

### Issue: Works in Debug but Not Release

**Check the entitlements value:**
- Debug might have `development`
- Release might need `production`

**Fix:**
1. Select target → Build Settings
2. Search for "Code Signing Entitlements"
3. Make sure both Debug and Release point to the same entitlements file
4. Or create separate entitlements files for each configuration

---

## Verification Checklist

After fixing:

- [ ] Push Notifications capability added in Xcode
- [ ] `aps-environment` key in `HYKA.entitlements` file
- [ ] Bundle ID `app.hyka.com` registered in Apple Developer Portal
- [ ] Push Notifications enabled for bundle ID in Apple Developer Portal
- [ ] Provisioning profile includes Push Notifications
- [ ] Project cleaned and rebuilt
- [ ] Running on real device (not simulator)
- [ ] No more "aps-environment" error in console
- [ ] Device token received successfully
- [ ] Token saved to Supabase `user_devices` table

---

## Quick Fix Summary

1. **Xcode** → Target → **Signing & Capabilities** → **+ Capability** → **Push Notifications**
2. **Verify** `HYKA.entitlements` has `<key>aps-environment</key>`
3. **Clean** build folder (Shift+Cmd+K)
4. **Rebuild** and run on device
5. **Check console** - should see device token received

This is a **required step** - without the entitlement, iOS will never generate device tokens!
