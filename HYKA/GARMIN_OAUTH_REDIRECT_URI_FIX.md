# Garmin OAuth Redirect URI Fix

## Problem
After clicking "Agree" on Garmin Connect authorization page, nothing happens. The OAuth flow doesn't complete.

## Root Cause
The redirect URI registered in **Garmin Developer Portal** doesn't match what the app is using.

## Current App Configuration

The app uses:
- **Redirect URI**: `app.hyka.com://callback`
- **Callback URL Scheme**: `app.hyka.com`

## ✅ Fix Steps

### Step 1: Check Garmin Developer Portal

1. Go to: https://developer.garmin.com/my-apps/
2. Select your HYKA app
3. Navigate to **OAuth 2.0** settings
4. Check the **Redirect URI** field

### Step 2: Update Redirect URI in Garmin Portal

**If you see:**
- ❌ `com.hyka.app://callback` (old bundle ID)

**Change it to:**
- ✅ `app.hyka.com://callback` (new bundle ID)

### Step 3: Save and Wait

1. Click **Save** in Garmin Developer Portal
2. **Wait 1-2 minutes** for changes to propagate
3. Try connecting again

## Verification

After updating, the OAuth flow should work:
1. Click "Connect with Garmin" in the app
2. Garmin Connect page opens
3. Click "Agree"
4. App receives callback: `app.hyka.com://callback?code=...`
5. Connection is saved successfully

## Debugging

If it still doesn't work after updating:

1. **Check the logs** in Xcode console:
   - Look for: `🔄 Garmin OAuth 2.0 with PKCE Flow`
   - Check: `Redirect URI: app.hyka.com://callback`
   - If callback fails, you'll see: `❌ Garmin OAuth callback URL is nil`

2. **Verify in Garmin Portal**:
   - Redirect URI must be **exactly**: `app.hyka.com://callback`
   - No trailing slashes
   - No typos

3. **Check Info.plist**:
   - Ensure `CFBundleURLSchemes` includes `app.hyka.com`
   - File: `ios/Info.plist`

## Common Issues

### Issue 1: "Nothing happens after clicking Agree"
**Cause**: Redirect URI mismatch
**Fix**: Update Garmin Portal to use `app.hyka.com://callback`

### Issue 2: "Safari cannot open the page"
**Cause**: URL scheme not registered in Info.plist
**Fix**: Verify `app.hyka.com` is in `CFBundleURLSchemes`

### Issue 3: "Invalid callback"
**Cause**: Garmin redirects to wrong URL
**Fix**: Double-check redirect URI in Garmin Portal matches exactly
