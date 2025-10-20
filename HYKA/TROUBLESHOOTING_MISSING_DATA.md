# Troubleshooting: Why You Don't See Calculated Results

## Step 1: Check Xcode Console Logs

When you run the app and view the race plan, look for these logs in Xcode console:

### Expected Logs (if data is loaded):
```
📊 fetchWorkouts: Fetching activities for user...
📊 fetchWorkouts: Found 2 activities in response
   ✓ Activity: Hamburg Running (garmin) - 24187m, 8509s, HR: 148/172 bpm
   ✓ Activity: Hamburg Running (garmin) - 16113m, 5204s, HR: 145/165 bpm
✅ fetchWorkouts: Successfully parsed 2 workouts

📊 RacePlanView: Fetched 2 workouts
   First workout: 24187.0m, HR: 148/172 bpm

📊 buildAthleteAnalytics: Processing 2 workouts
✅ buildAthleteAnalytics: Final results:
   averageHR: 146.5 bpm
   maxHR: 172.0 bpm
   basePace: 5.62 min/km
   caloriesPerHour: 600.0 kcal/h
   fatigueRate: 0.03 per hour

📊 RacePlanView: Analytics calculated:
   basePace: Optional(5.62) min/km
   maxHR: Optional(172.0) bpm
   avgHR: Optional(146.5) bpm
   caloriesPerHour: 600.0 kcal/h

   💓 Segment 1: HR = 133 bpm (maxHR: 172.0, percent: 0.775)
```

### If You See This (no data):
```
⚠️ fetchWorkouts: No activities found in response
⚠️ buildAthleteAnalytics: No workouts found - using defaults
   ⚠️ Segment 1: No maxHR available - showing 'Connexion needed'
```

---

## Step 2: Verify Supabase View Exists

1. Open **Supabase Dashboard** → **SQL Editor**
2. Run this query:
```sql
SELECT COUNT(*) FROM unified_activities 
WHERE user_id = 'your-user-id-here';
```

**Expected:** Should return 2 (or more)

**If returns 0:**
- The view might not exist
- Or data isn't in the view

---

## Step 3: Create the View (if missing)

Run `create_unified_activities_view.sql` in Supabase SQL Editor:

```sql
-- This creates the unified_activities view
CREATE OR REPLACE VIEW unified_activities AS
SELECT 
    w.id,
    w.user_id,
    w.provider,
    ...
FROM workouts w
WHERE w.provider != 'garmin'
UNION ALL
SELECT 
    ga.id,
    ga.user_id,
    'garmin' AS provider,
    ...
FROM garmin_activities ga;
```

---

## Step 4: Verify Data in Tables

Check if data exists in the source tables:

```sql
-- Check garmin_activities
SELECT COUNT(*) FROM garmin_activities 
WHERE user_id = 'your-user-id-here';

-- Check workouts
SELECT COUNT(*) FROM workouts 
WHERE user_id = 'your-user-id-here';
```

**Expected:** Should have data in `garmin_activities` table

---

## Step 5: Check Your User ID

Make sure you're using the correct user ID. In Xcode console, look for:
```
📊 fetchWorkouts: Fetching activities for user fc600af9-2926-4b86-b841-25a25d17c10c
```

Verify this matches your actual user ID in Supabase.

---

## Common Issues & Solutions

### Issue 1: "No activities found in response"
**Cause:** `unified_activities` view doesn't exist or is empty

**Solution:**
1. Run `create_unified_activities_view.sql` in Supabase
2. Verify data exists: `SELECT * FROM unified_activities LIMIT 5;`
3. Restart the app

---

### Issue 2: "No workouts found - using defaults"
**Cause:** `fetchWorkouts()` returned empty array

**Solution:**
1. Check if view exists (Step 3)
2. Check if data exists in `garmin_activities` table
3. Verify user_id matches

---

### Issue 3: Shows "Connexion needed" for BPM/Pace
**Cause:** Analytics calculated but `maxHR` or `basePace` is nil

**Solution:**
1. Check logs for `maxHR: nil` or `basePace: nil`
2. Verify workouts have `max_heart_rate` and valid distance/time
3. Check if workouts are being filtered out (need distance > 0, elapsed > 0)

---

### Issue 4: Wrong values displayed
**Cause:** Calculations using wrong data or formulas

**Solution:**
1. Check logs for calculated values
2. Compare with expected values from `SEGMENT_CALCULATIONS.md`
3. Verify temperature, elevation, and other inputs

---

## Quick Test

Run this in Supabase SQL Editor to test everything:

```sql
-- 1. Check if view exists
SELECT COUNT(*) as view_count FROM unified_activities;

-- 2. Check your data
SELECT 
    id,
    provider,
    name,
    distance_meters,
    duration_seconds,
    average_heart_rate,
    max_heart_rate,
    start_time
FROM unified_activities
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
ORDER BY start_time DESC
LIMIT 5;

-- 3. Verify calculations would work
SELECT 
    name,
    distance_meters,
    duration_seconds,
    (duration_seconds::float / (distance_meters / 1000.0) / 60.0) as pace_min_per_km,
    average_heart_rate,
    max_heart_rate
FROM unified_activities
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
AND distance_meters > 0
AND duration_seconds > 0;
```

---

## Next Steps

1. **Run the app** and check Xcode console logs
2. **Share the logs** - especially:
   - How many workouts were fetched?
   - What are the analytics values?
   - Are there any errors?
3. **Check Supabase** - verify the view exists and has data
4. **Compare results** - do the calculated values match `SEGMENT_CALCULATIONS.md`?

The logs will tell us exactly where the problem is! 🔍

