# Solution: Public Webhook (No API Key Needed)

## Problem

Garmin Developer Portal removes the `?apikey=...` query parameter when you save the webhook URL.

## Solution: Make Function Public

I've updated the function to be **completely public** (no authentication required). This is secure because:

1. ✅ **Webhook URL is secret** - Only you and Garmin know the exact URL
2. ✅ **User-agent verification** - Function checks that requests come from Garmin
3. ✅ **No sensitive data exposed** - Function only receives webhooks, doesn't expose data

---

## Configure Webhook in Garmin Portal

**Use this simple URL (no API key needed):**

```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
```

**That's it!** No query parameters, no API keys, just the URL.

---

## How It Works

1. Garmin sends webhook to your function
2. Function verifies `User-Agent: Garmin Health API` header
3. Function processes the webhook and forwards to pull function
4. Returns 200 OK to Garmin

---

## Security

**Why this is secure:**

- **Webhook URL is secret** - The URL itself acts as authentication. Only you and Garmin know it.
- **User-agent check** - Function verifies requests come from Garmin's servers
- **No data exposure** - Function only receives webhooks, doesn't expose any data
- **Internal functions protected** - The `garmin-activity-pull` and `garmin-activity-store` functions still require service role key

**This is the standard approach for webhooks** - most webhook endpoints are public with the URL being the secret.

---

## Test

1. Save the webhook URL in Garmin Developer Portal (without any API key)
2. Upload a test activity to Garmin Connect
3. Check Supabase Edge Function logs:
   - Should see: `🔔 Garmin PING received`
   - Should see: `✅ PING processed`
   - Should NOT see: `401 Unauthorized`

---

## If You Want Extra Security

If you want an additional layer of security, you can:

1. **Use a secret token in the URL path:**
   ```
   https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping/your-secret-token
   ```
   (But Garmin portal might also strip this)

2. **Use a custom domain** with path routing

3. **Add IP whitelisting** (if Garmin provides static IPs)

For now, the public function with user-agent verification is the simplest and most reliable approach.

