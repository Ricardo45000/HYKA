# Garmin OAuth 1.0a Activity Fetcher

This Supabase Edge Function fetches individual activity details from Garmin Activity API using OAuth 1.0a.

## Overview

This function is called when:
- A webhook notification is received and needs to fetch activity details
- Manual sync is triggered from the iOS app
- Activity details need to be refreshed

## Setup

### 1. Environment Variables

Set these in Supabase Dashboard → Project Settings → Edge Functions → Secrets:

- `GARMIN_CONSUMER_KEY` - Your Garmin OAuth 1.0a consumer key
- `GARMIN_CONSUMER_SECRET` - Your Garmin OAuth 1.0a consumer secret
- `SUPABASE_URL` - Automatically available
- `SUPABASE_ANON_KEY` - Automatically available

### 2. Deploy

```bash
supabase functions deploy garmin-oauth1-activity
```

## Usage

### Request

```bash
POST https://[your-project-ref].supabase.co/functions/v1/garmin-oauth1-activity
Authorization: Bearer [user-jwt-token]
Content-Type: application/json

{
  "activityId": "123456789"
}
```

### Response

Success (200):
```json
{
  "success": true,
  "activity": {
    "activityId": "123456789",
    "activityName": "Morning Run",
    "activityType": {
      "typeId": 1,
      "typeKey": "running"
    },
    "startTimeGMT": "2025-01-15T10:30:00Z",
    "distance": 5000,
    "duration": 1800,
    "averageHR": 145,
    "maxHR": 165,
    ...
  }
}
```

Error (400/401/404/500):
```json
{
  "error": "Error message"
}
```

## Authentication

The function requires:
1. Valid Supabase JWT token in `Authorization` header
2. User must have a Garmin OAuth 1.0a connection stored in `oauth_connections` table
3. The connection must have both `access_token` and `token_secret` (OAuth 1.0a credentials)

## Database Requirements

The function reads from `oauth_connections` table:
- `user_id` - Matches authenticated user
- `provider` = 'garmin'
- `access_token` - OAuth 1.0a access token
- `token_secret` - OAuth 1.0a token secret

