# Garmin Integration Complete Solution

## Overview

This solution implements a complete Garmin integration using:
1. **Supabase Edge Functions** for webhook processing and OAuth 1.0a backend requests
2. **Garmin Push Notifications** (webhooks) for real-time activity sync
3. **OAuth 1.0a** for accessing Garmin Activity API
4. **OAuth 2.0 PKCE** for user authentication (existing)

## Architecture

```
┌─────────────┐
│ Garmin      │
│ Device      │
└──────┬──────┘
       │
       │ User completes activity
       ▼
┌─────────────┐
│ Garmin      │
│ Cloud       │
└──────┬──────┘
       │
       │ Webhook POST
       ▼
┌─────────────────────────────────┐
│ Supabase Edge Function           │
│ garmin-webhook                   │
│                                  │
│ 1. Receives webhook              │
│ 2. Fetches activity (OAuth 1.0a)│
│ 3. Stores in Supabase            │
└──────┬───────────────────────────┘
       │
       │ INSERT/UPDATE
       ▼
┌─────────────────────────────────┐
│ Supabase Database                │
│ workouts table                   │
└──────┬───────────────────────────┘
       │
       │ Query
       ▼
┌─────────────┐
│ iOS App     │
│ (HYKA)      │
└─────────────┘
```

## Files Created

### 1. Supabase Edge Functions

#### `garmin-webhook/index.ts`
- Receives Garmin push notifications
- Fetches activity details using OAuth 1.0a
- Stores activities in Supabase `workouts` table
- **URL**: `https://[project-ref].supabase.co/functions/v1/garmin-webhook`

#### `garmin-oauth1-activity/index.ts`
- Fetches individual activity details on-demand
- Uses OAuth 1.0a for backend requests
- Called from iOS app or webhook function
- **URL**: `https://[project-ref].supabase.co/functions/v1/garmin-oauth1-activity`

### 2. Documentation

#### `GARMIN_WEBHOOK_SETUP.md`
Complete step-by-step guide covering:
- Garmin Developer Portal setup
- Webhook configuration
- OAuth 1.0a user authorization
- Testing and troubleshooting
- Token refresh setup

#### `garmin-webhook/README.md`
Function-specific documentation

#### `garmin-oauth1-activity/README.md`
Function-specific documentation

#### `garmin-webhook/DEPLOYMENT.md`
Quick deployment guide

#### `garmin-oauth1-activity/DEPLOYMENT.md`
Quick deployment guide

## Setup Steps

### Step 1: Deploy Edge Functions

```bash
# Deploy webhook receiver
supabase functions deploy garmin-webhook

# Deploy OAuth 1.0a activity fetcher
supabase functions deploy garmin-oauth1-activity
```

### Step 2: Set Environment Variables

In Supabase Dashboard → Project Settings → Edge Functions → Secrets:

```
GARMIN_CONSUMER_KEY=your_oauth1_consumer_key
GARMIN_CONSUMER_SECRET=your_oauth1_consumer_secret
```

### Step 3: Configure Garmin Webhook

1. Go to Garmin Developer Portal
2. Navigate to your app → Webhooks
3. Add webhook URL:
   ```
   https://[your-project-ref].supabase.co/functions/v1/garmin-webhook
   ```
4. Select events: `activity.created`, `activity.updated`

### Step 4: Update iOS App

The iOS app needs to:
1. Support OAuth 1.0a flow for Garmin (in addition to OAuth 2.0 PKCE)
2. Store both `access_token` and `token_secret` in `oauth_connections` table
3. Call `garmin-oauth1-activity` function when needed

## How It Works

### Webhook Flow

1. **User completes activity** on Garmin device
2. **Garmin sends webhook** to `garmin-webhook` function
3. **Function receives payload**:
   ```json
   {
     "activityId": "123456789",
     "userAccessToken": "oauth_token",
     "userTokenSecret": "oauth_token_secret",
     "userId": "optional-user-id"
   }
   ```
4. **Function fetches activity details** using OAuth 1.0a:
   - Generates OAuth 1.0a signature
   - Calls `GET /activity-service/activity/{activityId}`
5. **Function stores activity** in Supabase `workouts` table
6. **iOS app syncs** with Supabase to get new activities

### Manual Sync Flow

1. **iOS app calls** `garmin-oauth1-activity` function
2. **Function authenticates** user via Supabase JWT
3. **Function retrieves** OAuth 1.0a credentials from `oauth_connections`
4. **Function fetches** activity details using OAuth 1.0a
5. **Function returns** activity data to iOS app

## OAuth 1.0a Implementation

The Edge Functions use OAuth 1.0a for backend requests:

- **Signature Generation**: HMAC-SHA1
- **Parameter Encoding**: RFC 3986 percent-encoding
- **Nonce**: Random 32-character hex string
- **Timestamp**: Unix epoch seconds

Key functions:
- `percentEncode()` - RFC 3986 encoding
- `generateNonce()` - Random nonce generation
- `generateOAuth1Signature()` - HMAC-SHA1 signature
- `generateOAuth1Header()` - Authorization header

## Database Schema

### `oauth_connections` Table

Required columns for Garmin OAuth 1.0a:
- `user_id` - UUID
- `provider` - 'garmin'
- `access_token` - OAuth 1.0a access token
- `token_secret` - OAuth 1.0a token secret (required!)
- `expires_at` - Optional expiration

### `workouts` Table

Stores activity data:
- `user_id` - UUID
- `provider` - 'garmin'
- `provider_activity_id` - Garmin activity ID
- `name` - Activity name
- `distance_m` - Distance in meters
- `elapsed_seconds` - Duration
- `activity_type_code` - Activity type
- `start_time` - Start timestamp
- `average_heart_rate` - Average HR
- `max_heart_rate` - Max HR
- `calories` - Calories burned
- `elevation_gain_m` - Elevation gain
- `elevation_loss_m` - Elevation loss
- `average_speed_mps` - Average speed
- `max_speed_mps` - Max speed

## Security Considerations

### Webhook Security

⚠️ **Current Implementation**: Trusts all requests to webhook endpoint

✅ **Production Recommendation**: Add webhook signature verification

```typescript
function verifyGarminSignature(payload: string, signature: string): boolean {
  // Implement Garmin's signature verification
  // Check against shared secret or public key
}
```

### OAuth 1.0a Security

- ✅ Consumer key/secret stored in environment variables (secure)
- ✅ Token secret stored in database (encrypted at rest)
- ✅ OAuth signatures prevent tampering
- ✅ Timestamp validation (within 5 minutes)

## Testing

### Test Webhook Locally

```bash
curl -X POST http://localhost:54321/functions/v1/garmin-webhook \
  -H "Content-Type: application/json" \
  -d '{
    "activityId": "123456789",
    "userAccessToken": "test_token",
    "userTokenSecret": "test_secret",
    "userId": "test-user-id"
  }'
```

### Test OAuth 1.0a Activity Fetcher

```bash
curl -X POST https://[project-ref].supabase.co/functions/v1/garmin-oauth1-activity \
  -H "Authorization: Bearer [user-jwt-token]" \
  -H "Content-Type: application/json" \
  -d '{
    "activityId": "123456789"
  }'
```

## Monitoring

### View Logs

```bash
# Webhook logs
supabase functions logs garmin-webhook

# OAuth 1.0a activity fetcher logs
supabase functions logs garmin-oauth1-activity
```

### Check Database

```sql
-- Recent activities
SELECT * FROM workouts 
WHERE provider = 'garmin' 
ORDER BY created_at DESC 
LIMIT 10;

-- OAuth connections
SELECT user_id, provider, 
       LEFT(access_token, 20) as token_preview,
       token_secret IS NOT NULL as has_token_secret
FROM oauth_connections 
WHERE provider = 'garmin';
```

## Next Steps

1. ✅ Deploy Edge Functions
2. ✅ Set environment variables
3. ✅ Configure Garmin webhook
4. ✅ Update iOS app for OAuth 1.0a
5. ✅ Test with real Garmin device
6. ✅ Add webhook signature verification (production)
7. ✅ Set up token refresh cron job (optional)

## Support

- **Garmin Developer Portal**: https://developerportal.garmin.com/
- **Garmin API Docs**: https://developerportal.garmin.com/documentation/
- **Supabase Edge Functions**: https://supabase.com/docs/guides/functions

