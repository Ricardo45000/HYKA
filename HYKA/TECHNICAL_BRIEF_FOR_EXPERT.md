# Technical Brief: HYKA Garmin Integration Issue

## 🎯 Project Overview

**HYKA** is an iOS race planning application for ultra-marathon runners. It helps athletes:
- Plan race strategies with GPX route analysis
- Calculate pacing, nutrition, and fueling strategies
- Integrate with fitness devices (Garmin, Coros, Suunto, Polar) to pull training data
- Display historical workouts and health metrics

**Tech Stack:**
- **Frontend**: iOS app (Swift/SwiftUI, iOS 17+)
- **Backend**: Supabase (PostgreSQL + Edge Functions in Deno/TypeScript)
- **APIs**: Garmin Connect API (OAuth 2.0 PKCE), Tomorrow.io (weather)

---

## 🏗️ Architecture

### Current Flow (Garmin Integration)

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  iOS App    │────────▶│ Supabase     │────────▶│  Garmin     │
│  (Swift)    │ OAuth 2 │ Edge Function│ OAuth 2 │  Connect    │
│             │◀────────│              │◀────────│  API        │
└─────────────┘         └──────────────┘         └─────────────┘
      │                        │                        │
      │                        │                        │
      ▼                        ▼                        ▼
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│  Supabase   │◀────────│  Webhooks     │◀────────│  Garmin     │
│  Database   │  Store  │  (Push/Ping)  │  Notify │  (Activity  │
│             │  Data   │               │         │   Upload)   │
└─────────────┘         └──────────────┘         └─────────────┘
```

### Key Components

1. **iOS App** (`ios/`)
   - OAuth 2.0 PKCE flow for Garmin authentication
   - Calls Supabase Edge Function `garmin-auth-callback` to exchange code for tokens
   - Reads activity data from Supabase (never calls Garmin APIs directly)

2. **Supabase Edge Functions** (`supabase/functions/`)
   - `garmin-auth-callback`: Handles OAuth token exchange, stores connection
   - `garmin-activity-push`: Receives webhooks when activities are uploaded
   - `garmin-activity-ping`: Receives ping notifications
   - `garmin-activity-backfill`: Requests historical data
   - `garmin-health-webhook`: Receives health metrics
   - `garmin-permission-webhook`: Handles permission revocations

3. **Supabase Database**
   - `garmin_connections`: Stores OAuth tokens and user mapping
   - `garmin_activities`: Activity summaries
   - `garmin_activity_samples`: Detailed track points (GPS, HR, etc.)
   - `unified_activities`: View that combines all activity sources

---

## 🔴 Current Blockage / Problem

### Primary Issue
**Garmin activities are not being synced into Supabase despite successful OAuth connection.**

### Symptoms
1. ✅ OAuth 2.0 connection succeeds (user can authenticate)
2. ✅ Tokens are stored in `garmin_connections` table
3. ✅ `garmin_user_id` is retrieved and stored
4. ❌ **No activities appear in `garmin_activities` table**
5. ❌ **Webhooks are not being triggered** (or are failing silently)
6. ❌ **Backfill requests return empty arrays**

### What We Know Works
- OAuth 2.0 PKCE authentication flow completes successfully
- Access tokens and refresh tokens are stored
- Edge Functions are deployed and accessible
- Database schema is correct
- RLS policies allow service role access

### What Doesn't Work
- Activities are not being fetched from Garmin
- Webhooks are not being received (or are failing)
- Backfill requests return empty results even when activities exist in Garmin Connect

---

## 🔍 Technical Details

### Garmin API Configuration

**OAuth 2.0 Setup:**
- **Client ID**: `695055f8-9786-4fda-a3a7-f7c2e88382f0`
- **Redirect URI**: `com.hyka.app://callback`
- **Authorization URL**: `https://connect.garmin.com/oauth2Confirm`
- **Token Exchange URL**: `https://diauth.garmin.com/di-oauth2-service/oauth/token`
- **Client Secret**: Stored in Supabase Edge Function secrets (not in code)

**API Endpoints Used:**
- **Wellness API** (OAuth 2.0 Bearer token):
  - `GET /rest/activities` - List activities (requires Pull Token)
  - `GET /rest/activityDetails` - Get activity details + samples
  - `GET /rest/user/id` - Get Garmin user ID
  - `GET /rest/backfill/activities` - Request historical data

**Webhook Configuration:**
- **Activity PUSH**: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-push`
- **Activity PING**: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-ping`
- **Health Webhook**: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-health-webhook`
- **Permission Webhook**: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-permission-webhook`

### Critical Issue: Pull Token

**The Problem:**
- Garmin Wellness API requires a **Pull Token** for OAuth 2.0 integrations
- Pull Token is temporary (24 hours) and must be obtained from Garmin Developer Portal
- Pull Token must be passed as query parameter: `?token=CPT1763250098.9HZ__7xckH4`

**Current Implementation:**
- Pull Token is NOT being stored or used consistently
- Some Edge Functions try to use Pull Token but it's not available
- No mechanism to automatically refresh Pull Token

**What's Needed:**
- Either: Implement Pull Token management (store in database, refresh daily)
- Or: Use OAuth 1.0a for data access (but Garmin says OAuth 2.0 only for new apps)

---

## 🐛 Specific Error Patterns

### 1. Wellness API Errors
```
InvalidPullTokenException failure
```
- **Cause**: Pull Token missing or expired
- **Location**: `garmin-activity-backfill`, `garmin-activity-push`
- **Impact**: Cannot fetch activities

### 2. Empty Activity Lists
```
GET /rest/activities?token=XXX&startDate=...&endDate=...
Response: []
```
- **Cause**: 
  - Pull Token invalid
  - Date range issues
  - OAuth token permissions insufficient
- **Impact**: No activities synced

### 3. Webhook Not Receiving Data
- **Expected**: Garmin sends webhook when activity is uploaded
- **Reality**: Webhooks may not be configured correctly in Garmin Developer Portal
- **Impact**: Real-time sync doesn't work

### 4. Backfill Returns Empty
```
GET /rest/backfill/activities?summaryStartTimeInSeconds=...&summaryEndTimeInSeconds=...
Response: 202 Accepted (but no data arrives via webhooks)
```
- **Cause**: Backfill is async, but webhooks aren't triggering
- **Impact**: Historical data not retrieved

---

## 🔧 What's Been Tried

### Attempted Solutions

1. **OAuth 1.0a Implementation**
   - Tried using OAuth 1.0a HMAC-SHA1 signatures
   - Garmin rejected: "OAuth 2.0 only for new apps"
   - **Status**: Abandoned

2. **OAuth 2.0 with Pull Token**
   - Implemented Pull Token in requests
   - Token expires every 24 hours
   - **Status**: Partially working, but token management is manual

3. **Webhook-Based Architecture**
   - Set up webhook endpoints
   - Configured in Garmin Developer Portal
   - **Status**: Webhooks may not be triggering

4. **Backfill for Historical Data**
   - Implemented `/rest/backfill/activities` endpoint
   - **Status**: Returns 202 but no data arrives

5. **Direct API Calls from iOS**
   - Tried calling Garmin APIs directly from iOS
   - **Status**: Abandoned (security risk, tokens exposed)

### Current State

**Working:**
- ✅ OAuth 2.0 authentication
- ✅ Token storage in Supabase
- ✅ Edge Functions deployed
- ✅ Database schema correct

**Not Working:**
- ❌ Activity data retrieval
- ❌ Webhook reception
- ❌ Pull Token management
- ❌ Historical data backfill

---

## 🎯 What Needs to Be Fixed

### Priority 1: Pull Token Management

**Problem**: Pull Token is required but not managed properly.

**Solution Options:**

**Option A: Store Pull Token in Database**
```sql
-- Add to app_config table
CREATE TABLE IF NOT EXISTS app_config (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Store Pull Token
INSERT INTO app_config (key, value) 
VALUES ('garmin_pull_token', 'CPT...')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();
```

**Option B: Use OAuth 1.0a for Data Access (Hybrid)**
- Authenticate with OAuth 2.0 (current)
- Use OAuth 1.0a signatures for data access (if Garmin allows)
- Store `access_token` as `oauth_token`, `refresh_token` as `oauth_token_secret`

**Option C: Automatic Pull Token Refresh**
- Implement daily cron job to fetch new Pull Token from Garmin Developer Portal
- Update database automatically

### Priority 2: Webhook Verification

**Problem**: Webhooks may not be configured correctly.

**Needed:**
1. Verify webhook URLs are registered in Garmin Developer Portal
2. Check webhook endpoints are publicly accessible
3. Verify webhook signature validation (if required)
4. Add logging to see if webhooks are being received

### Priority 3: Activity Fetching Logic

**Problem**: Even with Pull Token, activities return empty.

**Needed:**
1. Verify OAuth token has correct scopes (`ACTIVITY_EXPORT`, `HEALTH_EXPORT`)
2. Check date range parameters (Garmin has strict limits)
3. Verify activity type filtering (`Running`, `Hiking`, `Walking`)
4. Test with minimal date range (last 24 hours)

---

## 📋 Files to Review

### Critical Files

1. **`supabase/functions/garmin-auth-callback/index.ts`**
   - OAuth token exchange
   - Stores connection
   - **Issue**: May not be triggering backfill correctly

2. **`supabase/functions/garmin-activity-push/index.ts`**
   - Receives webhook notifications
   - Fetches activity details
   - **Issue**: May not be receiving webhooks or Pull Token missing

3. **`supabase/functions/garmin-activity-backfill/index.ts`**
   - Requests historical data
   - **Issue**: Returns 202 but no data arrives

4. **`ios/Integrations/DeviceOAuthManager.swift`**
   - Initiates OAuth flow
   - **Status**: Working correctly

### Database Schema

**Key Tables:**
- `garmin_connections`: OAuth tokens, `garmin_user_id`, `connected_at`
- `garmin_activities`: Activity summaries
- `garmin_activity_samples`: Detailed track points
- `app_config`: Should store Pull Token (currently missing)

**Key Views:**
- `unified_activities`: Combines all activity sources for iOS app

---

## 🔑 Environment Variables / Secrets

**Required Supabase Edge Function Secrets:**
```bash
SUPABASE_URL=https://gvfhtiljkybbrbxoyqsq.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<service_role_key>
GARMIN_CLIENT_SECRET=<garmin_client_secret>
```

**Missing:**
- Pull Token management (should be in database or env var)

---

## 🧪 Testing & Debugging

### How to Test

1. **Test OAuth Flow:**
   ```bash
   # In iOS app, connect Garmin
   # Check: garmin_connections table has entry
   ```

2. **Test Activity Fetching:**
   ```bash
   # Manually call Edge Function
   curl -X POST https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-backfill \
     -H "Authorization: Bearer <anon_key>" \
     -H "Content-Type: application/json" \
     -d '{"user_id": "<uuid>"}'
   ```

3. **Check Webhooks:**
   ```bash
   # Check Supabase Edge Function logs
   # Look for incoming webhook requests
   ```

4. **Verify Pull Token:**
   ```sql
   -- Check if Pull Token exists
   SELECT * FROM app_config WHERE key = 'garmin_pull_token';
   ```

### Debugging Steps

1. **Check Garmin Connection:**
   ```sql
   SELECT * FROM garmin_connections WHERE user_id = '<user_id>';
   -- Verify: access_token, garmin_user_id, connected_at exist
   ```

2. **Check Activities:**
   ```sql
   SELECT COUNT(*) FROM garmin_activities WHERE user_id = '<user_id>';
   -- Should be > 0 if working
   ```

3. **Check Edge Function Logs:**
   - Supabase Dashboard → Edge Functions → Logs
   - Look for errors, Pull Token issues, empty responses

4. **Test Garmin API Directly:**
   ```bash
   # With valid Pull Token
   curl "https://apis.garmin.com/wellness-api/rest/activities?token=CPT...&startDate=...&endDate=..." \
     -H "Authorization: Bearer <access_token>"
   ```

---

## 💡 Expert Recommendations Needed

### Questions for Expert

1. **Pull Token Management:**
   - How should Pull Token be stored and refreshed?
   - Is there a way to get a permanent Pull Token?
   - Should we use OAuth 1.0a for data access instead?

2. **Webhook Configuration:**
   - Are webhooks correctly configured in Garmin Developer Portal?
   - Do webhooks require special authentication?
   - Why aren't webhooks triggering?

3. **API Permissions:**
   - Are OAuth scopes correct (`ACTIVITY_EXPORT`, `HEALTH_EXPORT`)?
   - Do we need additional permissions?
   - Why do API calls return empty arrays?

4. **Architecture:**
   - Is the webhook-based approach correct?
   - Should we poll instead of using webhooks?
   - Is there a better pattern for Garmin OAuth 2.0?

### Expected Outcome

**Success Criteria:**
- ✅ Activities appear in `garmin_activities` table within minutes of upload
- ✅ Historical data can be backfilled
- ✅ Webhooks trigger reliably
- ✅ No manual Pull Token management needed

---

## 📚 Reference Documentation

- **Garmin OAuth 2.0 PKCE**: https://developerportal.garmin.com/sites/default/files/OAuth2PKCE_1.pdf
- **Garmin Activity API**: https://developerportal.garmin.com/sites/default/files/Activity_API-1.2.3_0.pdf
- **Garmin Health API**: https://developerportal.garmin.com/sites/default/files/Health_API-1.2.3_0.pdf
- **Supabase Edge Functions**: https://supabase.com/docs/guides/functions

---

## 🚨 Critical Blockers

1. **Pull Token Management**: No automated way to get/refresh Pull Token
2. **Webhook Reception**: Webhooks may not be configured or not triggering
3. **Empty API Responses**: Even with valid tokens, activities return empty
4. **OAuth 2.0 Limitations**: Garmin's OAuth 2.0 may not support all use cases

---

## 📝 Summary for Expert

**The Core Issue:**
Garmin's OAuth 2.0 implementation requires a Pull Token for data access, but this token is temporary and manual. The webhook-based architecture isn't receiving data, and direct API calls return empty results even with valid tokens.

**What's Needed:**
1. A reliable way to manage Pull Tokens (or alternative authentication)
2. Verification that webhooks are correctly configured
3. Debugging why API calls return empty despite valid tokens
4. Possibly a different architecture pattern for Garmin integration

**Current State:**
- Authentication works ✅
- Data retrieval doesn't work ❌
- Webhooks may not be working ❌
- Pull Token management is manual ❌

