# Garmin OAuth Debugging Guide

## Problem: "Nothing happens after clicking Agree"

If you click "Agree" on the Garmin Connect authorization page and nothing happens, this guide will help you diagnose and fix the issue.

## Common Causes

### 1. Redirect URI Mismatch (Most Common)

**Symptom:** After clicking "Agree", the page doesn't redirect back to the app.

**Cause:** The redirect URI in Garmin Developer Portal doesn't match what the app is sending.

**Fix:**
1. Go to: https://developer.garmin.com/my-apps/
2. Select your HYKA app
3. Navigate to **OAuth 2.0** settings
4. Check the **Redirect URI** field
5. It must be **EXACTLY**: `app.hyka.com://callback`
   - No trailing slashes
   - No typos
   - Case-sensitive
6. Click **Save**
7. **Wait 1-2 minutes** for changes to propagate
8. Try connecting again

### 2. URL Scheme Not Registered

**Symptom:** Redirect happens but app doesn't open.

**Fix:**
1. Check `Info.plist` has the URL scheme registered:
   ```xml
   <key>CFBundleURLSchemes</key>
   <array>
       <string>app.hyka.com</string>
   </array>
   ```
2. Clean and rebuild the app in Xcode
3. Make sure you're testing on a real device (not simulator)

### 3. ASWebAuthenticationSession Not Intercepting

**Symptom:** Browser opens but callback isn't received.

**Possible causes:**
- The `callbackURLScheme` doesn't match the redirect URI scheme
- The session was cancelled or dismissed
- iOS security restrictions

**Debug steps:**
1. Check Xcode console logs for:
   - `🔄 Garmin OAuth 2.0 with PKCE Flow`
   - `🌐 Starting OAuth session...`
   - `✅ Garmin OAuth callback received:` (if successful)
   - `❌ Garmin OAuth callback URL is nil` (if failed)

2. Look for error messages:
   - `Redirect URI mismatch` → Fix in Garmin Portal
   - `User cancelled` → User tapped cancel
   - `Invalid callback` → Check redirect URI

## Step-by-Step Debugging

### Step 1: Verify Garmin Developer Portal Settings

1. **Login:** https://developer.garmin.com/my-apps/
2. **Select your app**
3. **Go to OAuth 2.0 settings**
4. **Check Redirect URI:**
   - Should be: `app.hyka.com://callback`
   - NOT: `com.hyka.app://callback` (old bundle ID)
   - NOT: `app.hyka.com://callback/` (trailing slash)
   - NOT: `app.hyka.com/callback` (missing `://`)

### Step 2: Verify App Configuration

1. **Check Config.swift:**
   ```swift
   static let garminRedirectURI = "app.hyka.com://callback"
   ```

2. **Check Info.plist:**
   - URL scheme `app.hyka.com` is registered
   - Bundle identifier is `app.hyka.com`

3. **Check Xcode console:**
   - Look for the authorization URL being printed
   - Verify the redirect_uri parameter matches

### Step 3: Test the Flow

1. **Start OAuth flow** in the app
2. **Watch Xcode console** for logs
3. **Click "Agree"** on Garmin page
4. **Check what happens:**
   - ✅ App should automatically return and show success
   - ❌ If nothing happens, check console for errors
   - ❌ If error appears, follow the error message

### Step 4: Check Console Logs

Look for these log messages:

**Success flow:**
```
🔄 Garmin OAuth 2.0 with PKCE Flow
   Redirect URI: app.hyka.com://callback
🌐 Starting OAuth session...
✅ Garmin OAuth callback received: app.hyka.com://callback?code=...
```

**Failure flow:**
```
❌ Garmin OAuth callback URL is nil
   This usually means:
   1. Redirect URI mismatch between app and Garmin Developer Portal
   2. Check Garmin Portal has: app.hyka.com://callback
```

## Quick Fix Checklist

- [ ] Garmin Developer Portal redirect URI is `app.hyka.com://callback`
- [ ] No trailing slashes or typos in redirect URI
- [ ] Waited 1-2 minutes after updating Garmin Portal
- [ ] Info.plist has URL scheme `app.hyka.com` registered
- [ ] App bundle identifier is `app.hyka.com`
- [ ] Testing on real device (not simulator)
- [ ] Clean build and rebuild app
- [ ] Check Xcode console for detailed error messages

## Still Not Working?

If the issue persists after checking all of the above:

1. **Check Garmin API Status:**
   - Visit: https://status.garmin.com/
   - Ensure OAuth services are operational

2. **Try Different Network:**
   - Switch from WiFi to cellular or vice versa
   - Some networks block OAuth redirects

3. **Check iOS Version:**
   - Ensure you're on iOS 12.0+ (required for ASWebAuthenticationSession)

4. **Verify Client ID:**
   - Make sure the Client ID in Config.swift matches Garmin Portal
   - Check for typos or extra spaces

5. **Contact Support:**
   - If all else fails, check Garmin Developer Forums
   - Or contact Garmin Developer Support

## Expected Behavior

**Correct flow:**
1. User taps "Connect with Garmin"
2. Safari/WebView opens with Garmin Connect login
3. User logs in (if needed)
4. User sees "Connect with Hyka?" page
5. User clicks "Agree"
6. **App automatically returns** (no manual action needed)
7. Connection is saved
8. Success message appears

**If step 6 doesn't happen**, there's a redirect URI mismatch.
