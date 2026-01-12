# Fix: Garmin Token Exchange 404 Error

## Problem

Token exchange fails with:
> **HTTP Status 404 – Not Found**  
> **Garmin Connect API Server**

## Root Cause

The token exchange endpoint URL was incorrect:
- ❌ **Wrong**: `https://connectapi.garmin.com/oauth-service/oauth/exchange/user/access_token`
- ✅ **Correct**: `https://connectapi.garmin.com/oauth-service/oauth/token`

## ✅ Fix Applied

The Edge Function has been updated to use the correct OAuth 2.0 token endpoint.

## Verification

After the fix, the token exchange should work. Check Supabase Edge Function logs:

1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions
2. Click on `garmin-auth-callback`
3. View the **Logs** tab
4. Look for:
   - `🔄 Exchanging code for Garmin tokens`
   - `✅ Tokens received` (success)
   - Or error details if it still fails

## Next Steps

1. **Deploy the updated Edge Function**:
   ```bash
   cd supabase
   npx supabase functions deploy garmin-auth-callback
   ```

2. **Try connecting to Garmin again**

3. **Check the logs** to verify it's working

## Reference

Garmin OAuth 2.0 PKCE Documentation:
- Token Endpoint: `https://connectapi.garmin.com/oauth-service/oauth/token`
- Authorization Endpoint: `https://connect.garmin.com/oauth2Confirm`
