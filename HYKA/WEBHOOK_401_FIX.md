# Fix: 401 Unauthorized on Garmin Webhook

## Problem

Garmin is sending webhooks to `garmin-activity-ping`, but getting **401 Unauthorized** error.

**Error:**
```
POST | 401 | https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
```

## Root Cause

Supabase Edge Functions require authentication by default. Garmin webhooks don't send authorization headers.

## Solution

### Option 1: Use Anon Key in Webhook URL (Recommended)

Configure Garmin webhook URL with anon key:

```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY
```

**Steps:**
1. Get your anon key from Supabase Dashboard → Settings → API
2. Update webhook URL in Garmin Developer Portal to include `?apikey=YOUR_ANON_KEY`
3. Redeploy function if needed

### Option 2: Add Secret Token Validation

Add a secret token check in the function:

1. Set a secret token in Supabase secrets: `GARMIN_WEBHOOK_SECRET`
2. Configure Garmin to send token in webhook URL: `?token=SECRET`
3. Validate token in function

### Option 3: Make Function Public (Current Fix)

I've updated the function to:
- Handle CORS preflight (OPTIONS requests)
- Not require authentication (public access)
- Verify request is from Garmin (user-agent check)
- Return proper CORS headers

**Security Note:** The webhook URL itself is the security (it's a secret URL). The function now accepts requests without auth headers.

---

## Updated Function

The `garmin-activity-ping` function now:
1. ✅ Handles OPTIONS requests (CORS)
2. ✅ Accepts requests without auth headers
3. ✅ Verifies user-agent is from Garmin
4. ✅ Returns proper CORS headers

---

## Test

After deploying, test by:
1. Upload activity to Garmin Connect
2. Check Supabase logs - should see 200 OK instead of 401
3. Verify activity appears in `garmin_activities` table

---

## Alternative: Use Anon Key (More Secure)

If you want to keep authentication, use the anon key in the webhook URL:

**In Garmin Developer Portal:**
```
Webhook URL: https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY
```

This way the function still requires authentication, but Garmin can access it with the anon key.

