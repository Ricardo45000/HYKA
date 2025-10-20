# Debug: "Failed to fetch connections" Error

## ✅ Good News
The function **IS deployed** and responding! The error means it's running but hitting an issue.

## Issue: "Failed to fetch connections"

This error occurs when the function can't query the `oauth_connections` table. Possible causes:

### 1. Missing Environment Variables

The function needs these environment variables (set in Supabase Dashboard):

**Check in Dashboard:**
1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions/garmin-sync-all-users
2. Click **Settings** tab
3. Check **Environment Variables** section

**Required variables:**
- `SUPABASE_URL` - Usually auto-set to `https://gvfhtiljkybbrbxoyqsq.supabase.co`
- `SUPABASE_SERVICE_ROLE_KEY` - Your service role key (needed for admin access)

**To set them:**
1. In Dashboard → Edge Functions → `garmin-sync-all-users` → Settings
2. Add environment variables:
   - `SUPABASE_URL` = `https://gvfhtiljkybbrbxoyqsq.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` = (get from Dashboard → Settings → API → service_role key)

### 2. Check Database Table

Verify the `oauth_connections` table exists and has the right schema:

```sql
-- Check if table exists
SELECT * FROM information_schema.tables 
WHERE table_name = 'oauth_connections';

-- Check table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'oauth_connections';

-- Check if there are any Garmin connections
SELECT user_id, provider, access_token IS NOT NULL as has_token
FROM oauth_connections
WHERE provider = 'garmin';
```

### 3. Check Function Logs

**In Supabase Dashboard:**
1. Go to Edge Functions → `garmin-sync-all-users`
2. Click **Logs** tab
3. Look for detailed error messages

**Via CLI:**
```bash
supabase functions logs garmin-sync-all-users
```

### 4. Test with Better Error Handling

The function should log more details. Check the logs to see:
- Is `SUPABASE_URL` set?
- Is `SUPABASE_SERVICE_ROLE_KEY` set?
- What's the exact database error?

## Quick Fix Steps

1. **Set Environment Variables** in Dashboard
2. **Check Logs** for detailed error
3. **Verify Table Exists** using SQL query above
4. **Test Again** with curl command

## Expected Behavior

Once fixed, the function should:
- Return `{"message": "No Garmin connections found", "synced": 0}` if no users connected
- OR return sync results if users are connected

