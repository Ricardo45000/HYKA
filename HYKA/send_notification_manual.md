# How to Send a Test Notification to a Specific User

## Quick Method: Using the Script

1. **Set your Supabase Service Role Key:**
   ```bash
   export SUPABASE_SERVICE_ROLE_KEY='your-service-role-key-here'
   ```

2. **Run the script:**
   ```bash
   chmod +x send_test_notification.sh
   ./send_test_notification.sh
   ```

3. **With custom parameters:**
   ```bash
   ./send_test_notification.sh \
     "84b13928-a931-4841-9289-bf2ab30cb07d" \
     "test-activity-123" \
     "Morning Run" \
     10000 \
     2400
   ```

   Parameters:
   - `user_id` (required) - The UUID of the user
   - `activity_id` (optional) - Activity identifier
   - `activity_name` (optional) - Name of the activity
   - `distance_meters` (optional) - Distance in meters (default: 5000 = 5km)
   - `duration_seconds` (optional) - Duration in seconds (default: 1800 = 30 min)

## Manual Method: Using curl

```bash
curl -X POST "https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-activity-notify" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "84b13928-a931-4841-9289-bf2ab30cb07d",
    "activity_id": "test-activity-123",
    "activity_name": "Test Run",
    "activity_type": "Running",
    "distance_meters": 5000,
    "duration_seconds": 1800
  }'
```

## Using Supabase Dashboard

1. Go to **Edge Functions** → **garmin-activity-notify** → **Invoke**
2. Set method to **POST**
3. Use this payload:
   ```json
   {
     "user_id": "84b13928-a931-4841-9289-bf2ab30cb07d",
     "activity_id": "test-activity-123",
     "activity_name": "Test Run",
     "activity_type": "Running",
     "distance_meters": 5000,
     "duration_seconds": 1800
   }
   ```
4. Click **Invoke**

## Notification Content

The notification will show:
- **Title:** "Distance: X km - Pace: Y m/km"
- **Body:** "Check your HYKA digital twin for your upcoming event"

Pace is automatically calculated from distance and duration.

## Requirements

1. **User must have a device token registered:**
   ```sql
   SELECT * FROM user_devices 
   WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d' 
   AND push_enabled = true;
   ```

2. **APNs must be configured:**
   - `APNS_KEY_ID`
   - `APNS_TEAM_ID`
   - `APNS_KEY_CONTENT`
   - `APNS_BUNDLE_ID` (defaults to `app.hyka.com`)

## Troubleshooting

### No notification received?

1. **Check device token exists:**
   ```sql
   SELECT device_token, device_type, push_enabled 
   FROM user_devices 
   WHERE user_id = 'your-user-id';
   ```

2. **Check Supabase logs:**
   - Go to **Edge Functions** → **garmin-activity-notify** → **Logs**
   - Look for: `✅ Push notification sent to device`

3. **Check APNs configuration:**
   - Verify all APNs secrets are set in Supabase
   - Check logs for APNs errors

4. **Verify device has push notifications enabled:**
   - User must have granted notification permissions
   - Device must be registered in `user_devices` table

### Get Service Role Key

1. Go to **Supabase Dashboard** → **Settings** → **API**
2. Copy the **service_role** key (not the anon key)
3. Use it as `SUPABASE_SERVICE_ROLE_KEY` environment variable


