# Garmin Sync - What Activities Are Fetched?

## Overview

When a user clicks "Sync with Garmin" in your iOS app, here's exactly what happens:

## Sync Behavior

### First Time Sync (No Previous Activities)

**Fetches:** Last 7 days of activities

**Logic:**
```swift
// From WorkoutDataFetchingService.swift
if no previous workouts found {
    fetchAfter = Date().addingTimeInterval(-7 * 24 * 60 * 60) // Last 7 days
}
```

**Why 7 days?**
- Reduces initial API load
- Gets recent activities quickly
- User can sync again for older activities if needed

### Incremental Sync (Has Previous Activities)

**Fetches:** Activities since the last stored workout

**Logic:**
```swift
if let lastTimestamp = getLastWorkoutTimestamp() {
    fetchAfter = lastTimestamp // Fetch from last activity forward
}
```

**Example:**
- Last stored activity: January 10, 2025
- User syncs on January 15, 2025
- **Fetches:** January 10 - January 15 (only new activities)

**Benefits:**
- ✅ Fast sync (only new data)
- ✅ No duplicates
- ✅ Efficient API usage

### Full Sync (Manual Override)

**Fetches:** Last 30 days of activities

**Logic:**
```swift
if useIncrementalSync == false {
    fetchAfter = Date().addingTimeInterval(-30 * 24 * 60 * 60) // Last 30 days
}
```

**When Used:**
- User explicitly requests full sync
- After reconnecting Garmin
- Manual refresh

## Activity Filtering

### Type Filter

**Only these activity types are stored:**
- ✅ Running
- ✅ Hiking
- ✅ Walking
- ✅ Indoor Running
- ✅ Trail Running
- ✅ Treadmill Running

**Filtered Out:**
- ❌ Cycling
- ❌ Swimming
- ❌ Strength Training
- ❌ Other activities

**Code:**
```swift
// From GarminAPIClient.swift
let allowedTypes = ["running", "hiking", "walking", "indoor_running", "trail_running", "treadmill_running"]
```

## What Data Is Stored

For each activity, the following is stored in Supabase:

```sql
- provider_activity_id (Garmin activity ID)
- name (Activity name)
- distance_m (Distance in meters)
- elapsed_seconds (Duration)
- activity_type_code (running, hiking, walking)
- start_time (Activity start time)
- average_heart_rate
- max_heart_rate
- calories
- elevation_gain_m
- elevation_loss_m
- average_speed_mps
- max_speed_mps
```

## Webhook vs Manual Sync

### Webhook (Automatic)
- **Trigger:** User completes activity on Garmin device
- **Fetches:** Only the new activity (real-time)
- **When:** Immediately after activity completion
- **Requires:** Webhook configured in Garmin Portal

### Manual Sync (User-Initiated)
- **Trigger:** User clicks "Sync with Garmin" button
- **Fetches:** Based on sync type (incremental or full)
- **When:** User chooses
- **Always Available:** Yes

## Getting ALL Activities

### Option 1: Multiple Syncs

If you want all historical activities:

1. **First sync:** Gets last 7 days
2. **Wait a moment**
3. **Second sync:** Gets activities from 7-14 days ago
4. **Continue** until you have all desired history

**Note:** This is limited by Garmin API rate limits and your sync logic.

### Option 2: Modify Sync Logic

To fetch more activities on first sync, modify `WorkoutDataFetchingService.swift`:

```swift
// Change from 7 days to 90 days (or more)
fetchAfter = Date().addingTimeInterval(-90 * 24 * 60 * 60) // Last 90 days
```

**Considerations:**
- ⚠️ Slower initial sync
- ⚠️ More API calls
- ⚠️ May hit rate limits
- ⚠️ Takes longer to complete

### Option 3: Server-Side Full Sync

Use the `garmin-sync-all-users` Edge Function with cron job:

```sql
-- Runs every 6 hours, fetches all new activities
SELECT cron.schedule(
  'sync-garmin-activities',
  '0 */6 * * *',
  ...
);
```

**Benefits:**
- ✅ Automatic background sync
- ✅ No user interaction needed
- ✅ Handles all users
- ✅ Incremental (only new activities)

## Current Sync Summary

| Scenario | Activities Fetched |
|----------|-------------------|
| **First sync** | Last 7 days |
| **Incremental sync** | Since last activity |
| **Full sync** | Last 30 days |
| **Webhook** | Only new activity |

## Recommendations

### For Most Users
✅ **Keep current incremental sync** - Fast and efficient

### For Power Users
✅ **Add "Full Sync" option** - Let users choose to fetch more history

### For Automatic Sync
✅ **Use server-side cron job** - Background sync every 6 hours

## Testing

To verify what's being fetched:

1. **Check logs:**
   ```
   📅 Incremental sync: Fetching activities after [date]
   ✅ Fetched X Garmin activities
   ```

2. **Check database:**
   ```sql
   SELECT 
     COUNT(*) as total,
     MIN(start_time) as oldest,
     MAX(start_time) as newest
   FROM workouts 
   WHERE provider = 'garmin' 
   AND user_id = '[your-user-id]';
   ```

3. **Check activity count:**
   ```sql
   SELECT activity_type_code, COUNT(*) 
   FROM workouts 
   WHERE provider = 'garmin'
   GROUP BY activity_type_code;
   ```

## Summary

**Will you get all activities?**
- **First sync:** Last 7 days only
- **Subsequent syncs:** Only new activities (incremental)
- **To get all:** Use multiple syncs or modify the date range

**Recommendation:** Keep incremental sync for speed, add optional "Full Sync" button for users who want all history.

