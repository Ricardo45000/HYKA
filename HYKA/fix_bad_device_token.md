# Fixing "BadDeviceToken" Error

## The Problem

You're getting `APNs error: 400 - {"reason":"BadDeviceToken"}`. This means Apple Push Notification service rejected your device token.

## Common Causes & Solutions

### 1. Environment Mismatch (Most Common)

**Problem:** Device token is for sandbox, but APNs is using production (or vice versa).

**Check:**
- What environment is your app running in?
  - **Development/Debug build** → Should use `APNS_ENVIRONMENT=development` (sandbox)
  - **Production/Release build** → Should use `APNS_ENVIRONMENT=production`

**Fix:**
1. Check your Supabase secret:
   ```bash
   # Check current setting
   cd supabase
   npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS_ENVIRONMENT
   ```

2. Set the correct environment:
   ```bash
   # For development/debug builds
   npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
   
   # For production/release builds
   npx supabase secrets set APNS_ENVIRONMENT=production --project-ref gvfhtiljkybbrbxoyqsq
   ```

### 2. Bundle ID Mismatch

**Problem:** The bundle ID in APNs doesn't match your app's bundle ID.

**Check:**
- Your app's bundle ID (from Xcode): `app.hyka.com`
- APNs bundle ID secret: Should match exactly

**Fix:**
```bash
cd supabase
npx supabase secrets set APNS_BUNDLE_ID=app.hyka.com --project-ref gvfhtiljkybbrbxoyqsq
```

### 3. Invalid Device Token

**Problem:** The device token stored in database is invalid or expired.

**Check:**
```sql
SELECT 
  device_token, 
  device_type, 
  push_enabled,
  created_at,
  updated_at
FROM user_devices 
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';
```

**Fix:**
1. **Re-register device token:**
   - Open the app on the device
   - The app should automatically register a new token
   - Check if a new token appears in the database

2. **Verify token format:**
   - Should be 64 hexadecimal characters
   - No spaces or dashes
   - Example: `70cb4b0a8e53d2110334fc385204844882fab37547f365b49eb46adbab86b96a`

### 4. APNs Key Issues

**Problem:** APNs key doesn't have correct permissions or is for wrong team.

**Check:**
1. Verify APNs key has "Apple Push Notifications service (APNs)" enabled
2. Verify key is for the correct Team ID
3. Verify key ID matches what's in Supabase secrets

**Fix:**
1. Go to Apple Developer → Certificates, Identifiers & Profiles → Keys
2. Find your APNs key
3. Verify it's enabled for APNs
4. Download the key again if needed
5. Update Supabase secret with correct key content

## Quick Diagnostic Steps

### Step 1: Check Current Configuration

```bash
cd supabase
npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep APNS
```

You should see:
- `APNS_KEY_ID`
- `APNS_TEAM_ID`
- `APNS_KEY_CONTENT`
- `APNS_BUNDLE_ID` (optional, defaults to `app.hyka.com`)
- `APNS_ENVIRONMENT` (optional, defaults to `production`)

### Step 2: Determine Correct Environment

**If testing with:**
- **Xcode debug build** → Use `development` (sandbox)
- **TestFlight or App Store** → Use `production`

**Most likely fix:**
```bash
cd supabase
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
```

### Step 3: Re-register Device Token

1. **Delete old token from database:**
   ```sql
   DELETE FROM user_devices 
   WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';
   ```

2. **Open the app on your device** (it will re-register automatically)

3. **Verify new token:**
   ```sql
   SELECT device_token FROM user_devices 
   WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';
   ```

4. **Test notification again**

## Most Likely Solution

For development/testing, try:

```bash
cd supabase
npx supabase secrets set APNS_ENVIRONMENT=development --project-ref gvfhtiljkybbrbxoyqsq
```

Then test the notification again. If you're using a production build (TestFlight/App Store), keep it as `production`.

## After Fixing

1. **Deploy updated function** (if you made code changes):
   ```bash
   cd supabase
   npx supabase functions deploy garmin-activity-notify --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
   ```

2. **Test notification again** using the Supabase Dashboard

3. **Check logs** for:
   - `✅ Push notification sent to device` (success)
   - Or more detailed error messages if it still fails


