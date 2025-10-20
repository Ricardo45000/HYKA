# Historical Data Flow - When Data Gets Pushed

## Overview

Historical data is **pushed asynchronously via webhooks** after you request a backfill. The process is **not immediate** - Garmin processes it in the background.

## Complete Flow

```
[ User Action ]
     |
     | User clicks "Sync with Garmin" button
     | OR calls garmin-activity-backfill function
     v
[ garmin-activity-backfill ]
     |
     | Calls: GET /rest/backfill/activities
     |        ?summaryStartTimeInSeconds=X
     |        &summaryEndTimeInSeconds=Y
     v
[ Garmin Backfill API ]
     |
     | Returns: 202 Accepted (async processing)
     | "We'll process this in the background"
     v
[ Garmin Processes Backfill ]
     |
     | ⏱️ Processing time: Minutes to hours
     | (Depends on amount of historical data)
     |
     | For each historical activity found:
     |   - Garmin sends PING webhook
     |   OR
     |   - Garmin sends PUSH webhook
     v
[ garmin-activity-ping ] OR [ garmin-activity-push ]
     |
     | Receives webhook with callbackUrl or full data
     v
[ garmin-activity-pull ]
     |
     | Fetches: summary, details, FIT file
     v
[ garmin-activity-store ]
     |
     | Stores in Supabase:
     |   - garmin_activities
     |   - garmin_activity_samples
     |   - garmin_fit_files (if available)
     v
[ Database Updated ✅ ]
```

## Timeline

### Step 1: Backfill Request (Immediate)
- **When:** User triggers backfill (button click or function call)
- **What happens:** 
  - `garmin-activity-backfill` function is called
  - Garmin API returns `202 Accepted`
  - Response: "Backfill request accepted, processing asynchronously"
- **Duration:** < 1 second

### Step 2: Garmin Processing (Variable Time)
- **When:** After backfill request is accepted
- **What happens:**
  - Garmin processes historical data in the background
  - Finds all activities in the requested date range
  - Prepares webhooks for each activity
- **Duration:** 
  - **Small range (7 days):** 5-15 minutes
  - **Medium range (30 days):** 15-60 minutes
  - **Large range (90 days):** 1-3 hours
  - **Very large (1 year):** 3-12 hours

### Step 3: Webhooks Arrive (Gradually)
- **When:** As Garmin processes each activity
- **What happens:**
  - Garmin sends webhooks (PING or PUSH) for each activity
  - Webhooks arrive **gradually**, not all at once
  - Each webhook triggers data fetch and storage
- **Duration:** 
  - Webhooks arrive over the processing period
  - Could be 1 per second, or batches

### Step 4: Data Storage (Per Activity)
- **When:** As each webhook arrives
- **What happens:**
  - `garmin-activity-ping` or `garmin-activity-push` receives webhook
  - `garmin-activity-pull` fetches activity data
  - `garmin-activity-store` stores in database
- **Duration:** 1-5 seconds per activity

## Example Timeline

**Scenario:** User requests 30 days of historical data (50 activities)

```
T+0s:    User clicks "Sync with Garmin"
T+0.5s:  Backfill request accepted (202 Accepted)
T+1m:    Garmin starts processing
T+2m:    First webhook arrives → Activity 1 stored
T+2m:    Second webhook arrives → Activity 2 stored
T+3m:    Third webhook arrives → Activity 3 stored
...
T+45m:   Last webhook arrives → Activity 50 stored
T+45m:   ✅ All historical data in database
```

## How to Check Progress

### 1. Check Backfill Request Status
```sql
SELECT 
    user_id,
    summary_start_time_seconds,
    summary_end_time_seconds,
    status,
    created_at,
    completed_at
FROM garmin_backfill_requests
WHERE user_id = 'your-user-id'
ORDER BY created_at DESC;
```

### 2. Check Activities Count
```sql
SELECT 
    COUNT(*) as total_activities,
    MIN(start_time) as earliest_activity,
    MAX(start_time) as latest_activity
FROM garmin_activities
WHERE user_id = 'your-user-id';
```

### 3. Monitor Webhook Logs
- Check Supabase Edge Function logs for:
  - `garmin-activity-ping` (webhooks received)
  - `garmin-activity-pull` (data fetched)
  - `garmin-activity-store` (data stored)

## Important Notes

### ⚠️ Asynchronous Processing
- **Data is NOT stored immediately** after backfill request
- Garmin processes in the background
- Webhooks arrive gradually over time

### ⚠️ No Progress Updates
- Garmin doesn't provide progress updates
- You can only check:
  - How many activities are in the database
  - When the last activity was stored

### ⚠️ Multiple 30-Day Requests
- For 90 days of data, make 3 separate requests:
  - Request 1: Days 0-30
  - Request 2: Days 31-60
  - Request 3: Days 61-90
- Each request processes independently
- Webhooks arrive for all requests simultaneously

### ⚠️ Duplicate Prevention
- Garmin returns `409 Conflict` for duplicate date ranges
- The `garmin_backfill_requests` table tracks requests
- Prevents accidentally requesting the same range twice

## Best Practices

1. **Request backfill after user connects:**
   - Automatically trigger backfill in `garmin-auth-callback`
   - Or provide a "Sync Historical Data" button

2. **Show progress to user:**
   - Display: "Syncing historical data... X activities found"
   - Update count as activities arrive

3. **Handle long processing times:**
   - Don't block UI waiting for completion
   - Process webhooks in background
   - Notify user when complete

4. **Monitor for completion:**
   - Check if new activities stop arriving
   - Compare requested date range with stored activities
   - Mark backfill as "completed" when done

## Summary

**Historical data is pushed:**
- ✅ **Asynchronously** (not immediately)
- ✅ **Via webhooks** (same as new activities)
- ✅ **Gradually** (over minutes to hours)
- ✅ **Automatically** (no manual intervention needed)

**Timeline:**
- Backfill request: **Immediate** (< 1 second)
- Garmin processing: **5 minutes to 12 hours** (depends on data volume)
- Data storage: **As webhooks arrive** (1-5 seconds per activity)

**You can't speed it up** - it's controlled by Garmin's processing speed. Just request the backfill and wait for webhooks to arrive!

