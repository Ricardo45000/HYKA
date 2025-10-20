# Garmin Webhook Deployment Guide

## Quick Start

### 1. Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:

```
GARMIN_CONSUMER_KEY=your_consumer_key_here
GARMIN_CONSUMER_SECRET=your_consumer_secret_here
```

### 2. Deploy Function

```bash
supabase functions deploy garmin-webhook
```

Or via Supabase Dashboard:
1. Go to Edge Functions
2. Click "Deploy new function"
3. Upload the `garmin-webhook` folder

### 3. Get Webhook URL

After deployment, your webhook URL is:
```
https://[your-project-ref].supabase.co/functions/v1/garmin-webhook
```

Use this URL in Garmin Developer Portal when configuring webhooks.

## Testing

### Test Locally (Optional)

```bash
supabase functions serve garmin-webhook --env-file .env.local
```

### Test with cURL

```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/garmin-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "activityId": "123456789",
    "userAccessToken": "test_token",
    "userTokenSecret": "test_secret",
    "userId": "test-user-id"
  }'
```

## Monitoring

View logs:
```bash
supabase functions logs garmin-webhook
```

Or in Supabase Dashboard → Edge Functions → garmin-webhook → Logs

