# Garmin Webhook Configuration - Quick Reference

## Quick Steps

1. **Login**: https://developerportal.garmin.com/
2. **Navigate**: My Apps → [Your App] → Webhooks
3. **Add Webhook**: Click "Add Webhook" or "Configure Webhook"
4. **Enter URL**: `https://[your-project-ref].supabase.co/functions/v1/garmin-webhook`
5. **Select Events**: ✅ activity.created, ✅ activity.updated
6. **Save**: Click "Save" or "Create Webhook"

## Your Webhook URL

Replace `[your-project-ref]` with your Supabase project reference:

```
https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-webhook
```

## Required Environment Variables

In Supabase Dashboard → Edge Functions → Secrets:

```
GARMIN_CONSUMER_KEY=your_consumer_key
GARMIN_CONSUMER_SECRET=your_consumer_secret
```

## Test Your Webhook

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

## Check Logs

```bash
supabase functions logs garmin-webhook
```

## Verify Database

```sql
SELECT * FROM workouts 
WHERE provider = 'garmin' 
ORDER BY created_at DESC 
LIMIT 10;
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Webhook not appearing | Request access from Garmin |
| Status: Failed | Check Supabase logs, verify URL |
| Not receiving notifications | Verify OAuth 1.0a credentials stored |
| Access Denied | Wait for webhook approval (1-3 days) |

## Full Guide

See `GARMIN_WEBHOOK_CONFIGURATION_GUIDE.md` for detailed instructions.

