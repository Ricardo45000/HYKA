# Garmin FIT File Download Fix

## Issues Fixed

1. **FIT File 401 Error** - Now properly handles Garmin's direct download URLs with tokens
2. **File Payload Data Extraction** - Extracts activity data (type, name) from file payload
3. **CallbackURL vs callbackUrl** - Handles both capital and lowercase variants

## The Problem

Garmin provides two types of FIT file download URLs:

1. **Direct Download URL** (from file payload):
   ```
   https://apis.garmin.com/wellness-api/rest/activityFile?id=510833743203&token=AAAAAGk4RnlcJ3B1
   ```
   - Has token in query string
   - Does NOT require OAuth Bearer token
   - Just download directly

2. **API Endpoint** (constructed):
   ```
   https://connectapi.garmin.com/activity-service/activity/{id}/file/fit
   ```
   - Requires OAuth Bearer token
   - Uses Authorization header

The code was trying to use OAuth token for direct download URLs, causing 401 errors.

## Changes Made

### 1. Extract `callbackURL` (capital) from File Payload
- File payload uses `callbackURL` (capital), not `callbackUrl`
- Now checks both variants

### 2. Extract Activity Data from File Payload
- File payload contains `activityType`, `activityName`, `deviceName`
- Now extracts this data instead of creating minimal summary

### 3. Smart FIT File Download
- Detects if URL has token in query string (direct download)
- Only uses OAuth token for API endpoints
- Better error handling for 401/403 errors

## Deployment

```bash
cd supabase
npx supabase functions deploy garmin-activity-store --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
```

## Testing

After deployment, create a new activity on Garmin and check logs:
1. Should see "Using direct download URL (has token in query string)"
2. FIT file should download successfully
3. Activity should have correct type and name from file payload

## What to Expect

### Before Fix:
- ❌ FIT file download: 401 Unauthorized
- ❌ Activity type: UNKNOWN
- ❌ Activity name: "Uncategorized Activity"

### After Fix:
- ✅ FIT file downloads successfully
- ✅ Activity type: RUNNING (from file payload)
- ✅ Activity name: "Hamburg Running" (from file payload)


