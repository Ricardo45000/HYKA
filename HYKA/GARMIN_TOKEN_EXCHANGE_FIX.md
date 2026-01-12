# Fix: "Failed to exchange authorization code for access token"

## Problem

After clicking "Agree" on Garmin, the redirect works, but the token exchange fails with:
> **"Failed to exchange authorization code for access token"**

## Root Causes

The token exchange can fail for several reasons:

### 1. Redirect URI Mismatch (Most Common)

**Issue**: The `redirect_uri` used in the token exchange request doesn't match what was used in the authorization request.

**Fix**: 
- The `redirect_uri` must be **EXACTLY** the same in both requests
- Check that `Config.swift` has: `app.hyka.com://callback`
- Check that Garmin Portal has: `app.hyka.com://callback`
- Both must match exactly

### 2. Authorization Code Already Used

**Issue**: Authorization codes are single-use. If you try to connect multiple times with the same code, it fails.

**Fix**: 
- Each authorization code can only be used once
- If it fails, start a fresh OAuth flow (disconnect and reconnect)

### 3. Authorization Code Expired

**Issue**: Authorization codes expire quickly (usually within minutes).

**Fix**: 
- Don't wait too long between authorization and token exchange
- The app should exchange immediately after receiving the code

### 4. Code Verifier Mismatch (PKCE)

**Issue**: The `code_verifier` used in token exchange doesn't match the `code_challenge` used in authorization.

**Fix**: 
- The app generates both and stores them together
- This should be automatic, but if it fails, check PKCE implementation

## Debugging Steps

### Step 1: Check Xcode Console

Look for these logs when connecting:

```
🔐 Exchanging authorization code for access token via Supabase Edge Function...
   Redirect URI: app.hyka.com://callback
```

**Verify**: The redirect URI shown matches `app.hyka.com://callback`

### Step 2: Check Supabase Edge Function Logs

1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions
2. Click on `garmin-auth-callback`
3. View the **Logs** tab
4. Look for:
   - `🔄 Exchanging code for Garmin tokens`
   - `❌ Token exchange failed:` (if there's an error)
   - The `redirect_uri` value being used
   - The actual error message from Garmin

### Step 3: Verify Redirect URI Consistency

The redirect URI must be the same in:
1. ✅ `Config.swift`: `app.hyka.com://callback`
2. ✅ Garmin Developer Portal: `app.hyka.com://callback`
3. ✅ Authorization request: `redirect_uri=app.hyka.com://callback`
4. ✅ Token exchange request: `redirect_uri=app.hyka.com://callback`

## Common Error Messages

### "invalid_grant" or "invalid_request"

**Cause**: Redirect URI mismatch or code already used

**Fix**: 
- Verify redirect URI matches in all places
- Start a fresh OAuth flow

### "invalid_client"

**Cause**: Client ID or Client Secret mismatch

**Fix**: 
- Check Supabase secrets: `GARMIN_CLIENT_ID` and `GARMIN_CLIENT_SECRET`
- Verify they match Garmin Developer Portal

### "invalid_code"

**Cause**: Authorization code is invalid, expired, or already used

**Fix**: 
- Start a fresh OAuth flow
- Don't reuse authorization codes

## Quick Fix Checklist

- [ ] `Config.swift` has `app.hyka.com://callback`
- [ ] Garmin Portal has `app.hyka.com://callback`
- [ ] Removed old redirect URIs from Garmin Portal
- [ ] Started a fresh OAuth flow (didn't reuse old code)
- [ ] Checked Supabase Edge Function logs for detailed error
- [ ] Verified Supabase secrets are set correctly

## Still Not Working?

If the issue persists:

1. **Check Supabase Edge Function logs** for the exact Garmin error
2. **Verify Supabase secrets**:
   ```bash
   npx supabase secrets list --project-ref gvfhtiljkybbrbxoyqsq | grep GARMIN
   ```
3. **Try disconnecting and reconnecting** to get a fresh authorization code
4. **Check Garmin API status**: https://status.garmin.com/
