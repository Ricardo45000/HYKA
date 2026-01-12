# Fix: "Safari cannot open the page because the address is invalid"

## Problem

After clicking "Agree" on the Garmin Connect authorization page, you see:
> **"Safari cannot open the page because the address is invalid"**

## Root Cause

This error occurs when:
1. **Redirect URI mismatch**: The redirect URI in Garmin Developer Portal doesn't match what the app is sending
2. **Invalid URL format**: The redirect URI has an invalid format that Safari can't handle

## ✅ Solution: Use Custom Scheme Directly

The simplest and most reliable approach is to use the **custom scheme** directly instead of Universal Links:

### Step 1: Update Garmin Developer Portal

1. Go to: https://developer.garmin.com/my-apps/
2. Select your HYKA app
3. Navigate to **OAuth 2.0** settings
4. **Change Redirect URI to**: `app.hyka.com://callback`
   - Remove: `https://hyka.app/garmin/callback` (if present)
   - Add: `app.hyka.com://callback`
5. Click **Save**
6. **Wait 1-2 minutes** for changes to propagate

### Step 2: Update Your Config.swift

Make sure your actual `Config.swift` file has:

```swift
static let garminRedirectURI = "app.hyka.com://callback"
```

**Important**: Update your actual `Config.swift` file (not just the example).

### Step 3: Verify Info.plist

Ensure `Info.plist` has the URL scheme registered:

```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>app.hyka.com</string>
</array>
```

### Step 4: Clean and Rebuild

1. Clean build folder in Xcode (Shift+Cmd+K)
2. Rebuild the app (Cmd+B)
3. Try connecting to Garmin again

## How It Works

1. **App sends to Garmin**: `app.hyka.com://callback` (matches Garmin Portal ✅)
2. **User clicks "Agree"** on Garmin page
3. **Garmin redirects to**: `app.hyka.com://callback?code=...`
4. **iOS app intercepts** the custom scheme automatically
5. **Connection is saved** ✅

## Why This Works Better

✅ **No web page required**: Direct redirect to app
✅ **More reliable**: No dependency on web server
✅ **Faster**: No intermediate redirect
✅ **Simpler**: Fewer moving parts

## Troubleshooting

### Still seeing "Safari cannot open the page"?

1. **Double-check Garmin Portal**:
   - Redirect URI must be **exactly**: `app.hyka.com://callback`
   - No `https://` prefix
   - No trailing slashes
   - Case-sensitive

2. **Verify Config.swift**:
   - Open your actual `Config.swift` file (not the example)
   - Ensure: `static let garminRedirectURI = "app.hyka.com://callback"`

3. **Check Xcode console**:
   - Look for: `Redirect URI: app.hyka.com://callback`
   - If you see `https://hyka.app/garmin/callback`, Config.swift wasn't updated

4. **Test on real device**:
   - Custom schemes work better on real devices than simulators

## Alternative: If You Must Use Universal Links

If you need to use `https://hyka.app/garmin/callback` for some reason:

1. **Ensure the web page exists** and is accessible
2. **The web page must redirect** to `app.hyka.com://garmin/callback${location.search}`
3. **Configure Associated Domains** in Xcode:
   - Capability: Associated Domains
   - Domain: `applinks:hyka.app`
4. **Add AASA file** at: `https://hyka.app/.well-known/apple-app-site-association`

However, **using the custom scheme directly is recommended** as it's simpler and more reliable.
