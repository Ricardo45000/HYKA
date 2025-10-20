# ✅ Garmin Webhook Architecture (OAuth 2.0 DIAUTH)

## Overview

This is the **only** architecture Garmin officially supports for activity syncing using OAuth 2.0 (DIAUTH). All Wellness API polling has been removed.

## Architecture Flow

```
[ iOS App ]
     |
     | OAuth2 PKCE
     v
[ Garmin Authentication Server ]
     |
     | (sends userId, scope, tokens)
     v
[ Supabase: garmin_connections ]
     |
     | User uploads activity on Garmin device
     v
[ Garmin Connect ]
     |
     | PING Webhook (summary + callbackUrl)
     v
[ Supabase Function: garmin-activity-ping ]
     |
     | Extract callbackUrl → includes temporary Pull Token
     v
[ Supabase Function: garmin-activity-pull ]
     |
     | Fetch activity summary + details
     v
[ Supabase Function: garmin-activity-store ]
     |
     | Store in database
     v
[ Supabase Database ]
     |
     | garmin_activities
     | garmin_activity_samples
     v
[ HYKA App Sync ]
```

## Functions

### 1. `garmin-activity-ping`

**Purpose:** Receives PING webhook from Garmin

**Input from Garmin:**
```json
{
  "summaryId": 12345,
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "userId": "garmin_user_id"
}
```

**Actions:**
1. Extract `callbackUrl` (includes temporary Pull Token)
2. Forward to `garmin-activity-pull`
3. Return 200 OK to Garmin

**Webhook URL:** `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-ping`

---

### 2. `garmin-activity-pull`

**Purpose:** Fetch activity data from Garmin

**Input:**
```json
{
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "garminUserId": "garmin_user_id",
  "summaryId": 12345
}
```

**Actions:**
1. `GET callbackUrl` → Fetch activity summary
2. `GET callbackUrl/details` → Fetch activity details (samples)
3. Forward to `garmin-activity-store`

**Returns:**
```json
{
  "success": true,
  "summaryId": 12345,
  "samplesCount": 1500,
  "duration": "250ms"
}
```

---

### 3. `garmin-activity-store`

**Purpose:** Store activity in Supabase

**Input:**
```json
{
  "summary": { ... },
  "details": { ... },
  "garminUserId": "garmin_user_id",
  "callbackUrl": "..."
}
```

**Actions:**
1. Find HYKA user from `garminUserId` in `garmin_connections`
2. Store activity in `garmin_activities` (upsert)
3. Store samples in `garmin_activity_samples` (upsert)
4. Update `last_sync_at` timestamp

**Returns:**
```json
{
  "success": true,
  "activityId": "uuid",
  "garminActivityId": "12345",
  "samplesCount": 1500,
  "duration": "180ms"
}
```

---

## Deprecated Functions

### ❌ `garmin-activity-fetch` (DEPRECATED)

**Status:** Deprecated - Returns 410 Gone

**Reason:** Used Wellness API polling which doesn't work with OAuth 2.0 DIAUTH

**Replacement:** Webhook flow (`garmin-activity-ping` → `pull` → `store`)

---

### ❌ `garmin-historical-backfill` (DEPRECATED)

**Status:** Deprecated - Returns 410 Gone

**Reason:** Used Wellness API polling which doesn't work with OAuth 2.0 DIAUTH

**Replacement:** Use Garmin Developer Portal's official backfill tool

---

## Setup Instructions

### 1. Configure Webhook in Garmin Developer Portal

1. Go to Garmin Developer Portal
2. Navigate to your app's webhook configuration
3. Set webhook URL: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-ping`
4. Enable "Activity Upload" events
5. Save configuration

### 2. Deploy Functions

```bash
# Deploy all three functions
supabase functions deploy garmin-activity-ping
supabase functions deploy garmin-activity-pull
supabase functions deploy garmin-activity-store
```

### 3. Verify Database Tables

Ensure these tables exist:
- `garmin_connections` (stores OAuth tokens and garmin_user_id)
- `garmin_activities` (stores activity summaries)
- `garmin_activity_samples` (stores activity samples)

### 4. Test Webhook

1. Upload an activity to Garmin Connect
2. Check Supabase function logs for `garmin-activity-ping`
3. Verify activity appears in `garmin_activities` table

---

## Historical Data Backfill

### Using Garmin's Official Tool

1. Go to Garmin Developer Portal
2. Navigate to "Backfill" or "Historical Sync" section
3. Select:
   - User (or all users)
   - Date range
   - Activity types
4. Start backfill
5. Garmin will send webhooks for each historical activity
6. Activities are automatically fetched and stored

**No manual polling or date chunking needed!**

---

## Key Differences from Old Architecture

| Old (Wellness API) | New (Webhook) |
|-------------------|---------------|
| ❌ Manual polling | ✅ Automatic webhooks |
| ❌ Pull Token management | ✅ Token in callbackUrl |
| ❌ Date range chunking | ✅ Garmin handles it |
| ❌ 24h window limits | ✅ No limits |
| ❌ Doesn't work with OAuth 2.0 | ✅ Works with OAuth 2.0 |
| ❌ Rate limiting issues | ✅ No rate limits |

---

## Troubleshooting

### Webhook Not Received

1. Check Garmin Developer Portal webhook configuration
2. Verify webhook URL is correct
3. Check Supabase function logs
4. Ensure function is deployed

### Activities Not Stored

1. Check `garmin-activity-pull` logs
2. Verify `callbackUrl` is valid
3. Check `garmin-activity-store` logs
4. Verify `garmin_user_id` exists in `garmin_connections`

### Missing Samples

1. Check if `callbackUrl/details` returns data
2. Verify samples array in details response
3. Check `garmin_activity_samples` table structure

---

## OAuth Authentication (Unchanged)

The OAuth 2.0 PKCE authentication flow remains unchanged:

1. iOS app initiates OAuth flow
2. User authorizes on Garmin
3. Garmin redirects with `code`
4. `garmin-token-exchange` exchanges code for tokens
5. Tokens stored in `garmin_connections` with `garmin_user_id`

**This part works correctly and should not be modified.**

---

## Summary

✅ **Webhook-based flow** - Only method that works with OAuth 2.0  
✅ **No Pull Token management** - Token is in callbackUrl  
✅ **No manual polling** - Garmin sends webhooks automatically  
✅ **No date chunking** - Garmin handles historical data  
✅ **OAuth authentication** - Works correctly (unchanged)  

All Wellness API polling code has been removed. The system now uses the correct Garmin-approved architecture.

