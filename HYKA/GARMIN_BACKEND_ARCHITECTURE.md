# Garmin Backend Architecture - Implementation Guide

## Overview

This document outlines the official Garmin Developer Program approach for HYKA, where all activity data is fetched server-side via webhooks, not client-side.

## Architecture

```
[ iOS HYKA app ]
       |
       | 1. "Connect Garmin" (OAuth 2.0 PKCE)
       v
[ Garmin OAuth 2.0 ]
       |
       | 2. Redirect with `code` --> Edge Function
       v
[ garmin-token-exchange Edge Function ]
       | 3. Exchange code → access_token + refresh_token + garmin_user_id
       | 4. Store in garmin_connections table
       v
[ Supabase DB: garmin_connections ]

-------------------------------- BACKEND DATA PLANE --------------------------

[ Garmin Activity / Health APIs ]
       |
       | 5. User syncs watch → Garmin generates summaries
       | 6. Garmin sends PUSH/PING to your webhooks
       v
[ garmin-activity-ping ] [ garmin-activity-push ]
       |                          |
       | 7a. PING: notification only
       | 7b. PUSH: JSON with activities
       v                          v
[ garmin-activity-fetch ] (fetches full details using Pull Token)
       |
       | 8. Store:
       |    - garmin_activities (summary)
       |    - garmin_activity_samples (per-second data)
       v
[ Supabase DB ]
       |
       | 9. iOS app reads from Supabase
       v
[ Race planner, workouts view, etc. ]
```

## Completed Changes

### ✅ 1. iOS App - Removed Activity Data Fetching

**File**: `ios/Integrations/GarminAPIClient.swift`
- Removed all activity/health/training data fetching methods
- Kept only `fetchUserId()` and `fetchUserPermissions()` for OAuth connection
- Added comprehensive documentation explaining the new architecture

**Status**: COMPLETE

### ✅ 2. Documented Architecture

**File**: `GARMIN_BACKEND_ARCHITECTURE.md` (this file)
- Complete documentation of the new architecture
- Mind map showing data flow
- Implementation checklist

**Status**: COMPLETE

## Remaining Work

### 🔄 3. Clean Up WorkoutDataFetchingService.swift

**File**: `ios/Integrations/WorkoutDataFetchingService.swift`
**Status**: IN PROGRESS

**What's done**:
- Added return statement for Garmin case to prevent client-side fetching

**What needs to be done**:
1. Remove unreachable code after `return 0` statement (lines 66-126)
2. Update `fetchAndStoreSamples()` case "garmin" to return early
3. Update `fetchAndStoreHealthMetrics()` case "garmin" to return early
4. Update `fetchAndStoreTraining()` case "garmin" to return early

**Code to add**:
```swift
case "garmin":
    // Garmin samples are fetched SERVER-SIDE via Edge Functions
    print("ℹ️  Garmin samples are fetched automatically by backend")
    print("   Read from Supabase garmin_activity_samples table")
    return
```

### 🔄 4. Remove "Sync with Device" Button

**File**: `ios/Features/RacePlan/RacePlanView.swift`
**Status**: TODO

**What to do**:
1. Search for "Sync with" or "Sync with device" button
2. Either remove it entirely OR
3. Change it to "Refresh" and have it reload data from Supabase (not call Garmin APIs)

**Recommended**: Remove the button entirely since Garmin webhooks automatically push new data.

### 🔄 5. Remove Pull Token from iOS App

**File**: `ios/Integrations/GarminConfig.swift`
**Status**: TODO

**What to do**:
1. Remove `pullToken` properties and `fetchPullToken()` method
2. Pull Token is now ONLY used server-side in Edge Functions
3. Update any remaining references to `GarminConfig.pullToken`

### 🔄 6. Database Schema

**File**: `garmin_backend_schema.sql` (TO BE CREATED)
**Status**: TODO

**What to create**:

```sql
-- Garmin connections table (stores OAuth tokens)
CREATE TABLE IF NOT EXISTS garmin_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_user_id TEXT NOT NULL, -- Garmin's userId
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id), -- One Garmin connection per user
    UNIQUE(garmin_user_id) -- One HYKA user per Garmin account
);

-- Garmin activities table (stores activity summaries)
CREATE TABLE IF NOT EXISTS garmin_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_activity_id TEXT NOT NULL, -- Garmin's activityId or summaryId
    activity_name TEXT,
    activity_type TEXT,
    start_time TIMESTAMPTZ,
    duration_seconds INT,
    distance_meters DOUBLE PRECISION,
    total_elevation_gain_meters DOUBLE PRECISION,
    average_heart_rate INT,
    max_heart_rate INT,
    average_speed_mps DOUBLE PRECISION,
    max_speed_mps DOUBLE PRECISION,
    calories INT,
    raw_data JSONB, -- Store full JSON from Garmin
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, garmin_activity_id)
);

-- Garmin activity samples table (stores per-second data)
CREATE TABLE IF NOT EXISTS garmin_activity_samples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES garmin_activities(id) ON DELETE CASCADE,
    timestamp_seconds BIGINT NOT NULL, -- startTimeInSeconds from Garmin
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    elevation_meters DOUBLE PRECISION,
    heart_rate INT,
    speed_mps DOUBLE PRECISION,
    steps_per_minute INT,
    air_temperature_celsius DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_garmin_activities_user_id ON garmin_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_start_time ON garmin_activities(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_activity_id ON garmin_activity_samples(activity_id);
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_timestamp ON garmin_activity_samples(timestamp_seconds);

-- App config table (stores Pull Token)
-- Already created in garmin_pull_token_setup.sql
```

### 🔄 7. Edge Function: garmin-activity-ping

**File**: `supabase/functions/garmin-activity-ping/index.ts` (TO BE CREATED)
**Status**: TODO

**Purpose**: Receives PING notifications from Garmin (no activity data, just notification)

**Code template**:
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    // Verify it's from Garmin (check headers/signature if needed)
    const body = await req.json()
    console.log("Garmin PING received:", body)
    
    // Extract garminUserId from ping
    const { garminUserId } = body
    
    if (!garminUserId) {
      return new Response("Missing garminUserId", { status: 400 })
    }
    
    // Look up HYKA user from garminUserId
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    const { data: connection } = await supabase
      .from('garmin_connections')
      .select('user_id, access_token')
      .eq('garmin_user_id', garminUserId)
      .single()
    
    if (!connection) {
      console.log("No connection found for Garmin user:", garminUserId)
      return new Response("OK", { status: 200 }) // Still return 200 to Garmin
    }
    
    // Trigger activity fetch (call garmin-activity-fetch Edge Function)
    const pullToken = Deno.env.get('GARMIN_PULL_TOKEN')!
    
    await fetch(`${supabaseUrl}/functions/v1/garmin-activity-fetch`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${supabaseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        userId: connection.user_id,
        accessToken: connection.access_token,
        pullToken: pullToken
      })
    })
    
    return new Response("OK", { status: 200 })
  } catch (error) {
    console.error("Error processing ping:", error)
    return new Response("Error", { status: 500 })
  }
})
```

### 🔄 8. Edge Function: garmin-activity-push

**File**: `supabase/functions/garmin-activity-push/index.ts` (TO BE CREATED)
**Status**: TODO

**Purpose**: Receives PUSH notifications from Garmin (includes activity data)

**Code template**:
```typescript
// Similar to garmin-activity-ping, but also includes activity data in the payload
// Process activities directly from the push payload
```

### 🔄 9. Edge Function: garmin-activity-fetch

**File**: `supabase/functions/garmin-activity-fetch/index.ts` (TO BE CREATED)
**Status**: TODO

**Purpose**: Fetches activity details from Garmin Wellness API using Pull Token

**Code template**:
```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { userId, accessToken, pullToken, startDate, endDate } = await req.json()
    
    // Build Wellness API request
    const startSeconds = Math.floor(new Date(startDate).getTime() / 1000)
    const endSeconds = Math.floor(new Date(endDate).getTime() / 1000)
    
    const wellnessUrl = `https://apis.garmin.com/wellness-api/rest/activities?uploadStartTimeInSeconds=${startSeconds}&uploadEndTimeInSeconds=${endSeconds}&token=${pullToken}`
    
    const response = await fetch(wellnessUrl, {
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json'
      }
    })
    
    if (!response.ok) {
      throw new Error(`Garmin API error: ${response.status}`)
    }
    
    const activities = await response.json()
    
    // Store activities in Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)
    
    for (const activity of activities) {
      // Insert activity
      await supabase.from('garmin_activities').upsert({
        user_id: userId,
        garmin_activity_id: activity.activityId || activity.summaryId,
        activity_name: activity.activityName,
        activity_type: activity.activityType,
        start_time: new Date(activity.startTimeInSeconds * 1000),
        duration_seconds: activity.durationInSeconds,
        distance_meters: activity.distanceInMeters,
        total_elevation_gain_meters: activity.totalElevationGainInMeters,
        average_heart_rate: activity.averageHeartRateInBeatsPerMinute,
        max_heart_rate: activity.maxHeartRateInBeatsPerMinute,
        average_speed_mps: activity.averageSpeedInMetersPerSecond,
        max_speed_mps: activity.maxSpeedInMetersPerSecond,
        calories: activity.activeKilocalories,
        raw_data: activity
      }, {
        onConflict: 'user_id,garmin_activity_id'
      })
      
      // Fetch activity details (samples) if needed
      // ... (similar logic for /rest/activityDetails)
    }
    
    return new Response(JSON.stringify({ success: true, count: activities.length }), {
      headers: { 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error("Error fetching activities:", error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    })
  }
})
```

### 🔄 10. Cron Job for Hourly Sync

**File**: Supabase SQL Editor (TO BE CREATED)
**Status**: TODO

**Purpose**: Backup mechanism to pull data every hour in case webhooks fail

**Code**:
```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule hourly sync for all Garmin connections
SELECT cron.schedule(
    'garmin-hourly-sync',
    '0 * * * *', -- Every hour at minute 0
    $$
    SELECT net.http_post(
        url := 'https://YOUR_PROJECT.supabase.co/functions/v1/garmin-hourly-sync',
        headers := jsonb_build_object(
            'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);
```

### 🔄 11. Garmin Webhook Configuration

**Platform**: Garmin Developer Portal
**Status**: TODO

**What to configure**:

1. Go to Garmin Developer Portal → Endpoint Configuration
2. For each endpoint, set the webhook URL:
   - **ACTIVITY - Activities** (PUSH):
     ```
     https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push
     ```
   - **ACTIVITY - Activity Details** (PUSH):
     ```
     https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push
     ```
   - **ACTIVITY - Activity Files** (optional):
     ```
     https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-push
     ```

3. Enable and save

## Summary of Changes

### What Changed
1. **iOS App**: No longer fetches activity data from Garmin APIs
2. **Data Flow**: Server-side only via Edge Functions
3. **Pull Token**: Moved from iOS app to Edge Functions
4. **Sync Button**: To be removed (data flows automatically)

### What Stayed the Same
1. **OAuth 2.0 PKCE**: User authorization still happens in iOS app
2. **User Experience**: Still connects Garmin, but data appears automatically
3. **Supabase**: Still the central data store

### Benefits
1. **Secure**: Pull Token never exposed to client
2. **Automatic**: Data flows without user action
3. **Scalable**: Backend handles all API calls
4. **Compliant**: Follows official Garmin Developer Program approach

## Next Steps

1. ✅ Clean up `WorkoutDataFetchingService.swift`
2. ✅ Remove "Sync with device" button
3. ✅ Remove Pull Token from iOS app
4. ✅ Create database schema
5. ✅ Create Edge Functions
6. ✅ Configure Garmin webhooks
7. ✅ Set up hourly cron job
8. ✅ Test end-to-end flow

