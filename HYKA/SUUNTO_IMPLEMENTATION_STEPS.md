# Suunto Integration Implementation Steps

## Step 1: Apply for Suunto API Access

1. Go to https://apizone.suunto.com
2. Submit application (reviewed weekly)
3. Once approved, get:
   - Client ID
   - Client Secret
   - Configure OAuth redirect URI

## Step 2: Database Setup

Run `suunto_schema.sql` in Supabase SQL Editor to create:
- `suunto_connections` table
- `suunto_activities` table
- `suunto_activity_samples` table
- Update `unified_activities` view

## Step 3: Supabase Edge Functions

Create 4 edge functions (similar to Garmin/Strava pattern):

### 3.1 suunto-auth-callback

**Purpose**: Handle OAuth callback and token exchange

**Location**: `supabase/functions/suunto-auth-callback/index.ts`

**Key Features**:
- Receive authorization code from iOS app
- Exchange code for access_token and refresh_token
- Fetch Suunto user ID from API
- Store connection in `suunto_connections` table
- Return tokens to iOS app

**Required Secrets**:
- `SUUNTO_CLIENT_ID`
- `SUUNTO_CLIENT_SECRET`

### 3.2 suunto-activity-store

**Purpose**: Store activity data in database

**Location**: `supabase/functions/suunto-activity-store/index.ts`

**Key Features**:
- Receive activity data from webhook or API fetch
- Parse Suunto activity format
- Store in `suunto_activities` table
- Fetch and store activity streams/samples
- Trigger push notification

### 3.3 suunto-activity-webhook

**Purpose**: Handle webhook notifications from Suunto

**Location**: `supabase/functions/suunto-activity-webhook/index.ts`

**Key Features**:
- Verify webhook signature/token
- Handle webhook subscription verification (GET)
- Process activity events (POST)
- Call `suunto-activity-store` to fetch and store activity

**Required Secrets**:
- `SUUNTO_WEBHOOK_VERIFY_TOKEN`

### 3.4 suunto-activity-notify

**Purpose**: Send push notifications for new activities

**Location**: `supabase/functions/suunto-activity-notify/index.ts`

**Key Features**:
- Send APNs push notification
- Format activity summary
- Handle notification errors gracefully

## Step 4: iOS App Updates

### 4.1 Update Config.swift

```swift
// MARK: - Suunto Configuration

/// Suunto OAuth 2.0 Client ID
static let suuntoClientID = "YOUR_CLIENT_ID"

/// Suunto OAuth 2.0 Redirect URI
/// 
/// IMPORTANT: In Suunto Developer Portal, set Authorization Callback Domain to:
/// gvfhtiljkybbrbxoyqsq.supabase.co
static let suuntoRedirectURI = "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/suunto-auth-callback"

/// Suunto OAuth callback Edge Function
static var suuntoAuthCallbackURL: String {
    return "\(edgeFunctionsBaseURL)/suunto-auth-callback"
}
```

### 4.2 Update DeviceOAuthManager.swift

Replace the `case "suunto"` block with actual OAuth implementation:

```swift
case "suunto":
    let (accessToken, refreshToken, expiresAt) = try await performSuuntoOAuth(from: viewController)
    return (accessToken, refreshToken, nil, expiresAt)
```

Add `performSuuntoOAuth` function (similar to `performStravaOAuth`).

### 4.3 Update SuuntoAPIClient.swift

Implement actual API calls:
- `fetchActivities()` - GET /v2/workouts
- `fetchActivity(id:)` - GET /v2/workouts/{id}
- `fetchStreams(activityId:)` - GET /v2/workouts/{id}/streams
- Update `fetchHealthMetrics()` with correct endpoint

### 4.4 Update ConnectDevicesView.swift

Remove Suunto from "coming soon" list:

```swift
private func isComingSoon(_ deviceName: String) -> Bool {
    deviceName == "Coros" // Only Coros is coming soon now
}
```

### 4.5 Update WorkoutsView.swift

Same change - remove Suunto from coming soon.

## Step 5: Supabase Configuration

### 5.1 Set Secrets

In Supabase Dashboard → Edge Functions → Secrets:

- `SUUNTO_CLIENT_ID` = Your Suunto Client ID
- `SUUNTO_CLIENT_SECRET` = Your Suunto Client Secret
- `SUUNTO_WEBHOOK_VERIFY_TOKEN` = Random secure token (e.g., `suunto-webhook-verify-token-2025`)

### 5.2 Deploy Edge Functions

Deploy all 4 edge functions to Supabase.

## Step 6: Suunto Developer Portal Configuration

1. **OAuth Settings**:
   - Redirect URI: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/suunto-auth-callback`
   - Authorization Callback Domain: `gvfhtiljkybbrbxoyqsq.supabase.co`

2. **Webhook Settings**:
   - Webhook URL: `https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/suunto-activity-webhook`
   - Verify Token: `suunto-webhook-verify-token-2025` (must match Supabase secret)
   - Subscribe to: `workout.created`, `workout.updated` (check Suunto docs for exact event names)

## Step 7: Testing

1. **Test OAuth Flow**:
   - Connect Suunto in app
   - Verify tokens stored in `suunto_connections`
   - Check connection appears in app

2. **Test Activity Sync**:
   - Create test activity in Suunto app
   - Verify webhook received
   - Check activity in `suunto_activities` table
   - Verify push notification sent

3. **Test Historical Sync**:
   - Trigger historical sync (if implemented)
   - Verify activities fetched and stored

## API Endpoints Reference

Based on Suunto API (verify in actual documentation):

```
Authorization: https://cloudapi.suunto.com/oauth/authorize
Token Exchange: https://cloudapi.suunto.com/oauth/token
Workouts List: GET https://cloudapi.suunto.com/v2/workouts
Workout Details: GET https://cloudapi.suunto.com/v2/workouts/{id}
Workout Streams: GET https://cloudapi.suunto.com/v2/workouts/{id}/streams
Health Daily: GET https://cloudapi.suunto.com/v2/health/daily/{date}
User Info: GET https://cloudapi.suunto.com/v2/user
```

## OAuth 2.0 Flow Details

1. **Authorization Request**:
   ```
   GET https://cloudapi.suunto.com/oauth/authorize?
       response_type=code&
       client_id={CLIENT_ID}&
       redirect_uri={REDIRECT_URI}&
       scope={SCOPES}&
       state={STATE}
   ```

2. **Token Exchange**:
   ```
   POST https://cloudapi.suunto.com/oauth/token
   Content-Type: application/x-www-form-urlencoded
   
   grant_type=authorization_code&
   code={AUTHORIZATION_CODE}&
   redirect_uri={REDIRECT_URI}&
   client_id={CLIENT_ID}&
   client_secret={CLIENT_SECRET}
   ```

3. **Token Refresh**:
   ```
   POST https://cloudapi.suunto.com/oauth/token
   Content-Type: application/x-www-form-urlencoded
   
   grant_type=refresh_token&
   refresh_token={REFRESH_TOKEN}&
   client_id={CLIENT_ID}&
   client_secret={CLIENT_SECRET}
   ```

## Notes

- Suunto API may have rate limits - implement retry logic
- Token expiration times may vary - check API docs
- Webhook event names may differ - verify in Suunto documentation
- Some endpoints may require different scopes - check required permissions


