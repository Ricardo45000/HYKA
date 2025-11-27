# Complete Garmin Integration Architecture

## Overview
This document describes the complete architecture for syncing Garmin activities and health data to Supabase, and how the iOS app reads this data.

## Data Flow

```
Garmin Connect → Webhooks → Supabase Edge Functions → Supabase Database → iOS App
```

## Architecture Components

### 1. OAuth Authentication Flow

**Edge Function:** `garmin-auth-callback`

**Flow:**
1. User authorizes app in Garmin Connect
2. iOS app receives OAuth code
3. App calls `garmin-auth-callback` with code
4. Edge function:
   - Exchanges code for access_token + refresh_token
   - Fetches Garmin user ID from `/rest/user/id`
   - Stores connection in `garmin_connections` table
   - Triggers automatic backfill for historical data

**Stored Data:**
- `user_id` (HYKA user)
- `garmin_user_id` (Garmin's user identifier)
- `access_token` (OAuth access token)
- `refresh_token` (OAuth refresh token)
- `token_expires_at` (Token expiration time)
- `connected_at` (Connection timestamp)

### 2. Activity Data Sync

#### 2.1 Webhook-Based Sync (Real-time)

**Webhook Types:**
- **PING**: Notification only (Garmin sends `callbackUrl`)
- **PUSH**: Full activity summary included in webhook

**Edge Functions:**
- `garmin-activity-ping`: Receives PING, extracts `callbackUrl`, forwards to `garmin-activity-pull`
- `garmin-activity-pull`: Fetches activity data from Garmin using `callbackUrl`
- `garmin-activity-push`: Receives PUSH with full activity summaries
- `garmin-activity-store`: Stores activity data in database

**Activity Data Stored:**
- **Summary** (in `garmin_activities` table):
  - Activity ID, type, name
  - Start time, duration, distance
  - Elevation gain/loss
  - Heart rate (avg, max)
  - Pace, calories
  - Device name
- **Details** (in `garmin_activity_samples` table):
  - GPS track points (lat, lon, elevation)
  - Heart rate samples
  - Pace samples
  - Timestamps
- **FIT Files** (in `garmin_fit_files` table):
  - Raw FIT file data
  - Processed by `garmin-fit-processor`

#### 2.2 Historical Data (Backfill)

**Edge Function:** `garmin-activity-backfill`

**Flow:**
1. App calls backfill function (or automatic after OAuth)
2. Function requests historical data from Garmin
3. Garmin processes asynchronously
4. Activities arrive via webhooks (PING or PUSH)
5. Webhook handlers store activities

**Limitations:**
- Garmin only allows backfilling from connection date forward
- Maximum 30 days per request
- Can make multiple requests for longer periods
- Garmin remembers requests (duplicate detection)

### 3. Health Data Sync

**Edge Function:** `garmin-health-webhook`

**Health Data Types:**
- User Metrics (fitness age, VO2 max)
- Health Snapshots
- Body Composition
- Daily metrics

**Stored Data** (in `garmin_health_metrics` table):
- `user_id` (HYKA user)
- `garmin_user_id`
- `timestamp` (metric timestamp)
- `fitness_age`
- `vo2_max`
- `raw_data` (full metric object as JSON)

### 4. Permission Management

**Edge Function:** `garmin-permission-webhook`

**Purpose:**
- Handles permission revocation
- Updates `permission_revoked` flag in `garmin_connections`
- Allows app to detect when user disconnects

### 5. Token Refresh

**Edge Function:** `garmin-token-refresh` (shared utility)

**Purpose:**
- Automatically refreshes expired access tokens
- Used by other functions when tokens expire
- Updates `garmin_connections` with new tokens

## Database Schema

### `garmin_connections`
- `user_id` (UUID, FK to profiles)
- `garmin_user_id` (TEXT, unique Garmin identifier)
- `access_token` (TEXT, encrypted)
- `refresh_token` (TEXT, encrypted)
- `token_expires_at` (TIMESTAMP)
- `connected_at` (TIMESTAMP)
- `permission_revoked` (BOOLEAN)
- `last_sync_at` (TIMESTAMP)

### `garmin_activities`
- `id` (UUID, primary key)
- `user_id` (UUID, FK)
- `garmin_activity_id` (TEXT, unique)
- `activity_type` (TEXT)
- `activity_name` (TEXT)
- `start_time_seconds` (BIGINT)
- `duration_seconds` (INTEGER)
- `distance_meters` (DOUBLE)
- `elevation_gain_meters` (INTEGER)
- `elevation_loss_meters` (INTEGER)
- `avg_heart_rate` (INTEGER)
- `max_heart_rate` (INTEGER)
- `avg_pace_seconds_per_km` (DOUBLE)
- `calories` (INTEGER)
- `device_name` (TEXT)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### `garmin_activity_samples`
- `id` (UUID, primary key)
- `activity_id` (UUID, FK to garmin_activities)
- `timestamp_seconds` (BIGINT)
- `latitude` (DOUBLE)
- `longitude` (DOUBLE)
- `elevation_meters` (DOUBLE)
- `heart_rate` (INTEGER)
- `pace_seconds_per_km` (DOUBLE)

### `garmin_health_metrics`
- `id` (UUID, primary key)
- `user_id` (UUID, FK)
- `garmin_user_id` (TEXT)
- `timestamp` (TIMESTAMP)
- `fitness_age` (INTEGER)
- `vo2_max` (DOUBLE)
- `raw_data` (JSONB, full metric object)

### `garmin_backfill_requests`
- `id` (UUID, primary key)
- `user_id` (UUID, FK)
- `summary_start_time_seconds` (BIGINT)
- `summary_end_time_seconds` (BIGINT)
- `status` (TEXT: 'pending', 'completed', 'failed', 'duplicate')
- `created_at` (TIMESTAMP)
- `completed_at` (TIMESTAMP)

## iOS App Integration

### Reading Activities from Supabase

The `SupabaseService` class provides helper functions to fetch Garmin data:

#### Fetch Activities

```swift
// Fetch all activities (or with date range)
let activities = try await SupabaseService.fetchGarminActivities(
    userId: userId,
    startDate: startDate,  // Optional
    endDate: endDate,      // Optional
    limit: 100
)

// Each activity includes:
// - id, garminActivityId, activityType, activityName
// - startTimeSeconds, durationSeconds, distanceMeters
// - elevationGainMeters, elevationLossMeters
// - avgHeartRate, maxHeartRate
// - avgPaceSecondsPerKm, calories, deviceName
// - Helper properties: startDate, distanceKm, durationHours
```

#### Fetch Single Activity

```swift
let activity = try await SupabaseService.fetchGarminActivity(activityId: activityId)
```

#### Fetch Activity GPS Samples (Track Points)

```swift
let samples = try await SupabaseService.fetchGarminActivitySamples(activityId: activityId)

// Each sample includes:
// - timestampSeconds, latitude, longitude, elevationMeters
// - heartRate, paceSecondsPerKm
// - Helper property: timestamp (Date)
```

### Reading Health Metrics from Supabase

#### Fetch Health Metrics for Date Range

```swift
let metrics = try await SupabaseService.fetchGarminHealthMetrics(
    userId: userId,
    startDate: startDate,
    endDate: endDate
)

// Each metric includes:
// - id, userId, garminUserId, timestamp
// - fitnessAge, vo2Max
// - rawData (full JSON object from Garmin)
```

#### Fetch Latest Health Metrics

```swift
let latestMetrics = try await SupabaseService.fetchLatestGarminHealthMetrics(userId: userId)
```

### Check Garmin Connection Status

```swift
let hasConnection = try await SupabaseService.hasGarminConnection(userId: userId)
```

## Webhook Configuration

### Garmin Developer Portal Setup

**Activity Webhooks:**
- **PING**: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-ping`
- **PUSH**: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push`

**Health Webhooks:**
- **User Metrics**: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-health-webhook`
- **Health Snapshot**: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-health-webhook`

**Permission Webhook:**
- **Permission Change**: `https://YOUR_PROJECT.supabase.co/functions/v1/garmin-permission-webhook`

## Activity Filtering

Currently, only these activity types are stored:
- Running (including Trail Running, Road Running, Treadmill Running)
- Hiking
- Walking

All other activity types are filtered out.

## Error Handling

### Token Expiration
- All functions check token expiration before API calls
- Automatic refresh using `garmin-token-refresh` utility
- If refresh fails, user must reconnect

### Webhook Failures
- All webhooks return 200 OK to prevent retries
- Errors are logged but don't block processing
- Duplicate activities are handled via upsert

### Backfill Failures
- 409 (Duplicate) is treated as success (Garmin remembers request)
- 401 (Token expired) triggers automatic refresh
- Failed requests are logged in `garmin_backfill_requests`

## Best Practices

1. **Always use webhooks** - Garmin's API is webhook-based, not direct fetch
2. **Handle duplicates** - Use upsert operations for activities
3. **Token management** - Always check expiration and refresh automatically
4. **Error resilience** - Don't fail entire sync if one activity fails
5. **Data validation** - Validate required fields before storing

## Testing

### Test OAuth Flow
1. Connect Garmin account in app
2. Verify connection stored in `garmin_connections`
3. Verify automatic backfill triggered

### Test Activity Sync
1. Create a new activity in Garmin Connect
2. Wait for webhook (usually within minutes)
3. Verify activity in `garmin_activities` table
4. Verify samples in `garmin_activity_samples` table

### Test Health Sync
1. Wait for health webhook (daily updates)
2. Verify metrics in `garmin_health_metrics` table

## Troubleshooting

### Activities Not Appearing
1. Check webhook logs in Supabase Dashboard
2. Verify webhook URLs in Garmin Developer Portal
3. Check `garmin_connections` for valid tokens
4. Verify activity type is not filtered out

### Health Data Not Appearing
1. Check `garmin-health-webhook` logs
2. Verify webhook is enabled in Garmin Developer Portal
3. Check `garmin_health_metrics` table structure

### Token Errors
1. Check token expiration in `garmin_connections`
2. Verify refresh token is valid
3. Reconnect Garmin account if refresh fails

