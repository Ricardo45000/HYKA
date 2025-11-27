# Fix 401 Unauthorized Error for Garmin Webhooks

## Problem

Garmin webhooks are receiving **401 Unauthorized** errors when calling your Supabase Edge Functions:
- `garmin-health-webhook` → 401
- `garmin-activity-push` → May also get 401
- `garmin-activity-ping` → May also get 401

## Root Cause

Supabase Edge Functions require authentication by default. Garmin webhooks don't send Supabase authentication headers (they can't include your `apikey`), so Supabase's gateway blocks them with 401 before the function code even runs.

## Solution: Make Functions Public

You need to configure the Edge Functions to allow **anonymous/unauthenticated** access in the Supabase Dashboard.

### Step 1: Open Supabase Dashboard

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project: `gvfhtiljkybbrbxoyqsq`

### Step 2: Navigate to Edge Functions

1. Click **"Edge Functions"** in the left sidebar
2. You'll see a list of all your functions

### Step 3: Make Functions Public

For each Garmin webhook function, you need to allow anonymous access:

#### For `garmin-health-webhook`:
1. Click on **`garmin-health-webhook`**
2. Go to **Settings** or **Configuration** tab
3. Find **"Require Authentication"** or **"Allow Anonymous Access"** option
4. **Disable** authentication requirement (or **Enable** anonymous access)
5. Save changes

#### For `garmin-activity-push`:
1. Click on **`garmin-activity-push`**
2. Repeat the same steps as above

#### For `garmin-activity-ping`:
1. Click on **`garmin-activity-ping`**
2. Repeat the same steps as above

#### For `garmin-permission-webhook`:
1. Click on **`garmin-permission-webhook`**
2. Repeat the same steps as above

### Alternative: Using Supabase CLI

If you prefer using the CLI, you can update the function configuration:

```bash
# Navigate to your project
cd /path/to/your/project

# Update function to allow anonymous access
supabase functions update garmin-health-webhook --no-verify-jwt
supabase functions update garmin-activity-push --no-verify-jwt
supabase functions update garmin-activity-ping --no-verify-jwt
supabase functions update garmin-permission-webhook --no-verify-jwt
```

**Note:** The `--no-verify-jwt` flag tells Supabase to skip JWT verification for these functions, allowing anonymous access.

## Verify the Fix

After making the functions public:

1. **Check Supabase Logs:**
   - Go to Edge Functions → Logs
   - Look for `garmin-health-webhook` invocations
   - You should see **200 OK** instead of **401 Unauthorized**

2. **Test with curl:**
   ```bash
   curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook \
     -H "Content-Type: application/json" \
     -H "User-Agent: Garmin Health API" \
     -d '{"test": "data"}'
   ```
   - Should return **200 OK** (not 401)

3. **Wait for Garmin to retry:**
   - Garmin will automatically retry failed webhooks
   - Check logs after a few minutes to see if new requests succeed

## Security Considerations

**Is it safe to make these functions public?**

✅ **Yes, because:**
- The functions use **webhook secrets** in the URL path for authentication
- They verify the **User-Agent** header (must contain "Garmin")
- They use **Service Role Key** internally (not exposed to callers)
- They validate the webhook payload structure
- They only process data for users who have connected Garmin

**The webhook secret in the URL path provides authentication:**
- Format: `/functions/v1/garmin-health-webhook/SECRET_TOKEN`
- Only requests with the correct secret are processed
- Garmin Developer Portal should include the secret in the webhook URL

## Current Webhook Configuration

Based on your Garmin Developer Portal screenshot:

### ✅ Currently Enabled:
- **ACTIVITY - Activities** → `garmin-activity-push` ✅
- **ACTIVITY - Activity Details** → `garmin-activity-push` ✅
- **ACTIVITY - Activity Files** → `garmin-activity-push` ✅
- **COMMON - User Permissions Change** → `garmin-permission-webhook` ✅
- **HEALTH - Health Snapshot** → `garmin-health-webhook` ✅
- **HEALTH - User Metrics** → `garmin-health-webhook` ✅

### ⚠️ Not Enabled (but configured):
- **HEALTH - Body Compositions** → Not enabled
- **HEALTH - Dailies** → Not enabled
- **HEALTH - Epochs** → Not enabled
- **HEALTH - HRV Summary** → Not enabled
- **HEALTH - Pulse Ox** → Not enabled
- **HEALTH - Respiration** → Not enabled
- **HEALTH - Skin Temperature** → Not enabled
- **HEALTH - Sleeps** → Not enabled
- **HEALTH - Stress** → Not enabled
- **HEALTH - Blood Pressure** → Enabled but URL is placeholder

## Next Steps

1. **Make functions public** (see steps above)
2. **Verify webhook URLs include secrets** in Garmin Developer Portal:
   - Should be: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook/SECRET`
   - Not: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook`
3. **Enable additional health endpoints** if needed (Body Compositions, Sleeps, etc.)
4. **Monitor logs** to confirm webhooks are arriving successfully

## Expected Behavior After Fix

- ✅ Garmin sends webhook → Supabase receives it (200 OK)
- ✅ Function processes data → Stores in database
- ✅ Activities and health metrics appear in Supabase
- ✅ App can read data from Supabase

---

**Summary:** The 401 error is because Supabase Edge Functions require authentication by default. Make the Garmin webhook functions public/anonymous in the Supabase Dashboard to allow Garmin to call them without authentication headers.

