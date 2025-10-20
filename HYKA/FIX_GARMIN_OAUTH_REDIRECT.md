# Fix: Garmin OAuth 2.0 Redirect URI Mismatch

## Problem

OAuth 2.0 connection doesn't work because of redirect URI mismatch:
- **OAuth request uses:** `https://hyka.app/garmin/callback`
- **App listens for:** `com.hyka.app://`

`ASWebAuthenticationSession` can't catch HTTPS redirects with a custom scheme callback.

## Solution

Changed redirect URI to use custom URL scheme (required for mobile OAuth):
- **New redirect URI:** `com.hyka.app://garmin/callback`

## Action Required: Update Garmin Developer Portal

You **must** update the redirect URI in Garmin Developer Portal:

1. Go to Garmin Developer Portal
2. Find your app settings
3. Update the **Redirect URI** to: `com.hyka.app://garmin/callback`
4. Save the changes

## Why This Fix Works

- **Before:** HTTPS redirect URI (`https://hyka.app/garmin/callback`) doesn't match custom scheme callback (`com.hyka.app://`)
- **After:** Custom scheme redirect URI (`com.hyka.app://garmin/callback`) matches the callback scheme

## Testing

After updating Garmin Developer Portal:

1. Rebuild the app
2. Try connecting to Garmin again
3. OAuth flow should complete successfully

## Important Notes

- The redirect URI in the code must **exactly match** what's configured in Garmin Developer Portal
- The `callbackURLScheme` in `ASWebAuthenticationSession` must match the scheme part of the redirect URI
- Custom URL schemes are the standard approach for mobile OAuth 2.0

---

**Next Step:** Update the redirect URI in Garmin Developer Portal to `com.hyka.app://garmin/callback`

