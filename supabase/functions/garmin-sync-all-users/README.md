# Garmin Sync All Users

Supabase Edge Function that periodically syncs Garmin activities for all connected users.

## Overview

This function:
- Fetches all users with Garmin OAuth 2.0 connections
- Retrieves new activities from Garmin API (using OAuth 2.0 Bearer tokens)
- Stores activities in Supabase `workouts` table
- Filters to only running, hiking, and walking activities

## Setup

### 1. Deploy Function

```bash
supabase functions deploy garmin-sync-all-users
```

### 2. Set Up Cron Job

In Supabase SQL Editor:

```sql
SELECT cron.schedule(
  'sync-garmin-activities',
  '0 */6 * * *', -- Every 6 hours
  $$
  SELECT
    net.http_post(
      url := 'https://[your-project-ref].supabase.co/functions/v1/garmin-sync-all-users',
      headers := '{"Content-Type": "application/json"}'::jsonb
    ) AS request_id;
  $$
);
```

### 3. Test Manually

```bash
curl -X POST https://[your-project-ref].supabase.co/functions/v1/garmin-sync-all-users \
  -H "Content-Type: application/json"
```

## Response

```json
{
  "success": true,
  "totalUsers": 5,
  "totalSynced": 12,
  "results": [
    {
      "userId": "user-uuid",
      "success": true,
      "count": 3
    }
  ]
}
```

## How It Works

1. Gets all `oauth_connections` where `provider = 'garmin'` and `token_secret IS NULL` (OAuth 2.0)
2. For each user:
   - Gets last sync timestamp (most recent workout)
   - Fetches new activities from Garmin API
   - Stores new activities in `workouts` table
3. Returns summary of sync results

## Rate Limiting

The function includes a 1-second delay between users to avoid rate limiting. Adjust if needed.

## Monitoring

View logs:
```bash
supabase functions logs garmin-sync-all-users
```

