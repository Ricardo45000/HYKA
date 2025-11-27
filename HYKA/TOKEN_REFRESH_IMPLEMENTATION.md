# Garmin Token Refresh Implementation

## What Was Implemented

Automatic token refresh for Garmin OAuth 2.0 access tokens. When a token expires, the system automatically refreshes it using the refresh_token before making API calls.

## Files Created/Modified

### 1. New File: `supabase/functions/_shared/garmin-token-refresh.ts`
- **Purpose**: Shared utility for token refresh
- **Functions**:
  - `refreshGarminToken()`: Refreshes an expired access token
  - `isTokenExpired()`: Checks if a token is expired or about to expire
  - `getValidAccessToken()`: Gets a valid token, refreshing if necessary

### 2. Modified: `supabase/functions/garmin-activity-backfill/index.ts`
- **Changes**:
  - Imports token refresh utilities
  - Checks token expiration before using it
  - Automatically refreshes if expired
  - Uses refreshed token for Garmin API calls

## How It Works

1. **Before making Garmin API call:**
   - Check if `token_expires_at` is in the past (or within 5 minutes)
   
2. **If expired:**
   - Call Garmin's token refresh endpoint
   - Get new `access_token` and `refresh_token`
   - Update `garmin_connections` table
   - Use new token for API call

3. **If valid:**
   - Use existing token directly

## Garmin Token Refresh Endpoint

```
POST https://diauth.garmin.com/di-oauth2-service/oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token
refresh_token=<refresh_token>
client_id=<GARMIN_CLIENT_ID>
client_secret=<GARMIN_CLIENT_SECRET>
```

## Testing

### Test 1: With Expired Token
```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-backfill" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"userId": "fc600af9-2926-4b86-b841-25a25d17c10c"}'
```

**Expected behavior:**
- Function detects expired token
- Automatically refreshes token
- Uses new token for backfill request
- Returns 202 Accepted (if successful)

### Test 2: With Valid Token
Same request, but if token is still valid:
- Uses existing token directly
- No refresh needed

## Environment Variables Required

Make sure these are set in Supabase Secrets:
- `GARMIN_CLIENT_ID`: Your Garmin OAuth client ID
- `GARMIN_CLIENT_SECRET`: Your Garmin OAuth client secret

## Error Handling

If refresh fails:
- Returns 401 error with message: "Failed to refresh Garmin access token. Please reconnect Garmin."
- User needs to reconnect Garmin in the app

## Next Steps

1. **Deploy the updated function:**
   ```bash
   supabase functions deploy garmin-activity-backfill
   ```

2. **Test with expired token** (wait for token to expire or manually set `token_expires_at` in database)

3. **Monitor logs** to see token refresh in action

4. **Optional: Update other functions** that use `access_token`:
   - `garmin-activity-push` (if it uses access_token)
   - Any other functions that call Garmin API

## Benefits

✅ **No more "Token is not active" errors**
✅ **Automatic token management**
✅ **Better user experience** (no need to reconnect)
✅ **Seamless operation** (tokens refresh in background)

