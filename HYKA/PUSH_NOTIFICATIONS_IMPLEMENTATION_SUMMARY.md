# Push Notifications Implementation Summary

## What Was Created

### 1. **Edge Function: `garmin-activity-notify`**
   - Sends push notifications when activities are stored
   - Looks up user's device tokens from database
   - Sends notifications via Apple Push Notification service (APNs)
   - Includes deep link to activity and race performance

### 2. **iOS Service: `PushNotificationService`**
   - Handles push notification permissions
   - Registers device tokens with Supabase
   - Handles notification taps and deep links

### 3. **Database Table: `user_devices`**
   - Stores device tokens for each user
   - Tracks push notification preferences
   - SQL script: `create_user_devices_table.sql`

### 4. **Updated: `garmin-activity-store`**
   - Now triggers push notifications after storing activities
   - Calls `garmin-activity-notify` asynchronously

### 5. **Updated: `MainApp.swift`**
   - Registers for push notifications on app launch
   - Handles device token registration
   - Handles deep links for activities

## Setup Steps

### Step 1: Create APNs Key
1. Go to [Apple Developer Portal](https://developer.apple.com/account/resources/authkeys/list)
2. Create new key with **APNs** enabled
3. Download `.p8` file
4. Note **Key ID** and **Team ID**

### Step 2: Add APNs Credentials to Supabase
In Supabase Dashboard → Project Settings → Edge Functions → Secrets:
- `APNS_KEY_ID` = Your Key ID
- `APNS_TEAM_ID` = Your Team ID  
- `APNS_BUNDLE_ID` = `com.hyka.app`
- `APNS_ENVIRONMENT` = `production` (or `development` for testing)
- `APNS_KEY_PATH` = Path to `.p8` file (or store key content)

### Step 3: Create Database Table
Run `create_user_devices_table.sql` in Supabase SQL Editor

### Step 4: Add Push Notification Capability in Xcode
1. Open Xcode project
2. Go to **Signing & Capabilities**
3. Add **"Push Notifications"** capability
4. Add **"Background Modes"** → Enable **"Remote notifications"**

### Step 5: Deploy Edge Function
```bash
supabase functions deploy garmin-activity-notify
```

### Step 6: Make Function Public (Optional)
If calling from `garmin-activity-store`, it can use service role key (internal call).
If calling from app, make it public in Supabase Dashboard.

## How It Works

### Flow:
1. **User completes activity** on Garmin device
2. **Garmin sends webhook** → `garmin-activity-push`
3. **Activity stored** → `garmin-activity-store`
4. **Notification triggered** → `garmin-activity-notify` (async)
5. **Notification sent** → APNs → iOS device
6. **User taps notification** → Deep link `hyka://activity/{id}` → Opens app → Shows activity

### Notification Message:
```
Title: "🎉 Congrats on Your Run!"
Body: "Check out your 5.2km run and see how it influences your upcoming race performance"
```

### Deep Link Data:
```json
{
  "type": "activity_completed",
  "activity_id": "uuid",
  "activity_name": "Morning Run",
  "activity_type": "Running",
  "distance_km": 5.2,
  "duration_seconds": 1800,
  "deep_link": "hyka://activity/{id}"
}
```

## Next Steps

### 1. Implement APNs JWT Signing
The `garmin-activity-notify` function needs proper JWT signing. You'll need to:
- Use a JWT library that supports ES256 (e.g., `djwt` for Deno)
- Load the `.p8` key file
- Sign the JWT token with ES256 algorithm

Example using `djwt`:
```typescript
import { create, getNumericDate } from "https://deno.land/x/djwt@v2.8/mod.ts"

async function generateAPNsToken(): Promise<string> {
  const key = await Deno.readTextFile(APNS_KEY_PATH)
  const header = { alg: "ES256", kid: APNS_KEY_ID }
  const payload = {
    iss: APNS_TEAM_ID,
    iat: getNumericDate(new Date())
  }
  return await create(header, payload, key)
}
```

### 2. Implement Activity Detail View
Create a view that shows:
- Activity details (distance, pace, heart rate, etc.)
- Race performance impact
- How this activity affects upcoming race predictions

### 3. Handle Deep Links
Update your navigation to handle `hyka://activity/{id}`:
```swift
if scheme == "hyka" && host == "activity" {
    let activityId = path.replacingOccurrences(of: "/", with: "")
    // Navigate to activity detail view
    // Show race performance impact
}
```

### 4. Add Race Performance Calculation
In `garmin-activity-notify`, query upcoming races and calculate impact:
```typescript
const { data: races } = await supabase
  .from('race_plans')
  .select('id, title, race_date')
  .eq('user_id', userId)
  .gte('race_date', new Date().toISOString())
  .order('race_date', { ascending: true })
  .limit(1)
```

## Testing

### Test Notification Service:
```bash
curl -X POST "https://YOUR_PROJECT.supabase.co/functions/v1/garmin-activity-notify" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "apikey: YOUR_SERVICE_ROLE_KEY" \
  -d '{
    "user_id": "YOUR_USER_ID",
    "activity_id": "test-id",
    "activity_name": "Test Run",
    "activity_type": "Running",
    "distance_meters": 5200,
    "duration_seconds": 1800
  }'
```

### Test Device Token Registration:
1. Open app
2. Grant notification permissions
3. Check `user_devices` table in Supabase
4. Should see device token saved

## Current Status

✅ **Created:**
- Edge function for notifications
- iOS push notification service
- Database table schema
- Integration with activity store

⚠️ **Needs Implementation:**
- APNs JWT signing (requires JWT library)
- Activity detail view navigation
- Race performance calculation
- Deep link handling for activities

## Files Created/Modified

1. `supabase/functions/garmin-activity-notify/index.ts` - NEW
2. `supabase/functions/garmin-activity-store/index.ts` - UPDATED
3. `ios/Services/PushNotificationService.swift` - NEW
4. `ios/App/MainApp.swift` - UPDATED
5. `create_user_devices_table.sql` - NEW
6. `PUSH_NOTIFICATIONS_SETUP.md` - NEW (detailed guide)

---

**The infrastructure is ready! You just need to:**
1. Set up APNs credentials
2. Implement JWT signing
3. Test the flow end-to-end

