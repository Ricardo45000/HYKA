# Garmin OAuth Universal Link Fix

## Problem Identified

You're using a **Universal Link** pattern for Garmin OAuth:
- **Garmin Developer Portal**: `https://hyka.app/garmin/callback` (web URL)
- **Web page redirects to**: `app.hyka.com://garmin/callback${location.search}`

But the app was configured to use a **custom scheme** directly:
- **App was sending**: `app.hyka.com://callback` to Garmin

**Result**: Garmin rejects the OAuth request because the redirect URI doesn't match what's registered.

## ✅ Solution Applied

The app has been updated to use the Universal Link pattern:

1. **Updated Config**: Changed `garminRedirectURI` to `https://hyka.app/garmin/callback`
2. **Updated OAuth Flow**: Now uses `https` as the callback scheme for Universal Links
3. **Enhanced Callback Handling**: Handles both Universal Links and custom scheme redirects

## How It Works Now

1. **App sends to Garmin**: `https://hyka.app/garmin/callback` (matches Garmin Portal ✅)
2. **User clicks "Agree"** on Garmin page
3. **Garmin redirects to**: `https://hyka.app/garmin/callback?code=...`
4. **Web page at hyka.app** receives the callback
5. **Web page redirects to**: `app.hyka.com://garmin/callback?code=...`
6. **iOS app intercepts** the Universal Link and processes the OAuth callback
7. **Connection is saved** ✅

## What You Need to Do

### 1. Update Your Config.swift File

Make sure your actual `Config.swift` (not the example) has:

```swift
static let garminRedirectURI = "https://hyka.app/garmin/callback"
```

**Important**: The example file has been updated, but you need to update your actual `Config.swift` file that's used by the app.

### 2. Verify Web Page Redirect

Ensure the web page at `https://hyka.app/garmin/callback` has JavaScript that redirects:

```javascript
// Should redirect to: app.hyka.com://garmin/callback${location.search}
window.location.href = `app.hyka.com://garmin/callback${location.search}`;
```

### 3. Verify Universal Links Setup

For Universal Links to work, you need:

1. **Apple App Site Association (AASA) file** at:
   - `https://hyka.app/.well-known/apple-app-site-association`
   - Should include path: `/garmin/callback`

2. **Associated Domains** in Xcode:
   - Capability: Associated Domains
   - Domain: `applinks:hyka.app`

3. **Info.plist** should have URL scheme `app.hyka.com` registered (already done)

## Testing

After updating `Config.swift`:

1. **Clean and rebuild** the app in Xcode
2. **Try connecting to Garmin** again
3. **Check Xcode console** for logs:
   - Should see: `Redirect URI: https://hyka.app/garmin/callback`
   - Should see: `Callback scheme: https`
   - After clicking "Agree", should see: `✅ Received callback: https://hyka.app/garmin/callback?code=...`
   - Then: `🔗 DEEP LINK CALLBACK RECEIVED!` with `app.hyka.com://garmin/callback?code=...`

## Benefits of Universal Links

✅ **Better user experience**: Works even if app isn't installed (opens web page)
✅ **More reliable**: iOS handles the redirect automatically
✅ **Supports both**: Web and app flows
✅ **Matches Garmin Portal**: Uses the registered web URL

## Troubleshooting

### Issue: "Still not redirecting after clicking Agree"

**Check:**
1. `Config.swift` has `https://hyka.app/garmin/callback` (not the example file)
2. Garmin Portal has exactly `https://hyka.app/garmin/callback`
3. Web page at `https://hyka.app/garmin/callback` exists and redirects properly
4. Universal Links are configured (AASA file, Associated Domains)

### Issue: "Web page opens but app doesn't open"

**Check:**
1. Associated Domains capability is enabled in Xcode
2. AASA file is accessible and valid
3. Testing on real device (Universal Links don't work in simulator)

### Issue: "App opens but no code parameter"

**Check:**
1. Web page is preserving query parameters: `${location.search}`
2. Redirect format: `app.hyka.com://garmin/callback?code=...` (not just `app.hyka.com://garmin/callback`)
