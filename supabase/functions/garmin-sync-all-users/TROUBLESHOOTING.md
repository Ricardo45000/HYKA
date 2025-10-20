# Troubleshooting: No Invocations or Logs

## Step 1: Check if Function is Deployed

### Option A: Via Supabase Dashboard
1. Go to https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq
2. Navigate to **Edge Functions** in the left sidebar
3. Look for `garmin-sync-all-users` in the list
4. If it's not there, it needs to be deployed

### Option B: Via Supabase CLI
```bash
cd /Volumes/Rissie\ T7/Ricardo/Project/HYKA_V1_Starter/HYKA
supabase functions list
```

## Step 2: Deploy the Function

If the function is not deployed:

```bash
cd /Volumes/Rissie\ T7/Ricardo/Project/HYKA_V1_Starter/HYKA
supabase functions deploy garmin-sync-all-users
```

**Note**: You need to be logged in:
```bash
supabase login
```

## Step 3: Test Manually (Before Setting Up Cron)

Test the function manually to see if it works:

```bash
curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-sync-all-users \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

Replace `YOUR_ANON_KEY` with your Supabase anon key (or use service role key for testing).

**Expected Response:**
```json
{
  "success": true,
  "totalUsers": 1,
  "totalSynced": 5,
  "results": [...]
}
```

## Step 4: Check Logs

### Via Supabase Dashboard
1. Go to **Edge Functions** → `garmin-sync-all-users`
2. Click on **Logs** tab
3. You should see invocation logs

### Via Supabase CLI
```bash
supabase functions logs garmin-sync-all-users
```

## Step 5: Verify Environment Variables

The function needs these environment variables (set in Supabase Dashboard):
- `SUPABASE_URL` (usually auto-set)
- `SUPABASE_SERVICE_ROLE_KEY` (usually auto-set)

Check in Dashboard: **Edge Functions** → `garmin-sync-all-users` → **Settings** → **Environment Variables**

## Step 6: Check for Errors

If the function is deployed but not working:

1. **Check function logs** for errors
2. **Verify OAuth connections exist**:
   ```sql
   SELECT user_id, provider, access_token IS NOT NULL as has_token
   FROM oauth_connections
   WHERE provider = 'garmin' AND token_secret IS NULL;
   ```
3. **Check if users have activities** in Garmin account

## Common Issues

### Issue 1: Function Not Deployed
**Solution**: Deploy using `supabase functions deploy garmin-sync-all-users`

### Issue 2: No OAuth Connections
**Solution**: Users need to connect their Garmin account first via the iOS app

### Issue 3: Cron Job Not Set Up
**Solution**: 
- First enable `pg_cron` extension (if available)
- Or use external cron service (cron-job.org, EasyCron)
- Or manually invoke the function

### Issue 4: Function Returns Empty
**Solution**: Check logs to see if:
- Garmin API is returning data
- Activities are being filtered out
- OAuth tokens are valid

## Manual Invocation (Alternative to Cron)

If `pg_cron` is not available, you can:
1. Use external cron service to call the function URL
2. Set up a scheduled task on your server
3. Manually invoke when needed

