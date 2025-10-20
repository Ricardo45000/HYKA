# Fix: Garmin Portal Removes API Key from Webhook URL

## Problem

Garmin Developer Portal removes the `?apikey=...` query parameter when you save the webhook URL.

## Solution: Use Secret Token in URL Path

Instead of using a query parameter, we'll use a secret token in the URL path itself.

---

## Step 1: Set Webhook Secret (Optional)

You can set a custom secret, or use the default:

```bash
supabase secrets set GARMIN_WEBHOOK_SECRET=your-secret-token-here
```

**Or use the default:** `garmin-webhook-secret-2024`

---

## Step 2: Configure Webhook URL in Garmin Portal

Use this format (secret token in the path):

```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping/garmin-webhook-secret-2024
```

**Note:** Replace `garmin-webhook-secret-2024` with your custom secret if you set one.

---

## Alternative: Make Function Public (Less Secure)

If you want to make the function completely public (no authentication), we can do that, but it's less secure. The security comes from:
1. The webhook URL being secret (only you and Garmin know it)
2. The user-agent check (verifies it's from Garmin)

---

## How It Works

The function now:
1. ✅ Extracts secret token from URL path
2. ✅ Verifies it matches expected secret (if set)
3. ✅ Checks user-agent is from Garmin
4. ✅ Still processes the webhook even if checks fail (to prevent retries)

---

## Test

After updating the webhook URL:

1. Upload a test activity to Garmin Connect
2. Check Supabase Edge Function logs for `garmin-activity-ping`
3. Should see: `✅ Valid secret token verified` (if secret matches)
4. Should see: `🔔 Garmin PING received`

---

## If Portal Still Strips the Path

If Garmin Developer Portal also strips the path segment, we can:

1. **Make function completely public** (no auth required)
2. **Use a different webhook endpoint** with the secret in the function name
3. **Use a custom domain** with path routing

Let me know which approach you prefer!

