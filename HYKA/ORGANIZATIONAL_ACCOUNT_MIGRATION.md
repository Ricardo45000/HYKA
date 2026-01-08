# Migration Guide: Personal to Organizational Apple Developer Account

## Overview

When transitioning from a personal to an organizational Apple Developer account, you need to update several configurations:

1. **APNs Team ID** in Supabase secrets
2. **APNs Key** (may need to create new one under organizational account)
3. **Xcode Project Team ID** for code signing
4. **Bundle ID Registration** (ensure it's registered under new account)

---

## Step 1: Get Your New Organizational Account Information

### 1.1 Get Your New Team ID

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Sign in with your **organizational account**
3. Look at the **top right corner** - your Team ID is displayed there
4. **Note it down** (format: `ABC123XYZ` - 10 characters)

**OR** check in Xcode:
- Xcode → Preferences → Accounts
- Select your organizational team
- Team ID is shown in the list

### 1.2 Verify Bundle ID is Registered

1. Go to [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)
2. Search for `app.hyka.com`
3. **If it doesn't exist**, you need to:
   - Click **+** to create new App ID
   - Bundle ID: `app.hyka.com`
   - Enable **Push Notifications** capability
   - Click **Continue** → **Register**

### 1.3 Create New APNs Key (If Needed)

**Important:** If your old APNs key was created under your personal account, you should create a new one under the organizational account.

1. Go to [Keys](https://developer.apple.com/account/resources/authkeys/list)
2. Click **+** to create new key
3. **Key Name:** "HYKA APNs Key (Organizational)"
4. Enable: **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. **Download the `.p8` file** (⚠️ You can only download once!)
7. **Note the Key ID** (shown on the page)

**If you want to reuse the old key:**
- Check if the old key still works with the new Team ID
- If it doesn't, you must create a new one

---

## Step 2: Update Supabase Secrets

Update all APNs-related secrets in Supabase with your new organizational account information.

### 2.1 Update Team ID

```bash
cd supabase
npx supabase secrets set APNS_TEAM_ID=YOUR_NEW_TEAM_ID --project-ref gvfhtiljkybbrbxoyqsq
```

Replace `YOUR_NEW_TEAM_ID` with your organizational Team ID.

### 2.2 Update APNs Key ID (If You Created a New Key)

```bash
npx supabase secrets set APNS_KEY_ID=YOUR_NEW_KEY_ID --project-ref gvfhtiljkybbrbxoyqsq
```

Replace `YOUR_NEW_KEY_ID` with the Key ID from Step 1.3.

### 2.3 Update APNs Key Content (If You Created a New Key)

```bash
npx supabase secrets set APNS_KEY_CONTENT="$(cat /path/to/AuthKey_YOUR_KEY_ID.p8)" --project-ref gvfhtiljkybbrbxoyqsq
```

Replace `/path/to/AuthKey_YOUR_KEY_ID.p8` with the path to your downloaded `.p8` file.

### 2.4 Verify Bundle ID (Should Stay the Same)

```bash
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

### 2.5 Verify All Secrets Are Set

```bash
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
```

You should see:
- `APNS_KEY_ID` ✅
- `APNS_TEAM_ID` ✅ (should be your new organizational Team ID)
- `APNS_KEY_CONTENT` ✅
- `APNS_BUNDLE_ID` ✅
- `APNS_ENVIRONMENT` ✅ (development or production)

---

## Step 3: Update Xcode Project Settings

### 3.1 Update Team in Xcode

1. Open your project in Xcode
2. Select your project in the navigator (top item)
3. Select your **target** (HYKA)
4. Go to **Signing & Capabilities** tab
5. Under **Team**, select your **organizational team** from the dropdown
6. Xcode will automatically update the Team ID

### 3.2 Verify Bundle Identifier

1. In the same **Signing & Capabilities** tab
2. Verify **Bundle Identifier** is `app.hyka.com`
3. If it's different, update it to match

### 3.3 Verify Provisioning Profile

1. Xcode should automatically create/update the provisioning profile
2. If you see errors:
   - Click **Download Manual Profiles**
   - Or go to [Profiles](https://developer.apple.com/account/resources/profiles/list) and create one manually

### 3.4 Clean and Rebuild

1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)
3. Verify there are no signing errors

---

## Step 4: Re-register Device Tokens

After changing the Team ID, existing device tokens may need to be re-registered.

### Option A: Let App Re-register Automatically

1. Build and run the app on your device
2. The app should automatically register a new device token
3. Check Supabase `user_devices` table to see the new token

### Option B: Clear Old Tokens Manually

If you want to start fresh:

```sql
-- Connect to your Supabase database and run:
DELETE FROM user_devices;
```

Then let the app register new tokens.

---

## Step 5: Test Push Notifications

### 5.1 Test with Diagnostic Script

```bash
./diagnose_notification.sh
```

Enter your user ID when prompted.

### 5.2 Check Supabase Logs

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Navigate to **Edge Functions** → `garmin-activity-notify` → **Logs**
3. Look for successful notification sends

### 5.3 Common Issues

**Issue: "BadEnvironmentKeyInToken"**
- **Fix:** Ensure `APNS_ENVIRONMENT` matches your build type:
  - Debug builds → `development`
  - TestFlight/App Store → `production`

**Issue: "BadDeviceToken"**
- **Fix:** Re-register device token (Step 4)

**Issue: "403 Forbidden"**
- **Fix:** Verify Team ID and Key ID are correct in Supabase secrets

---

## Quick Checklist

- [ ] Got new organizational Team ID
- [ ] Verified/created Bundle ID under organizational account
- [ ] Created new APNs key (if needed)
- [ ] Updated `APNS_TEAM_ID` in Supabase
- [ ] Updated `APNS_KEY_ID` in Supabase (if new key)
- [ ] Updated `APNS_KEY_CONTENT` in Supabase (if new key)
- [ ] Updated Xcode Team setting
- [ ] Cleaned and rebuilt Xcode project
- [ ] Re-registered device tokens
- [ ] Tested push notifications

---

## Need Help?

If you encounter issues:

1. Check Supabase Edge Function logs for detailed error messages
2. Verify all secrets are set correctly: `npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS`
3. Ensure your bundle ID is registered under the organizational account
4. Make sure the APNs key has Push Notifications enabled
