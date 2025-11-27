# Garmin Edge Functions Summary

## Complete List of Edge Functions

### 1. **garmin-auth-callback** ✅ KEEP
**Purpose:** OAuth 2.0 callback handler
- Receives OAuth code from iOS app
- Exchanges code for access_token + refresh_token
- Fetches Garmin user ID
- Stores connection in `garmin_connections` table
- Triggers automatic backfill

**Called by:** iOS app after user authorizes

---

### 2. **garmin-token-refresh** ✅ KEEP (Shared Utility)
**Purpose:** Token refresh utility
- Refreshes expired Garmin access tokens
- Used by other functions automatically
- Updates `garmin_connections` with new tokens

**Called by:** Other edge functions (internal)

---

### 3. **garmin-activity-ping** ✅ KEEP
**Purpose:** PING webhook handler
- Receives PING notifications from Garmin
- Extracts `callbackUrl` from webhook
- Forwards to `garmin-activity-pull` to fetch data

**Called by:** Garmin (webhook)

---

### 4. **garmin-activity-pull** ✅ KEEP
**Purpose:** Fetches activity data from Garmin
- Uses `callbackUrl` from PING webhook
- Fetches activity summary, details, and FIT file
- Forwards to `garmin-activity-store`

**Called by:** `garmin-activity-ping` (internal)

---

### 5. **garmin-activity-push** ✅ KEEP
**Purpose:** PUSH webhook handler
- Receives PUSH webhooks with full activity data
- Processes activity summaries directly
- Forwards to `garmin-activity-store`
- Filters for Running/Hiking/Walking activities

**Called by:** Garmin (webhook)

---

### 6. **garmin-activity-store** ✅ KEEP
**Purpose:** Stores activity data in Supabase
- Stores activity summary in `garmin_activities`
- Stores GPS samples in `garmin_activity_samples`
- Stores FIT files in `garmin_fit_files`
- Triggers `garmin-fit-processor` for FIT files

**Called by:** `garmin-activity-pull` or `garmin-activity-push` (internal)

---

### 7. **garmin-activity-backfill** ✅ KEEP
**Purpose:** Requests historical activity data
- Requests backfill from Garmin API
- Handles 90-day chunks (3x 30-day requests)
- Records requests in `garmin_backfill_requests` table
- Activities arrive via webhooks after request

**Called by:** iOS app (via "Sync with Device" button) or automatically after OAuth

---

### 8. **garmin-health-webhook** ✅ KEEP
**Purpose:** Health data webhook handler
- Receives health metrics from Garmin
- Handles User Metrics, Health Snapshots, Body Composition
- Stores in `garmin_health_metrics` table

**Called by:** Garmin (webhook)

---

### 9. **garmin-permission-webhook** ✅ KEEP
**Purpose:** Permission change webhook handler
- Handles permission revocation
- Updates `permission_revoked` flag in `garmin_connections`

**Called by:** Garmin (webhook)

---

### 10. **garmin-fit-processor** ✅ KEEP
**Purpose:** Processes FIT files
- Triggered when FIT file is stored
- Parses FIT file data
- Extracts additional metrics

**Called by:** `garmin-activity-store` (internal)

---

### 11. **garmin-backfill-status** ⚠️ OPTIONAL
**Purpose:** Check and update backfill request statuses
- Checks pending backfill requests
- Looks for activities in date ranges
- Can mark requests as completed

**Called by:** Manual/admin use (not required for normal flow)

---

### 12. **garmin-token-exchange** ❓ CHECK
**Purpose:** Unknown - need to verify
- May be duplicate of token refresh logic

**Status:** Needs review

---

### 13. **garmin-historical-backfill** ❓ CHECK
**Purpose:** Unknown - appears empty
- Directory exists but may be empty/unused

**Status:** Needs review

---

## Recommended Functions to Keep

### Essential (Required for OAuth + Data Sync):
1. ✅ `garmin-auth-callback` - OAuth flow
2. ✅ `garmin-token-refresh` - Token management
3. ✅ `garmin-activity-ping` - PING webhook
4. ✅ `garmin-activity-pull` - Fetch activity data
5. ✅ `garmin-activity-push` - PUSH webhook
6. ✅ `garmin-activity-store` - Store activities
7. ✅ `garmin-activity-backfill` - Historical data
8. ✅ `garmin-health-webhook` - Health data
9. ✅ `garmin-permission-webhook` - Permission changes
10. ✅ `garmin-fit-processor` - FIT file processing

### Optional:
11. ⚠️ `garmin-backfill-status` - Admin tool (can keep or remove)

### Removed:
12. ❌ `garmin-token-exchange` - DEPRECATED (removed)
13. ❌ `garmin-historical-backfill` - EMPTY (removed)

## Final Edge Functions List

**Total: 11 Active Functions**

1. ✅ `garmin-auth-callback` - OAuth authentication
2. ✅ `garmin-token-refresh` - Token management (shared utility)
3. ✅ `garmin-activity-ping` - PING webhook handler
4. ✅ `garmin-activity-pull` - Fetch activity data
5. ✅ `garmin-activity-push` - PUSH webhook handler
6. ✅ `garmin-activity-store` - Store activities
7. ✅ `garmin-activity-backfill` - Historical data requests
8. ✅ `garmin-health-webhook` - Health data webhook
9. ✅ `garmin-permission-webhook` - Permission changes
10. ✅ `garmin-fit-processor` - FIT file processing
11. ⚠️ `garmin-backfill-status` - Admin tool (optional)

**Removed:**
- ❌ `garmin-token-exchange` - DEPRECATED
- ❌ `garmin-historical-backfill` - EMPTY

## Webhook Configuration

These functions need to be configured in Garmin Developer Portal:

- **Activity PING**: `garmin-activity-ping`
- **Activity PUSH**: `garmin-activity-push` (recommended for faster sync)
- **Health Webhook**: `garmin-health-webhook`
- **Permission Webhook**: `garmin-permission-webhook`

