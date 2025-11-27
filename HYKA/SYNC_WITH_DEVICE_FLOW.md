# "Sync with Device" Flow - Complete Process

## When You Click "Sync with Device" Button

### Step-by-Step Flow:

### 1. **iOS App** (`syncWithDevice()` function)
   - Checks if Garmin is connected
   - Gets user ID
   - Calls `triggerGarminBackfill(userId: userId)`

### 2. **iOS App** (`triggerGarminBackfill()` function)
   - Calls `garmin-activity-backfill` edge function
   - Sends: `{ "user_id": "...", "requestLast90Days": true }`
   - Waits for response

### 3. **Edge Function** (`garmin-activity-backfill`)
   - Gets Garmin access token (auto-refreshes if expired)
   - Looks up connection date from `garmin_connections`
   - Calculates date range: **Last 90 days** (or from connection date if newer)
   - Splits into **3 chunks of 30 days each**
   - For each chunk:
     - Checks if already requested (in `garmin_backfill_requests` table)
     - If not, calls Garmin API: `GET /wellness-api/rest/backfill/activities`
     - Garmin returns:
       - **202 Accepted** = Request accepted, will process
       - **409 Conflict** = Already requested (Garmin remembers it)
   - Records requests in `garmin_backfill_requests` table
   - Returns summary to iOS app

### 4. **Garmin Server** (Asynchronous Processing)
   - Garmin processes the backfill request in the background
   - This can take minutes to hours depending on data volume
   - When ready, Garmin sends webhooks

### 5. **Webhook Delivery** (PING or PUSH)

   **If PING webhooks configured:**
   - Garmin → `garmin-activity-ping` (notification only)
   - Extracts `callbackUrl` from webhook
   - Forwards to → `garmin-activity-pull`
   - Pull function fetches activity data from Garmin
   - Forwards to → `garmin-activity-store`

   **If PUSH webhooks configured (faster):**
   - Garmin → `garmin-activity-push` (full data included)
   - Processes activity summaries directly
   - Forwards to → `garmin-activity-store`

### 6. **Edge Function** (`garmin-activity-store`)
   - Stores activity summary in `garmin_activities` table
   - Stores GPS samples in `garmin_activity_samples` table
   - Stores FIT file in `garmin_fit_files` table
   - Triggers `garmin-fit-processor` for FIT file processing
   - Updates `last_sync_at` in `garmin_connections`

### 7. **iOS App** (Reading Data)
   - App can now read activities from Supabase:
     ```swift
     let activities = try await SupabaseService.fetchGarminActivities(
         userId: userId,
         startDate: startDate,
         endDate: endDate
     )
     ```

## Timeline

```
User clicks "Sync" 
  ↓ (immediate)
App calls backfill function
  ↓ (1-2 seconds)
Backfill function requests from Garmin
  ↓ (immediate)
Garmin accepts (202) or remembers (409)
  ↓ (minutes to hours - async)
Garmin processes and sends webhooks
  ↓ (seconds per webhook)
Webhook handlers store activities
  ↓ (immediate)
Activities available in Supabase
  ↓
App can read from Supabase
```

## What Gets Synced

### Activities:
- **Activity Summary**: Type, name, distance, duration, pace, elevation, heart rate
- **GPS Track**: Latitude, longitude, elevation for each sample
- **Heart Rate Samples**: HR data throughout activity
- **FIT Files**: Raw Garmin FIT file data

### Health Data:
- **User Metrics**: Fitness age, VO2 max (via `garmin-health-webhook`)
- **Health Snapshots**: Daily health summaries
- **Body Composition**: Weight, body fat, etc.

## Important Notes

1. **Asynchronous**: Activities don't appear immediately
   - Backfill request is accepted immediately
   - Activities arrive via webhooks over time (minutes to hours)

2. **Webhook-Based**: Garmin's API is webhook-based
   - No direct "fetch activities now" endpoint
   - Must wait for webhooks to deliver data

3. **Date Range**: Currently requests **last 90 days**
   - Can be changed in `triggerGarminBackfill()` function
   - Garmin limits to 30 days per request (handled as 3 chunks)

4. **Activity Filtering**: Only Running/Hiking/Walking activities are stored
   - Other activity types are filtered out
   - Can be changed in `garmin-activity-push` and `garmin-activity-pull`

5. **Duplicate Handling**: 
   - Garmin remembers requests for a long time
   - 409 responses are treated as success (Garmin is processing)

## Current Implementation

**Function Called:** `garmin-activity-backfill`
**Request:** Last 90 days of activities
**Response:** Immediate (202 or 409)
**Data Delivery:** Via webhooks (asynchronous)

## To See Activities in App

After clicking "Sync with Device":
1. Wait for webhooks to arrive (check Supabase logs)
2. Activities will appear in `garmin_activities` table
3. Use `SupabaseService.fetchGarminActivities()` to read them
4. Display in your UI

