# When Functions Are Called - Garmin Webhook Flow

## Flow Overview

```
[User uploads activity to Garmin Connect]
           |
           v
[Garmin sends PING webhook]
           |
           v
[garmin-activity-ping] ← Called automatically by Garmin
           |
           v
[garmin-activity-pull] ← Called by ping function
           |
           v
[garmin-activity-store] ← Called by pull function
           |
           v
[Data stored in Supabase]
           |
           v
[iOS app reads from Supabase]
```

---

## Function Call Sequence

### 1. `garmin-activity-ping` 

**When:** Automatically called by Garmin when:
- ✅ User uploads a new activity to Garmin Connect
- ✅ Activity is synced from Garmin device
- ✅ Historical backfill is triggered (via Garmin Developer Portal)

**Who calls it:** Garmin's servers (webhook)

**Trigger:** Garmin sends HTTP POST to your webhook URL

**What it does:**
1. Receives PING webhook from Garmin
2. Extracts `callbackUrl` (includes temporary Pull Token)
3. Calls `garmin-activity-pull` function
4. Returns 200 OK to Garmin

**Example webhook payload from Garmin:**
```json
{
  "summaryId": 12345,
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "userId": "garmin_user_id"
}
```

---

### 2. `garmin-activity-pull`

**When:** Called by `garmin-activity-ping` function

**Who calls it:** `garmin-activity-ping` (internal function call)

**Trigger:** After `garmin-activity-ping` extracts callbackUrl

**What it does:**
1. Receives `callbackUrl` from ping function
2. `GET callbackUrl` → Fetches activity summary
3. `GET callbackUrl/details` → Fetches activity samples
4. Calls `garmin-activity-store` function
5. Returns success

**Example input:**
```json
{
  "callbackUrl": "https://apis.garmin.com/.../pull?token=XYZ",
  "garminUserId": "garmin_user_id",
  "summaryId": 12345
}
```

---

### 3. `garmin-activity-store`

**When:** Called by `garmin-activity-pull` function

**Who calls it:** `garmin-activity-pull` (internal function call)

**Trigger:** After `garmin-activity-pull` fetches summary and details

**What it does:**
1. Receives summary and details from pull function
2. Finds HYKA user from `garminUserId` in `garmin_connections` table
3. Stores activity in `garmin_activities` table (upsert)
4. Stores samples in `garmin_activity_samples` table (upsert)
5. Updates `last_sync_at` timestamp
6. Returns success

**Example input:**
```json
{
  "summary": { "summaryId": 12345, "activityType": "running", ... },
  "details": { "samples": [...] },
  "garminUserId": "garmin_user_id",
  "callbackUrl": "..."
}
```

---

### 4. `garmin-token-exchange`

**When:** Called by iOS app during OAuth flow

**Who calls it:** iOS app (when user connects Garmin)

**Trigger:** User clicks "Connect Garmin" in iOS app

**What it does:**
1. Receives authorization `code` from iOS app
2. Exchanges code for `access_token` and `refresh_token`
3. Gets `garmin_user_id` from Garmin
4. Stores tokens and user ID in `garmin_connections` table
5. Returns success to iOS app

**Example flow:**
```
iOS App → OAuth → Garmin → Redirect with code → garmin-token-exchange
```

---

## Timeline Example

### Scenario: User uploads activity at 2:00 PM

**2:00:00 PM** - User syncs Garmin device
- Activity uploaded to Garmin Connect

**2:00:05 PM** - Garmin sends webhook
- `garmin-activity-ping` called automatically
- Extracts callbackUrl
- Calls `garmin-activity-pull`

**2:00:06 PM** - Pull function executes
- `garmin-activity-pull` fetches summary from callbackUrl
- Fetches details from callbackUrl/details
- Calls `garmin-activity-store`

**2:00:07 PM** - Store function executes
- `garmin-activity-store` stores in Supabase
- Activity available in `garmin_activities` table

**2:00:10 PM** - User opens HYKA app
- iOS app reads from `unified_activities` view
- Activity appears in app

---

## Manual Triggers

### Historical Backfill

**When:** User clicks "Sync with Garmin" button in iOS app

**What happens:**
1. iOS app shows message: "Use Garmin Developer Portal's backfill tool"
2. User goes to Garmin Developer Portal
3. User triggers backfill for date range
4. Garmin sends webhooks for each historical activity
5. Each webhook triggers the same flow: `ping` → `pull` → `store`

**Note:** The iOS app no longer calls any backend function for backfill. It's all handled by Garmin webhooks.

---

## Automatic Triggers

### Real-Time Sync

**When:** User uploads activity to Garmin Connect

**Flow:**
1. ✅ Automatic - Garmin sends webhook
2. ✅ Automatic - `garmin-activity-ping` processes it
3. ✅ Automatic - `garmin-activity-pull` fetches data
4. ✅ Automatic - `garmin-activity-store` stores it
5. ✅ Automatic - Activity available in app

**No manual action needed!**

---

## Function Dependencies

```
garmin-activity-ping
    └── calls → garmin-activity-pull
                    └── calls → garmin-activity-store

garmin-token-exchange (independent, called by iOS app)
```

---

## Summary

| Function | Called By | When | Frequency |
|----------|-----------|------|-----------|
| `garmin-activity-ping` | **Garmin** (webhook) | Activity uploaded | Real-time |
| `garmin-activity-pull` | `garmin-activity-ping` | After ping receives callbackUrl | Real-time |
| `garmin-activity-store` | `garmin-activity-pull` | After pull fetches data | Real-time |
| `garmin-token-exchange` | **iOS app** | User connects Garmin | Once per connection |

---

## Key Points

1. **`garmin-activity-ping`** is the **entry point** - only function called by Garmin
2. **`garmin-activity-pull`** and **`garmin-activity-store`** are **internal** - called by other functions
3. **`garmin-token-exchange`** is **independent** - only called during OAuth
4. **No polling** - everything is event-driven via webhooks
5. **Real-time** - Activities appear in Supabase within seconds of upload

---

## Testing

To test the flow:

1. **Upload activity to Garmin Connect**
   - Sync your Garmin device
   - Activity appears in Garmin Connect

2. **Check Supabase logs**
   - Look for `garmin-activity-ping` logs
   - Should see webhook received
   - Should see pull and store functions called

3. **Check database**
   - Query `garmin_activities` table
   - Activity should appear within seconds

4. **Check iOS app**
   - Activity should appear in app
   - Read from `unified_activities` view

