# Garmin Webhook Receiver

This Supabase Edge Function receives push notifications from Garmin when new activities are created.

## Overview

When a user completes an activity on their Garmin device, Garmin sends a webhook notification to this endpoint. The function then:

1. Receives the webhook payload with activity ID and OAuth credentials
2. Fetches full activity details from Garmin Activity API using OAuth 1.0a
3. Stores the activity in Supabase `workouts` table

## Setup

### 1. Environment Variables

Set these in Supabase Dashboard → Project Settings → Edge Functions → Secrets:

- `GARMIN_CONSUMER_KEY` - Your Garmin OAuth 1.0a consumer key
- `GARMIN_CONSUMER_SECRET` - Your Garmin OAuth 1.0a consumer secret
- `SUPABASE_URL` - Automatically available
- `SUPABASE_SERVICE_ROLE_KEY` - Automatically available (for bypassing RLS)

### 2. Deploy

```bash
supabase functions deploy garmin-webhook
```

Or deploy via Supabase Dashboard.

### 3. Webhook URL

After deployment, your webhook URL will be:
```
https://[your-project-ref].supabase.co/functions/v1/garmin-webhook
```

Use this URL when configuring webhooks in Garmin Developer Portal.

## Webhook Payload

Garmin sends a POST request with JSON payload:

```json
{
  "activityId": "123456789",
  "activityName": "Morning Run",
  "userAccessToken": "oauth_token",
  "userTokenSecret": "oauth_token_secret",
  "userId": "optional-user-id",
  "eventType": "activity.created",
  "timestamp": "2025-01-15T10:30:00Z"
}
```

## Response

Success (200):
```json
{
  "success": true,
  "activityId": "123456789",
  "message": "Activity processed successfully"
}
```

Error (400/404/500):
```json
{
  "error": "Error message"
}
```

## Security

⚠️ **Important**: In production, add webhook signature verification to ensure requests are from Garmin. The current implementation trusts all requests to this endpoint.

## Database Schema

The function stores activities in the `workouts` table with the following mapping:

- `provider` = 'garmin'
- `provider_activity_id` = activity ID from Garmin
- `name` = activity name
- `distance_m` = distance in meters
- `elapsed_seconds` = duration
- `activity_type_code` = activity type (running, hiking, walking, etc.)
- `start_time` = activity start time
- `average_heart_rate` / `max_heart_rate` = HR data
- `calories` = calories burned
- `elevation_gain_m` / `elevation_loss_m` = elevation data
- `average_speed_mps` / `max_speed_mps` = speed data

