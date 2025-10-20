# Garmin Official Integration - Complete Implementation

## Overview

This document describes the complete implementation of the official Garmin integration based on specifications from the Garmin Developer Team meeting.

## Architecture

```
[ iOS App ]
     |
     | OAuth 2.0 PKCE
     v
[ Garmin Auth Server ]
     |
     | Authorization Code
     v
[ garmin-auth-callback ]
     |
     | Exchange code → tokens
     | Fetch garmin_user_id
     | Store in garmin_connections
     v
[ Supabase: garmin_connections ]
     |
     | Historical Backfill
     v
[ garmin-activity-backfill ]
     |
     | Official backfill endpoint
     | summaryStartTimeInSeconds / summaryEndTimeInSeconds
     v
[ Garmin Backfill API ]
     |
     | Async processing → Webhooks
     v
[ garmin-activity-ping ] OR [ garmin-activity-push ]
     |
     | callbackUrl (PING) or full summary (PUSH)
     v
[ garmin-activity-pull ]
     |
     | GET callbackUrl → summary
     | GET callbackUrl/details → samples
     | GET callbackUrl/file → FIT file
     v
[ garmin-activity-store ]
     |
     | Store activity + samples + FIT file
     | Compute elevation from samples
     v
[ Supabase: garmin_activities + samples + fit_files ]
     |
     | iOS app reads from Supabase
     v
[ HYKA App ]
```

## Database Schema

### Tables

1. **garmin_connections**
   - Stores OAuth 2.0 tokens
   - Maps HYKA user_id to garmin_user_id
   - Tracks permission_revoked flag (certification requirement)

2. **garmin_activities**
   - Activity summaries from Garmin
   - Computed elevation gain/loss from samples
   - Device name and metadata

3. **garmin_activity_samples**
   - Per-second GPS/HR/cadence data
   - From JSON details or FIT files

4. **garmin_fit_files**
   - Raw FIT files for ultra-runner activities (>24 hours)
   - Complete data when JSON is truncated

5. **garmin_backfill_requests**
   - Tracks backfill requests to prevent duplicates (HTTP 409)

## Edge Functions

### 1. garmin-auth-callback
**Purpose:** Receives OAuth2 redirect, exchanges code for tokens, stores connection

**Flow:**
1. Receive `code`, `code_verifier`, `redirect_uri`, `user_id` from iOS app
2. Exchange code for `access_token` + `refresh_token`
3. Fetch Garmin user ID from `/rest/user/id`
4. Store in `garmin_connections` table
5. Return success to iOS app

**Endpoint:** `POST /functions/v1/garmin-auth-callback`

**Request:**
```json
{
  "code": "authorization_code",
  "code_verifier": "code_verifier",
  "redirect_uri": "https://hyka.app/garmin/callback",
  "user_id": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "garmin_user_id": "garmin_user_id",
  "connection_id": "uuid"
}
```

---

### 2. garmin-activity-backfill
**Purpose:** Request historical activity data using official backfill endpoint

**Flow:**
1. Receive `user_id` and optional date range
2. Lookup Garmin `access_token` from `garmin_connections`
3. Calculate date range (default: last 30 days from connection date)
4. Call official endpoint: `GET /rest/backfill/activities`
5. Garmin responds with 202 Accepted (async)
6. Garmin sends webhooks as backfill completes

**Endpoint:** `POST /functions/v1/garmin-activity-backfill`

**Request:**
```json
{
  "user_id": "uuid",
  "summary_start_time_seconds": 1452384000,  // Optional
  "summary_end_time_seconds": 1453248000    // Optional
}
```

**Response:**
```json
{
  "success": true,
  "message": "Backfill request accepted",
  "status": "pending",
  "summary_start_time_seconds": 1452384000,
  "summary_end_time_seconds": 1453248000,
  "days": 10.5,
  "note": "Garmin will process this asynchronously. Webhooks will be sent as activities are processed."
}
```

**Important:**
- Maximum 30 days per request
- Returns 202 Accepted (async processing)
- Returns 409 Conflict for duplicate requests
- Uses `summaryStartTimeInSeconds` (NOT upload timestamps)
- No Pull Token needed (uses OAuth 2.0 access token)

---

### 3. garmin-activity-ping
**Purpose:** Receives PING webhooks from Garmin

**Flow:**
1. Receive PING with `callbackUrl`, `summaryId`, `userId`
2. Extract `callbackUrl` (includes temporary Pull Token)
3. Forward to `garmin-activity-pull`
4. Return 200 OK to Garmin

**Webhook URL:** `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping`

**PING Payload:**
```json
{
  "summaryId": 12345,
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "userId": "garmin_user_id"
}
```

---

### 4. garmin-activity-push
**Purpose:** Receives PUSH webhooks from Garmin with full activity data

**Flow:**
1. Receive PUSH with `garminUserId` + activities array (full summaries)
2. Look up HYKA user from `garminUserId`
3. For each activity:
   - Forward summary to `garmin-activity-store`
   - Optionally fetch details/FIT file if `callbackUrl` available
4. Return 200 OK to Garmin

**Webhook URL:** `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push`

**PUSH Payload:**
```json
{
  "userId": "garmin_user_id",
  "activities": [
    {
      "summaryId": 12345,
      "activityType": "Running",
      "startTimeInSeconds": 1452384000,
      "durationInSeconds": 3600,
      "distanceInMeters": 10000,
      "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ"  // Optional
    }
  ]
}
```

---

### 5. garmin-activity-pull
**Purpose:** Fetch activity data from Garmin using callbackUrl

**Flow:**
1. Receive `callbackUrl` (includes temporary Pull Token)
2. Fetch activity summary: `GET callbackUrl`
3. Fetch activity details: `GET callbackUrl/details` (samples)
4. Fetch FIT file: `GET callbackUrl/file` (for ultra-runners)
5. Forward to `garmin-activity-store`

**Endpoint:** `POST /functions/v1/garmin-activity-pull`

**Request:**
```json
{
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "garminUserId": "garmin_user_id",
  "summaryId": 12345
}
```

---

### 6. garmin-activity-store
**Purpose:** Store activity data in Supabase database

**Flow:**
1. Receive summary, details, FIT file data
2. Find HYKA user from `garminUserId`
3. Compute elevation gain/loss from samples (more accurate than summary)
4. Store activity in `garmin_activities`
5. Store samples in `garmin_activity_samples`
6. Store FIT file in `garmin_fit_files` (if available)
7. Trigger FIT processor (async) if FIT file present

**Endpoint:** `POST /functions/v1/garmin-activity-store`

**Request:**
```json
{
  "summary": { /* activity summary */ },
  "details": { /* activity details with samples */ },
  "garminUserId": "garmin_user_id",
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "fitFileData": [ /* Uint8Array as array */ ]
}
```

**Features:**
- Computes elevation gain/loss from samples (for ultra-runner accuracy)
- Handles FIT files for activities >24 hours
- Deduplication via unique constraints
- Updates `last_sync_at` timestamp

---

### 7. garmin-permission-webhook
**Purpose:** Handles Garmin webhooks for registration, permission changes, deregistration

**Flow:**
1. Receive webhook from Garmin
2. Parse webhook type: `registration`, `permission_revoked`, `deregistration`
3. Update `garmin_connections` table accordingly
4. Return 200 OK to Garmin

**Webhook URL:** `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook`

**Webhook Types:**
- `registration`: User connected (already handled in auth-callback)
- `permission_revoked`: User removed permissions (set `permission_revoked = true`)
- `deregistration`: User disconnected (delete connection)

**Required for certification!**

---

### 8. garmin-fit-processor
**Purpose:** Parse FIT files for ultra-runner activities (>24 hours)

**Flow:**
1. Receive `activity_id` and FIT file data
2. Parse FIT file using FIT parser library
3. Extract samples (GPS, HR, elevation, cadence, temperature)
4. Compute accurate elevation gain/loss from samples
5. Store samples in `garmin_activity_samples`
6. Update activity with computed elevation

**Endpoint:** `POST /functions/v1/garmin-fit-processor`

**Request:**
```json
{
  "activity_id": "uuid",
  "fit_file_data": [ /* Uint8Array as array */ ]
}
```

**Note:** FIT parser library integration required. See function comments for details.

---

## Key Differences from Previous Implementation

### ❌ Removed (Invalid for OAuth 2.0)
- Wellness API polling (`/rest/activities` with date ranges)
- `uploadStartTimeInSeconds` / `uploadEndTimeInSeconds` parameters
- 24-hour chunking logic
- Persistent Pull Token refresh
- Daily Pull Token extraction
- Wellness `/rest/activities` endpoints (for historical data)
- Connect API `/activity-service/*` endpoints

### ✅ Added (Official Specification)
- Official backfill endpoint: `/rest/backfill/activities`
- `summaryStartTimeInSeconds` / `summaryEndTimeInSeconds` parameters
- FIT file support for ultra-runners
- Permission webhook handling (certification requirement)
- Elevation computation from samples
- Backfill request deduplication

---

## Deployment Steps

### 1. Database Migration
```sql
-- Run garmin_official_schema.sql
-- This creates all required tables, views, and RPC functions
```

### 2. Deploy Edge Functions
```bash
cd supabase/functions

# Core functions
supabase functions deploy garmin-auth-callback
supabase functions deploy garmin-activity-backfill
supabase functions deploy garmin-activity-ping
supabase functions deploy garmin-activity-push
supabase functions deploy garmin-activity-pull
supabase functions deploy garmin-activity-store
supabase functions deploy garmin-permission-webhook
supabase functions deploy garmin-fit-processor
```

### 3. Configure Garmin Developer Portal

**Webhook URLs:**
- Activity PING: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping`
- Activity PUSH: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push`
- Permission Webhook: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook`

**OAuth 2.0 Settings:**
- Client ID: `695055f8-9786-4fda-a3a7-f7c2e88382f0`
- Redirect URI: `https://hyka.app/garmin/callback`
- Scopes: `ACTIVITY_EXPORT`, `HEALTH_EXPORT`, `WORKOUT_IMPORT`

### 4. Set Environment Variables
```bash
supabase secrets set GARMIN_CLIENT_SECRET=your_secret_here
```

### 5. Update iOS App
- Update `DeviceOAuthManager.swift` to call `garmin-auth-callback` instead of `garmin-token-exchange`
- Pass `user_id` in request body

---

## Testing

### 1. OAuth Flow
1. User connects Garmin in iOS app
2. Verify connection stored in `garmin_connections`
3. Verify `garmin_user_id` is stored

### 2. Historical Backfill
1. Call `garmin-activity-backfill` with `user_id`
2. Verify 202 Accepted response
3. Wait for webhooks (may take time)
4. Verify activities appear in `garmin_activities`

### 3. New Activities
1. Upload activity to Garmin Connect
2. Verify webhook received (PING or PUSH)
3. Verify activity stored in `garmin_activities`
4. Verify samples stored in `garmin_activity_samples`

### 4. Ultra-Runner Activities (>24 hours)
1. Upload long activity (>24 hours)
2. Verify FIT file fetched and stored
3. Verify FIT processor triggered
4. Verify samples extracted from FIT file

---

## Rate Limits

### Backfill
- **Evaluation keys:** 100 days of data per minute
- **Production keys:** 10,000 days of data per minute
- **User limit:** 1 month since first connection

### Best Practices
- Request backfill in 30-day chunks
- Use incremental sync for new activities (webhooks)
- Store backfill requests to prevent duplicates (HTTP 409)

---

## FIT File Processing

### Current Status
- FIT files are stored in `garmin_fit_files` table
- FIT processor function exists but requires FIT parser library integration

### Next Steps
1. Choose FIT parser library compatible with Deno
2. Integrate parser in `garmin-fit-processor`
3. Extract samples from FIT files
4. Compute elevation from FIT samples
5. Update activities with computed elevation

### Recommended Libraries
- JavaScript FIT parser (e.g., `fit-file-parser`)
- Garmin FIT SDK via WebAssembly
- External FIT parsing service

---

## Certification Requirements

### Required Webhooks
1. **Registration:** User connects (handled in `garmin-auth-callback`)
2. **Permission Revoked:** User removes permissions (handled in `garmin-permission-webhook`)
3. **Deregistration:** User disconnects (handled in `garmin-permission-webhook`)

### Unregistration Endpoint
When user disconnects in iOS app, must call:
```
DELETE https://apis.garmin.com/wellness-api/rest/user/unregister
```

**Failure to implement this will break certification!**

---

## Support

For issues or questions:
1. Check Edge Function logs in Supabase Dashboard
2. Verify webhook URLs in Garmin Developer Portal
3. Check database tables for stored data
4. Review Garmin Activity API 1.2.3 documentation

---

## References

- **Activity API 1.2.3:** https://developerportal.garmin.com/sites/default/files/Activity_API-1.2.3_0.pdf
- **OAuth 2.0 PKCE:** https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf
- **Garmin Developer Portal:** https://developerportal.garmin.com/

---

**Last Updated:** Based on official Garmin Developer Team specifications

