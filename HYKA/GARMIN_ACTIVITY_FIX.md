# Garmin Activity Data Fix

## Issues Fixed

1. **Activity Type Detection** - Now checks multiple fields and infers from activity name
2. **API Fetching** - Tries multiple endpoints and domains
3. **Better Logging** - Shows what data is actually received from Garmin
4. **Data Validation** - Warns if activity has no meaningful data

## Changes Made

### 1. Improved Activity Type Detection
- Checks `activityType`, `type`, `sportType` fields
- Infers from activity name if type is missing
- Better handling of object vs string formats

### 2. Enhanced API Fetching
- Tries multiple Garmin API endpoints:
  - `connectapi.garmin.com/activity-service/activity/{id}`
  - `apis.garmin.com/activity-service/activity/{id}`
  - Both with `/summary` suffix
- Better error handling and logging

### 3. Better Logging
- Logs full summary structure when received
- Shows what data is extracted
- Warns if activity has no meaningful data

## Deployment

```bash
cd supabase
npx supabase functions deploy garmin-activity-store --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
```

## Testing

After deployment, create a new activity on Garmin and check:
1. Activity type should be "RUNNING" not "UNKNOWN"
2. Distance, duration, HR should be populated
3. Check logs for detailed data extraction

## Common Issues

### Still getting "UNKNOWN" activity type?
- Check logs for "Activity type extracted" message
- Verify Garmin is sending activityType in webhook
- May need to wait for Garmin to fully process activity

### Still getting 403/404 errors?
- Activity may still be processing (wait 1-5 minutes)
- Access token may lack permissions
- Try reconnecting Garmin in the app

### FIT file still 404?
- FIT files can take 1-5 minutes to be available
- Garmin will send another webhook when FIT is ready
- Or manually retry after a few minutes


