# Garmin Webhook Setup Guide

Complete guide for setting up Garmin Push Notifications (Webhooks) for your HYKA app.

## Overview

Garmin Push Notifications allow your app to receive real-time notifications when users complete activities. This eliminates the need for polling and provides instant data synchronization.

## Architecture

```
Garmin Device → Garmin Cloud → Webhook → Supabase Edge Function → Supabase Database → iOS App
```

1. User completes activity on Garmin device
2. Garmin sends webhook notification to your Supabase Edge Function
3. Edge Function fetches activity details using OAuth 1.0a
4. Activity is stored in Supabase
5. iOS app syncs with Supabase to get new activities

## Prerequisites

1. ✅ Garmin Developer Portal account
2. ✅ Garmin OAuth 1.0a application registered
3. ✅ Supabase project with Edge Functions enabled
4. ✅ Database tables: `workouts`, `oauth_connections`

## Step 1: Garmin Developer Portal Setup

### 1.1 Register Your Application

1. Go to [Garmin Developer Portal](https://developerportal.garmin.com/)
2. Navigate to **My Apps** → **Create New App**
3. Fill in application details:
   - **Application Name**: HYKA
   - **Application Type**: Web Application
   - **OAuth Version**: OAuth 1.0a
   - **Callback URL**: `https://hyka.app/garmin/callback` (or your domain)

### 1.2 Get OAuth Credentials

After creating the app, you'll receive:
- **Consumer Key** (OAuth 1.0a)
- **Consumer Secret** (OAuth 1.0a)

Save these securely - you'll need them for:
- Supabase Edge Functions environment variables
- iOS app OAuth flow

### 1.3 Request Webhook Access

1. Go to **My Apps** → Select your app
2. Navigate to **Webhooks** or **Push Notifications** section
3. Request access to Push Notifications (may require approval from Garmin)
4. Once approved, you'll see webhook configuration options

## Step 2: Configure Webhook Endpoint

### 2.1 Deploy Supabase Edge Function

1. Deploy the `garmin-webhook` function:
   ```bash
   supabase functions deploy garmin-webhook
   ```

2. Your webhook URL will be:
   ```
   https://[your-project-ref].supabase.co/functions/v1/garmin-webhook
   ```

### 2.2 Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:

- `GARMIN_CONSUMER_KEY` = Your OAuth 1.0a consumer key
- `GARMIN_CONSUMER_SECRET` = Your OAuth 1.0a consumer secret

### 2.3 Register Webhook in Garmin Portal

1. Go to **My Apps** → Select your app → **Webhooks**
2. Click **Add Webhook** or **Configure Webhook**
3. Enter your webhook URL:
   ```
   https://[your-project-ref].supabase.co/functions/v1/garmin-webhook
   ```
4. Select event types:
   - ✅ `activity.created` - New activity completed
   - ✅ `activity.updated` - Activity updated
   - ✅ `activity.deleted` - Activity deleted (optional)

5. Save configuration

## Step 3: OAuth 1.0a User Authorization

### 3.1 Update iOS App OAuth Flow

Your iOS app needs to support OAuth 1.0a for Garmin (in addition to OAuth 2.0 PKCE for other features).

The OAuth 1.0a flow:
1. Request token from Garmin
2. User authorizes app
3. Exchange for access token + token secret
4. Store both in `oauth_connections` table

### 3.2 Store OAuth 1.0a Credentials

When users connect Garmin, store:
- `access_token` - OAuth 1.0a access token
- `token_secret` - OAuth 1.0a token secret (required for webhook processing)

In your `oauth_connections` table:
```sql
INSERT INTO oauth_connections (user_id, provider, access_token, token_secret)
VALUES (user_id, 'garmin', 'oauth_token', 'oauth_token_secret');
```

## Step 4: Test Webhook

### 4.1 Test with Garmin Test Tool

1. Go to Garmin Developer Portal → **My Apps** → **Webhooks**
2. Use the **Test Webhook** feature (if available)
3. Or manually trigger a test notification

### 4.2 Monitor Logs

Check Supabase Edge Function logs:
```bash
supabase functions logs garmin-webhook
```

Or in Supabase Dashboard → Edge Functions → garmin-webhook → Logs

### 4.3 Verify Database

Check that activities are being stored:
```sql
SELECT * FROM workouts 
WHERE provider = 'garmin' 
ORDER BY created_at DESC 
LIMIT 10;
```

## Step 5: Webhook Security (Production)

### 5.1 Add Signature Verification

Garmin may provide webhook signatures. Add verification:

```typescript
// In garmin-webhook/index.ts
function verifyGarminSignature(payload: string, signature: string): boolean {
  // Implement Garmin's signature verification algorithm
  // This depends on Garmin's documentation
}
```

### 5.2 Rate Limiting

Add rate limiting to prevent abuse:
- Use Supabase Edge Function rate limiting
- Or implement custom rate limiting logic

### 5.3 IP Whitelisting (Optional)

If Garmin provides IP ranges, whitelist them in your Edge Function.

## Step 6: Handle Webhook Events

### 6.1 Activity Created

When `activity.created` event is received:
1. Fetch full activity details using OAuth 1.0a
2. Store in `workouts` table
3. Optionally: Fetch activity samples (GPS, HR, etc.)

### 6.2 Activity Updated

When `activity.updated` event is received:
1. Fetch updated activity details
2. Update existing workout record

### 6.3 Activity Deleted

When `activity.deleted` event is received:
1. Mark workout as deleted in database
2. Or remove from database (depending on your needs)

## Step 7: Token Refresh (Optional)

### 7.1 Set Up Cron Job

Create a Supabase cron job to refresh OAuth tokens:

```sql
-- In Supabase SQL Editor
SELECT cron.schedule(
  'refresh-garmin-tokens',
  '0 */6 * * *', -- Every 6 hours
  $$
  -- Call Edge Function to refresh tokens
  SELECT net.http_post(
    url := 'https://[your-project-ref].supabase.co/functions/v1/refresh-garmin-tokens',
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  $$
);
```

### 7.2 Create Refresh Function

Create `garmin-refresh-tokens` Edge Function to:
1. Get all Garmin OAuth connections
2. Refresh tokens using OAuth 1.0a refresh flow
3. Update `oauth_connections` table

## Troubleshooting

### Webhook Not Receiving Notifications

1. ✅ Verify webhook URL is correct in Garmin Portal
2. ✅ Check Supabase Edge Function logs for errors
3. ✅ Ensure webhook is enabled in Garmin Portal
4. ✅ Verify OAuth 1.0a credentials are correct

### OAuth 1.0a Signature Errors

1. ✅ Verify consumer key/secret are correct
2. ✅ Check timestamp is within 5 minutes
3. ✅ Ensure nonce is unique per request
4. ✅ Verify URL encoding matches Garmin's requirements

### Activities Not Storing

1. ✅ Check database permissions (RLS policies)
2. ✅ Verify OAuth token/secret are valid
3. ✅ Check Edge Function logs for errors
4. ✅ Verify `workouts` table schema matches expected format

## Support

- **Garmin Developer Portal**: https://developerportal.garmin.com/
- **Garmin API Documentation**: https://developerportal.garmin.com/documentation/
- **Supabase Edge Functions**: https://supabase.com/docs/guides/functions

## Next Steps

1. ✅ Deploy webhook Edge Function
2. ✅ Configure webhook in Garmin Portal
3. ✅ Test with real Garmin device
4. ✅ Monitor logs and database
5. ✅ Add signature verification (production)
6. ✅ Set up token refresh cron job (optional)

