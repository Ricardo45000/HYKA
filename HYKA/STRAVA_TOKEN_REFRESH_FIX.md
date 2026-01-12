# Strava Token Refresh Fix

## Problem

The Strava webhook was receiving events correctly, but `strava-activity-store` was failing with a **401 Authorization Error** when trying to fetch activity details from Strava's API. This was because:

1. The access token stored in the database had expired
2. Token refresh logic was not implemented (marked as TODO)

## Solution

Implemented automatic token refresh in `strava-activity-store`:

### 1. Proactive Token Refresh
- Checks if token expires within 5 minutes
- Automatically refreshes before expiration
- Updates connection in database with new tokens

### 2. Reactive Token Refresh (401 Handling)
- If API call returns 401 (Unauthorized)
- Automatically refreshes token using refresh_token
- Retries the API request once with new token
- Updates connection in database

### 3. Token Refresh Implementation
Uses Strava's OAuth token endpoint:
```
POST https://www.strava.com/oauth/token
{
  client_id: STRAVA_CLIENT_ID,
  client_secret: STRAVA_CLIENT_SECRET,
  grant_type: "refresh_token",
  refresh_token: <stored_refresh_token>
}
```

## What This Fixes

✅ **Webhook now works end-to-end:**
1. Strava sends webhook → `strava-activity-webhook` receives it
2. Webhook forwards to → `strava-activity-store`
3. Store function refreshes token if needed
4. Fetches activity details from Strava API
5. Stores activity in database
6. Triggers notification → `garmin-activity-notify`
7. User receives push notification

## Deployment

Deploy the updated function:

```bash
cd supabase
npx supabase functions deploy strava-activity-store --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
```

## Testing

1. **Create a test activity on Strava**
2. **Check Supabase logs** for:
   - `strava-activity-webhook`: `✅ Forwarded successfully`
   - `strava-activity-store`: `✅ Token refreshed successfully` (if needed)
   - `strava-activity-store`: `✅ Activity stored`
   - `garmin-activity-notify`: `✅ Push notification sent`

3. **Verify in database:**
```sql
SELECT * FROM strava_activities 
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
ORDER BY start_date DESC 
LIMIT 1;
```

4. **Check notification received** on your iOS device

## Environment Variables Required

Make sure these are set in Supabase Secrets:

- `STRAVA_CLIENT_ID` - Your Strava app client ID
- `STRAVA_CLIENT_SECRET` - Your Strava app client secret

Set them with:
```bash
cd supabase
npx supabase secrets set STRAVA_CLIENT_ID=your_client_id --project-ref gvfhtiljkybbrbxoyqsq
npx supabase secrets set STRAVA_CLIENT_SECRET=your_client_secret --project-ref gvfhtiljkybbrbxoyqsq
```

## Notes

- Tokens are automatically refreshed when needed
- Refresh tokens are also updated if Strava provides a new one
- Connection is updated in database after each refresh
- If refresh fails, the original error is thrown (no infinite retries)


