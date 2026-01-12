# Suunto API Integration Guide

## Overview

This guide covers integrating Suunto API OAuth 2.0 authentication and daily activity data sync into HYKA, following the same pattern as Garmin and Strava integrations.

## Prerequisites

1. **Apply for Suunto API Access**
   - Visit: https://apizone.suunto.com
   - Submit application (reviewed weekly, max 2 weeks wait)
   - Note: API is for companies/organizations, not personal use

2. **Get API Credentials**
   - Client ID
   - Client Secret
   - Configure OAuth redirect URI in Suunto Developer Portal

## Architecture

Following the same pattern as Garmin/Strava:

```
iOS App → OAuth Flow → Suunto API
    ↓
Edge Function (suunto-auth-callback) → Exchange code for tokens
    ↓
Store in suunto_connections table
    ↓
Webhook → Edge Function (suunto-activity-webhook) → Store activity
    ↓
Edge Function (suunto-activity-store) → Save to suunto_activities
    ↓
Edge Function (suunto-activity-notify) → Push notification
```

## Implementation Steps

### Step 1: Database Schema

Create tables for Suunto connections and activities (see `suunto_schema.sql`).

### Step 2: Supabase Edge Functions

Create 4 edge functions:
1. `suunto-auth-callback` - OAuth token exchange
2. `suunto-activity-store` - Store activity data
3. `suunto-activity-webhook` - Handle webhook notifications
4. `suunto-activity-notify` - Send push notifications

### Step 3: iOS App Updates

1. Update `Config.swift` with Suunto credentials
2. Implement OAuth flow in `DeviceOAuthManager.swift`
3. Update `SuuntoAPIClient.swift` with actual API calls
4. Remove "Coming soon" status from `ConnectDevicesView`

### Step 4: Supabase Configuration

1. Set secrets in Supabase Dashboard:
   - `SUUNTO_CLIENT_ID`
   - `SUUNTO_CLIENT_SECRET`
   - `SUUNTO_WEBHOOK_VERIFY_TOKEN`

2. Configure webhook in Suunto Developer Portal

## API Endpoints Reference

Based on Suunto API documentation:

- **Authorization**: `https://cloudapi.suunto.com/oauth/authorize`
- **Token Exchange**: `https://cloudapi.suunto.com/oauth/token`
- **Activities**: `https://cloudapi.suunto.com/v2/workouts`
- **Activity Details**: `https://cloudapi.suunto.com/v2/workouts/{id}`
- **Health Data**: `https://cloudapi.suunto.com/v2/health/daily/{date}`
- **Webhooks**: Configure in Developer Portal

## OAuth 2.0 Flow

1. User taps "Connect Suunto" in app
2. App opens Suunto authorization page
3. User authorizes
4. Suunto redirects to edge function with code
5. Edge function exchanges code for tokens
6. Tokens stored in `suunto_connections` table
7. Connection established

## Webhook Flow

1. User completes activity in Suunto app
2. Suunto sends webhook to edge function
3. Edge function verifies webhook signature
4. Edge function fetches activity details from Suunto API
5. Activity stored in `suunto_activities` table
6. Push notification sent to user

## Data Mapping

Suunto activity data maps to our schema:
- `workout.id` → `suunto_activity_id`
- `workout.name` → `activity_name`
- `workout.sport` → `activity_type`
- `workout.startTime` → `start_date`
- `workout.duration` → `elapsed_time`
- `workout.distance` → `distance_meters`
- `workout.elevationGain` → `total_elevation_gain_meters`
- `workout.heartRate.avg` → `average_heart_rate`
- `workout.heartRate.max` → `max_heart_rate`

## Testing

1. Test OAuth flow end-to-end
2. Verify webhook receives test events
3. Check activities appear in `suunto_activities` table
4. Verify push notifications are sent
5. Test activity sync in iOS app

## Troubleshooting

- **OAuth redirect_uri invalid**: Check redirect URI matches exactly in Suunto Developer Portal
- **Webhook not receiving**: Verify webhook URL and verify token in both places
- **Activities not syncing**: Check access token expiration and refresh logic
- **401 Unauthorized**: Verify client credentials are correct


