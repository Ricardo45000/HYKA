# Complete Garmin Activity Store Fix

## Issues Identified and Fixed

### 1. Missing Data Fields ❌ → ✅

**Problem:** Activity stored but missing:
- `total_elevation_gain_meters`: null (should be 90.31)
- `total_elevation_loss_meters`: null (should be 94.01)
- `calories`: null (should be 586)
- `average_cadence`: null (should be 173.77)
- `max_cadence`: null (should be 188)

**Root Cause:** Field name mismatches - Garmin uses:
- `totalElevationGainInMeters` (not `elevationGainInMeters`)
- `activeKilocalories` (not `calories`)
- `averageRunCadenceInStepsPerMinute` (not `averageRunningCadenceInStepsPerMinute`)

**Fix:** Updated field extraction to check correct field names first:
```typescript
total_elevation_gain_meters: summary.totalElevationGainInMeters || ...
calories: summary.activeKilocalories || ...
average_cadence: summary.averageRunCadenceInStepsPerMinute || ...
```

### 2. FIT File Download 400 Error ❌ → ✅

**Problem:** Direct download URL returns `{"errorMessage":"Authorization header not found"}`

**Root Cause:** Garmin's wellness-api endpoint requires Authorization header even though token is in query string

**Fix:** Extract token from query string and use in Authorization header:
```typescript
const token = urlObj.searchParams.get('token')
headers['Authorization'] = `Bearer ${token}`
```

### 3. has_fit_file Not Updated ❌ → ✅

**Problem:** `has_fit_file` stays `false` even after FIT file is stored

**Root Cause:** Only FIT processor updates this flag, but if processor fails, flag never updates

**Fix:** Update `has_fit_file = true` immediately after storing FIT file (processor will also update it)

## Changes Made

### Data Extraction
- ✅ Added `totalElevationGainInMeters` check (before `elevationGainInMeters`)
- ✅ Added `totalElevationLossInMeters` check
- ✅ Added `activeKilocalories` check (before `calories`)
- ✅ Added `averageRunCadenceInStepsPerMinute` check (before `averageRunningCadenceInStepsPerMinute`)
- ✅ Added `maxRunCadenceInStepsPerMinute` check

### FIT File Download
- ✅ Extract token from query string for direct download URLs
- ✅ Use token in Authorization header for wellness-api endpoints
- ✅ Better error handling for 400/401 errors

### Database Updates
- ✅ Update `has_fit_file = true` after storing FIT file
- ✅ FIT processor will also update it (redundant but safe)

## Deployment

```bash
cd supabase
npx supabase functions deploy garmin-activity-store --project-ref gvfhtiljkybbrbxoyqsq --no-verify-jwt
```

## Expected Results After Fix

### Activity Data:
- ✅ `total_elevation_gain_meters`: 90.31 (from `totalElevationGainInMeters`)
- ✅ `total_elevation_loss_meters`: 94.01 (from `totalElevationLossInMeters`)
- ✅ `calories`: 586 (from `activeKilocalories`)
- ✅ `average_cadence`: 173.77 (from `averageRunCadenceInStepsPerMinute`)
- ✅ `max_cadence`: 188 (from `maxRunCadenceInStepsPerMinute`)

### FIT File:
- ✅ Downloads successfully using token from query string
- ✅ Stored in `garmin_fit_files` table
- ✅ `has_fit_file` set to `true`
- ✅ FIT processor extracts samples

## Testing

After deployment, create a new activity and verify:
1. All data fields are populated (check database)
2. FIT file downloads successfully (check logs)
3. `has_fit_file = true` (check database)
4. Activity samples extracted (check `garmin_activity_samples` table)


