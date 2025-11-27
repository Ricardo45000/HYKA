# Solution: 401 Errors for Garmin Webhooks

## Problem

Garmin webhooks are receiving `401 Unauthorized` errors because:
1. Supabase Edge Functions require authentication at the **gateway level**
2. Garmin cannot send `Authorization` headers
3. Garmin cannot include query parameters (`?apikey=...`) in webhook URLs
4. The 401 error happens **before** our function code runs

## Solution Options

### Option 1: Use Supabase Anon Key in URL Path (If Garmin Allows)

If Garmin Developer Portal allows path segments, you can include the anon key in the path:

**Webhook URLs:**
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping/YOUR_ANON_KEY
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push/YOUR_ANON_KEY
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook/YOUR_ANON_KEY
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook/YOUR_ANON_KEY
```

**Get your anon key:**
- Supabase Dashboard → Settings → API → `anon` `public` key

**Update functions to extract anon key from path:**
The functions are already updated to extract secrets from the URL path. We just need to modify them to also accept the anon key.

### Option 2: Use Custom Domain with Reverse Proxy

Set up a custom domain that proxies to Supabase without requiring auth:

1. **Set up a reverse proxy** (e.g., Cloudflare Workers, AWS Lambda, etc.)
2. **Proxy adds the anon key** to requests before forwarding to Supabase
3. **Garmin calls your custom domain** (no auth required)
4. **Proxy forwards to Supabase** with anon key

**Example:**
```
Garmin → https://webhooks.yourdomain.com/garmin-ping → Proxy adds anon key → Supabase
```

### Option 3: Contact Supabase Support

Supabase may have a way to make Edge Functions truly public (bypass gateway auth). Contact support to ask about:
- Making specific Edge Functions accessible without authentication
- Configuring functions to accept webhooks without auth headers

### Option 4: Use Webhook Secret in Path (Current Implementation)

The functions now support extracting a webhook secret from the URL path:

**Set webhook secret:**
```bash
supabase secrets set GARMIN_WEBHOOK_SECRET=your-secret-here
```

**Webhook URLs:**
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping/your-secret-here
```

**Note:** This still won't fix the 401 at the gateway level, but it adds an extra security layer once requests get through.

## Recommended Approach

Since Garmin can't include auth in webhooks, the best solution is **Option 2 (Reverse Proxy)**:

1. **Set up a simple proxy service** (Cloudflare Workers is free and easy)
2. **Proxy adds Supabase anon key** to all requests
3. **Garmin calls your proxy URL** (no auth needed)
4. **Proxy forwards to Supabase** with proper auth

This way:
- ✅ Garmin doesn't need to send auth
- ✅ Supabase gets proper auth from proxy
- ✅ You control the proxy URL
- ✅ Works with any webhook provider

## Quick Test

To verify if the gateway is the issue:

1. Try calling the function directly with curl:
```bash
curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

If you get 401, it confirms the gateway requires auth.

2. Try with anon key:
```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

If this works, it confirms the gateway needs the anon key.

## Next Steps

1. **Test if Garmin allows path segments** - Try adding a secret to the URL path in Garmin Developer Portal
2. **If path segments work** - Use Option 1 (anon key in path)
3. **If path segments don't work** - Set up Option 2 (reverse proxy)
4. **Contact Supabase** - Ask if there's a way to make functions public

