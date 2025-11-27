# Push Notifications Setup for Activity Completion

## Overview

This guide explains how to set up push notifications that alert users when they complete a Garmin activity, with a message like:
> "🎉 Congrats on Your Run! Check out your 5.2km run and see how it influences your upcoming race performance"

## Architecture

```
Garmin Activity → Webhook → garmin-activity-store → garmin-activity-notify → APNs → iOS Device
```

## Step 1: Set Up Apple Push Notification Service (APNs)

### 1.1 Create APNs Key in Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Click **"Keys"** → **"+"** to create a new key
3. Enable **"Apple Push Notifications service (APNs)"**
4. Register the key and download the `.p8` file
5. Note the **Key ID** and your **Team ID**

### 1.2 Store APNs Credentials in Supabase

Add these environment variables to your Supabase project:

```bash
APNS_KEY_ID=YOUR_KEY_ID
APNS_TEAM_ID=YOUR_TEAM_ID
APNS_BUNDLE_ID=com.hyka.app
APNS_ENVIRONMENT=production  # or 'development' for testing
APNS_KEY_PATH=/path/to/your/key.p8  # Or store key content as env var
```

**In Supabase Dashboard:**
1. Go to **Project Settings → Edge Functions → Secrets**
2. Add each environment variable

## Step 2: Create Database Table for Device Tokens

Run this SQL in Supabase SQL Editor:

```sql
-- Create user_devices table to store device tokens
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  device_type TEXT NOT NULL CHECK (device_type IN ('ios', 'android')),
  push_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_token)
);

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can manage their own devices"
  ON user_devices
  FOR ALL
  USING (auth.uid() = user_id);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_push_enabled ON user_devices(user_id, push_enabled) WHERE push_enabled = true;
```

## Step 3: Update iOS App

### 3.1 Add Push Notification Capability

1. Open your Xcode project
2. Go to **Signing & Capabilities**
3. Click **"+ Capability"**
4. Add **"Push Notifications"**
5. Add **"Background Modes"** → Enable **"Remote notifications"**

### 3.2 Update AppDelegate or MainApp

Add push notification registration:

```swift
// In MainApp.swift or AppDelegate
import UserNotifications

@main
struct HYKAApp: App {
    @StateObject var session = SessionManager()
    
    init() {
        // Request notification permissions on app launch
        Task {
            await PushNotificationService.shared.requestAuthorization()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .onAppear {
                    // Register for remote notifications
                    UIApplication.shared.registerForRemoteNotifications()
                }
        }
    }
}
```

### 3.3 Handle Device Token Registration

Add to your app delegate or main app:

```swift
// Handle device token
func application(_ application: UIApplication, 
                didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Task {
        if let userId = await SessionManager.shared.currentUser?.id {
            await PushNotificationService.shared.registerDeviceToken(deviceToken, userId: userId)
        }
    }
}

func application(_ application: UIApplication, 
                didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
}
```

### 3.4 Implement Device Token Saving

Update `PushNotificationService.swift` to save token to Supabase:

```swift
private func saveDeviceTokenToSupabase(token: String, userId: UUID) async {
    do {
        let response = try await Supa.client
            .from("user_devices")
            .upsert([
                "user_id": userId.uuidString,
                "device_token": token,
                "device_type": "ios",
                "push_enabled": true,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ], options: UpsertOptions(onConflict: "user_id,device_token"))
            .execute()
        
        print("✅ Device token saved to Supabase")
    } catch {
        print("❌ Error saving device token: \(error)")
    }
}
```

## Step 4: Update Activity Store Function

Modify `garmin-activity-store/index.ts` to call notification service after storing activity:

```typescript
// After activity is stored successfully (around line 250)
console.log("✅ Activity stored successfully in database")

// Send push notification (async, don't wait)
try {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const notifyUrl = `${supabaseUrl}/functions/v1/garmin-activity-notify`
  
  fetch(notifyUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${supabaseKey}`,
      'apikey': supabaseKey
    },
    body: JSON.stringify({
      user_id: userId,
      activity_id: activity.id,
      activity_name: activityName,
      activity_type: activityType,
      distance_meters: distanceMeters,
      duration_seconds: durationSeconds
    })
  }).catch(err => {
    console.error("⚠️ Failed to send notification (non-critical):", err)
  })
} catch (error) {
  console.error("⚠️ Error triggering notification (non-critical):", error)
}
```

## Step 5: Handle Deep Links

Update your deep link handler to show activity details:

```swift
// In MainApp.swift or ContentView
.onOpenURL { url in
    if url.scheme == "hyka" && url.host == "activity" {
        let activityId = url.pathComponents.last
        // Navigate to activity detail view
        // Show race performance impact
    }
}
```

## Step 6: Deploy Edge Function

```bash
supabase functions deploy garmin-activity-notify
```

## Step 7: Make Function Public

In Supabase Dashboard:
1. Go to **Edge Functions → garmin-activity-notify**
2. **Disable** "Require Authentication" (or it can be called internally)

## Testing

### Test Notification Service Directly:

```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-notify" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "apikey: YOUR_SERVICE_ROLE_KEY" \
  -d '{
    "user_id": "YOUR_USER_ID",
    "activity_id": "test-activity-id",
    "activity_name": "Test Run",
    "activity_type": "Running",
    "distance_meters": 5200,
    "duration_seconds": 1800
  }'
```

## Notification Flow

1. **User completes activity** on Garmin device
2. **Garmin sends webhook** → `garmin-activity-push`
3. **Activity stored** → `garmin-activity-store`
4. **Notification triggered** → `garmin-activity-notify`
5. **Notification sent** → APNs → iOS device
6. **User taps notification** → Deep link opens app → Shows activity and race performance

## Customization

### Customize Notification Message:

Edit `garmin-activity-notify/index.ts`:

```typescript
const title = "🎉 Congrats on Your Run!"
const body = `Check out your ${distanceKm}km run and see how it influences your upcoming race performance`
```

### Add Race Performance Data:

Query upcoming races and calculate impact:

```typescript
// In garmin-activity-notify, after getting activity:
const { data: races } = await supabase
  .from('race_plans')
  .select('id, title, race_date')
  .eq('user_id', userId)
  .gte('race_date', new Date().toISOString())
  .order('race_date', { ascending: true })
  .limit(1)

if (races && races.length > 0) {
  const nextRace = races[0]
  body = `Check out your ${distanceKm}km run and see how it influences your ${nextRace.title} performance`
  deepLinkData.next_race_id = nextRace.id
}
```

## Troubleshooting

### Notifications Not Arriving:

1. **Check APNs credentials** - Verify Key ID, Team ID, Bundle ID
2. **Check device token** - Verify token is saved in `user_devices` table
3. **Check APNs logs** - Look for errors in edge function logs
4. **Test with curl** - Send test notification directly
5. **Check iOS settings** - User may have disabled notifications

### Common Issues:

- **"Invalid device token"** - Token expired or invalid, re-register device
- **"APNs authentication failed"** - Check JWT token generation
- **"No devices found"** - User hasn't registered device token yet

## Next Steps

1. Implement APNs JWT signing in `garmin-activity-notify`
2. Add device token registration in iOS app
3. Update `garmin-activity-store` to trigger notifications
4. Implement deep link handling for activity details
5. Add race performance calculation and display

---

**Note**: APNs JWT signing requires a JWT library that supports ES256. You may need to use a library like `djwt` for Deno or implement it manually.

