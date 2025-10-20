# Quick Test: garmin-sync-all-users

## Why No Invocations/Logs?

**Most likely reasons:**
1. ✅ Function directory exists (confirmed)
2. ❓ Function may not be deployed to Supabase
3. ❓ Cron job not set up (pg_cron extension doesn't exist)
4. ❓ Function hasn't been manually invoked

## Step 1: Check if Deployed

### Via Supabase Dashboard:
1. Go to: https://supabase.com/dashboard/project/gvfhtiljkybbrbxoyqsq/functions
2. Look for `garmin-sync-all-users` in the list
3. If missing → needs deployment

### Via CLI (if you have Supabase CLI):
```bash
cd "/Volumes/Rissie T7/Ricardo/Project/HYKA_V1_Starter/HYKA"
supabase functions list
```

## Step 2: Deploy the Function

**If not deployed, deploy it:**

```bash
cd "/Volumes/Rissie T7/Ricardo/Project/HYKA_V1_Starter/HYKA"
supabase login
supabase functions deploy garmin-sync-all-users
```

**Or via Supabase Dashboard:**
1. Go to Edge Functions
2. Click "Deploy new function"
3. Upload the `garmin-sync-all-users` folder

## Step 3: Test Manually (IMPORTANT!)

**Test the function to see if it works:**

```bash
curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-sync-all-users \
  -H "Content-Type: application/json"
```

**Expected response:**
```json
{
  "success": true,
  "totalUsers": 1,
  "totalSynced": 5,
  "results": [...]
}
```

**Or if no users connected:**
```json
{
  "message": "No Garmin connections found",
  "synced": 0
}
```

## Step 4: Check Logs

### Via Dashboard:
1. Go to **Edge Functions** → `garmin-sync-all-users`
2. Click **Logs** tab
3. You should see logs after manual invocation

### Via CLI:
```bash
supabase functions logs garmin-sync-all-users
```

## Step 5: Why No Automatic Runs?

**The function won't run automatically unless:**
1. ✅ Cron job is set up (pg_cron extension enabled)
2. ✅ OR external cron service calls the function URL
3. ✅ OR you manually invoke it

**Since pg_cron doesn't exist, you have 2 options:**

### Option A: Use External Cron Service
1. Sign up for cron-job.org or EasyCron
2. Set up a job to call:
   ```
   POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-sync-all-users
   ```
3. Schedule it to run every 6 hours

### Option B: Manual Invocation
- Call the function manually when needed
- Or set up a scheduled task on your local machine/server

## Quick Checklist

- [ ] Function deployed? (Check Dashboard)
- [ ] Function tested manually? (Use curl command above)
- [ ] Logs visible after manual test? (Check Dashboard)
- [ ] OAuth connections exist? (Check `oauth_connections` table)
- [ ] Cron job set up? (If not, use external service or manual invocation)

