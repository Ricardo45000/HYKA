# Test Notification via Supabase Dashboard

## Quick Test

1. **Go to Supabase Dashboard:**
   - Edge Functions → `garmin-activity-notify` → **Invoke**

2. **Set Method:** POST

3. **Use this payload:**
```json
{
  "user_id": "fc600af9-2926-4b86-b841-25a25d17c10c",
  "activity_id": "test-123",
  "activity_name": "Test Run",
  "activity_type": "Running",
  "distance_meters": 5000,
  "duration_seconds": 1800
}
```

4. **Click "Invoke"**

5. **Check the response:**
   - Should show `"success": true`
   - Should show `"devices_notified": 1` (or more)

6. **Check your device:**
   - You should receive a notification with:
     - **Title:** "Distance: 5.0 km - Pace: 6:00 m/km"
     - **Body:** "Check your HYKA digital twin for your upcoming event"

## If It Fails

Check the logs:
- Dashboard → Edge Functions → `garmin-activity-notify` → **Logs**
- Look for error messages

Common issues:
- `BadEnvironmentKeyInToken` → Wrong APNs environment
- `BadDeviceToken` → Device token doesn't match environment
- `APNs not configured` → Missing APNs secrets

## Or Use the Script

```bash
export SUPABASE_SERVICE_ROLE_KEY='your-key-here'
chmod +x test_notification_now.sh
./test_notification_now.sh
```


