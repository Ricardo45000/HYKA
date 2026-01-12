# Edge Functions Bundle ID Update: `app.hyka.com`

## ✅ Updated Functions

All OAuth callback functions have been updated to use the new bundle ID `app.hyka.com` with the `/callback` path:

### 1. `strava-auth-callback/index.ts`
- ✅ Updated redirect URLs to: `app.hyka.com://callback?code=...`
- ✅ Updated error redirects to: `app.hyka.com://callback?error=...`

### 2. `polar-auth-callback/index.ts`
- ✅ Updated redirect URLs to: `app.hyka.com://callback?code=...`
- ✅ Updated error redirects to: `app.hyka.com://callback?error=...`

### 3. `suunto-auth-callback/index.ts`
- ✅ Updated redirect URLs to: `app.hyka.com://callback?code=...`
- ✅ Updated error redirects to: `app.hyka.com://callback?error=...`

### 4. `garmin-activity-notify/index.ts`
- ✅ Already updated: Uses `app.hyka.com` as default bundle ID

### 5. `garmin-auth-callback/index.ts`
- ✅ No redirect URLs (POST-only, no web redirects)

## 🚀 Deployment Instructions

### Step 1: Login to Supabase

```bash
cd supabase
npx supabase login
```

This will open a browser window for authentication.

### Step 2: Deploy All Functions

Run the deployment script:

```bash
cd /Volumes/Rissie\ T7/Ricardo/Project/HYKA_V1_Starter/HYKA/HYKA
./deploy_auth_callbacks.sh
```

Or deploy individually:

```bash
cd supabase

# Deploy each function
npx supabase functions deploy strava-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
npx supabase functions deploy polar-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
npx supabase functions deploy suunto-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
npx supabase functions deploy garmin-auth-callback --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
npx supabase functions deploy garmin-activity-notify --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
```

## 📝 Changes Summary

### Before:
- Redirect URLs: `app.hyka.com://?code=...` (missing `/callback` path)
- Error redirects: `app.hyka.com://?error=...` (missing `/callback` path)

### After:
- Redirect URLs: `app.hyka.com://callback?code=...` (with `/callback` path)
- Error redirects: `app.hyka.com://callback?error=...` (with `/callback` path)

## ✅ Verification

After deployment, verify the functions are working:

1. **Test OAuth flows:**
   - Try connecting Strava, Polar, or Suunto from the app
   - Verify the redirect works correctly
   - Check that the app receives the callback

2. **Check Supabase logs:**
   - Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions
   - Click on each function → View Logs
   - Look for successful redirects with `app.hyka.com://callback`

## 🔍 What Changed

All OAuth callback functions now use a consistent deep link format:
- **Success redirects:** `app.hyka.com://callback?code=XXX&state=YYY`
- **Error redirects:** `app.hyka.com://callback?error=XXX`

This matches the URL scheme registered in `Info.plist`:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>app.hyka.com</string>
    <string>hyka</string>
</array>
```

The `/callback` path helps distinguish OAuth callbacks from other deep links in the app.
