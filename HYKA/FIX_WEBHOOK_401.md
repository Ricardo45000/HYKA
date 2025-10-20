# Fix: 401 Unauthorized on Garmin Webhook

## Problem

Garmin webhook is getting **401 Unauthorized** because Supabase Edge Functions require authentication by default.

**Error:**
```
POST | 401 | /functions/v1/garmin-activity-ping
User-Agent: Garmin Health API
```

## Solution: Add Anon Key to Webhook URL

Supabase Edge Functions require either:
1. `Authorization: Bearer TOKEN` header, OR
2. `?apikey=ANON_KEY` query parameter

Since Garmin doesn't send auth headers, add the anon key to the webhook URL.

---

## Steps to Fix

### 1. Get Your Anon Key

From Supabase Dashboard:
- Go to **Settings** → **API**
- Copy the **anon/public** key

Or from your code:
```swift
// From SupabaseClient.swift
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w"
```

### 2. Update Webhook URL in Garmin Developer Portal

**Current URL (causing 401):**
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping
```

**New URL (with anon key):**
```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3NjYyNTgsImV4cCI6MjA3NjM0MjI1OH0.pOSv9o4_xIg-GCozVMEocp2K27fTDzP_-aG2WPm9j1w
```

### 3. Update Function to Extract Anon Key

The function will automatically receive the `apikey` query parameter. Supabase will validate it before the function code runs.

### 4. Redeploy Function (Optional)

If you made code changes, redeploy:
```bash
supabase functions deploy garmin-activity-ping
```

---

## Alternative: Use Secret Token (More Secure)

If you want better security, use a secret token:

### 1. Set Secret in Supabase

```bash
supabase secrets set GARMIN_WEBHOOK_SECRET=your-secret-token-here
```

### 2. Update Webhook URL

```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping?token=your-secret-token-here
```

### 3. Validate in Function

```typescript
const url = new URL(req.url)
const token = url.searchParams.get('token')
const secret = Deno.env.get('GARMIN_WEBHOOK_SECRET')

if (token !== secret) {
  return new Response("Unauthorized", { status: 401 })
}
```

---

## Why This Happens

Supabase Edge Functions are protected by default. They require:
- Authentication header, OR
- Anon key in query parameter, OR
- Service role key (for internal calls)

Garmin webhooks don't send auth headers, so we use the anon key in the URL.

**Security:** The webhook URL itself is secret (only you and Garmin know it), so using the anon key is acceptable for webhooks.

---

## Test

After updating the webhook URL:

1. Upload activity to Garmin Connect
2. Check Supabase logs - should see **200 OK** instead of 401
3. Verify activity appears in `garmin_activities` table

---

## Current Status

✅ Function code updated (handles CORS, validates user-agent)  
⚠️ **Action needed:** Update webhook URL in Garmin Developer Portal with anon key

