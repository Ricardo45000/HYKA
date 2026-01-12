# Strava OAuth Fix - Token Exchange Error

## Problem
After switching to organizational Apple Developer account, Strava OAuth fails with "failed to exchange authorization code for access token" error.

## Root Cause
The `redirect_uri` parameter must match **EXACTLY** between:
1. The authorization request sent to Strava
2. The token exchange request sent to Strava

## ✅ Code Changes Made

### 1. iOS App (`DeviceOAuthManager.swift`)
- **Changed:** Now uses `Config.stravaAuthCallbackURL` (Supabase Edge Function URL) instead of `Config.stravaRedirectURI` (app deep link)
- **Why:** Strava redirects to a web URL first, then the Edge Function redirects to the app

### 2. Supabase Edge Function (`strava-auth-callback/index.ts`)
- **Changed:** Updated redirect URLs to include `/callback` path: `app.hyka.com://callback?code=...`
- **Why:** Proper deep link format for iOS app

## 🔧 Manual Steps Required

### Step 1: Update Your `Config.swift` File

Make sure your `ios/Config/Config.swift` has:

```swift
// Strava OAuth Redirect URI - MUST be the Supabase Edge Function URL
static let stravaRedirectURI = "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback"

// Strava OAuth Callback Edge Function URL
static var stravaAuthCallbackURL: String {
    return "\(edgeFunctionsBaseURL)/strava-auth-callback"
}
```

**Important:** The `stravaRedirectURI` should be the **full Supabase Edge Function URL**, not the app deep link.

### Step 2: Update Strava Developer Settings

1. Go to: https://www.strava.com/settings/api
2. Find your app settings
3. Update the **Authorization Callback Domain**:
   - Set to: `gvfhtiljkybbrbxoyqsq.supabase.co`
   - OR use the full redirect URI: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback`
4. Click **Save**
5. **Wait 1-2 minutes** for changes to propagate

### Step 3: Verify the Flow

The correct OAuth flow should be:

1. **App** → Opens Strava OAuth with `redirect_uri = https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback`
2. **Strava** → Redirects to Supabase Edge Function with `code` parameter
3. **Edge Function** → Redirects to app: `app.hyka.com://callback?code=...`
4. **App** → Sends code to Edge Function with same `redirect_uri`
5. **Edge Function** → Exchanges code with Strava using same `redirect_uri`
6. **Success!** → Tokens received and stored

## ⚠️ Common Issues

### Issue 1: "redirect_uri mismatch"
**Error:** Strava returns error about redirect_uri not matching

**Fix:**
- Make sure `Config.stravaRedirectURI` in your app matches exactly what's in Strava settings
- Make sure you're using the Supabase Edge Function URL, not the app deep link
- Wait 1-2 minutes after updating Strava settings

### Issue 2: "Safari cannot open the page"
**Error:** Safari shows "address is invalid" error

**Fix:**
- This was fixed by updating the Edge Function redirect URLs to include `/callback` path
- Make sure your `Info.plist` has the URL scheme `app.hyka.com` registered

### Issue 3: Token exchange still fails
**Error:** Code exchange returns 400 or 401 error

**Fix:**
- Check Supabase Edge Function logs for detailed error messages
- Verify `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET` are set in Supabase secrets
- Make sure the redirect_uri in the token exchange matches the authorization request exactly

## 🔍 Debugging

### Check Supabase Edge Function Logs

1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions
2. Click on `strava-auth-callback`
3. View the **Logs** tab
4. Look for:
   - `🔄 Exchanging authorization code for tokens...`
   - `❌ Token exchange failed:` (if there's an error)
   - The `redirect_uri` value being used

### Verify Redirect URI

In the Edge Function logs, you should see:
```
Token exchange parameters:
- client_id: YOUR_CLIENT_ID
- code: ...
- redirect_uri: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/strava-auth-callback
```

This `redirect_uri` must match **exactly** what's configured in Strava.

## ✅ Verification Checklist

- [ ] `Config.swift` has `stravaRedirectURI` set to Supabase Edge Function URL
- [ ] `Config.swift` has `stravaAuthCallbackURL` defined
- [ ] Strava settings have Authorization Callback Domain set to `gvfhtiljkybbrbxoyqsq.supabase.co`
- [ ] Strava settings saved and waited 1-2 minutes
- [ ] Code changes deployed (iOS app rebuilt, Edge Function redeployed if needed)
- [ ] Tested OAuth flow end-to-end

## 📝 Notes

- The redirect URI changed from app deep link (`app.hyka.com://callback`) to web URL (Supabase Edge Function) because Strava requires a web redirect URL
- The Edge Function then redirects to the app using the deep link
- This is the standard OAuth flow for mobile apps using web-based OAuth providers
