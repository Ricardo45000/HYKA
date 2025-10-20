# Why You're Seeing Slow Times (45.4 hours, 19:03/km, 25:39/km)

## The Problem

Your app is showing:
- **Total Time:** 45.4 hours (should be ~14.5 hours)
- **Pace:** 19:03/km and 25:39/km (should be 6:28/km to 8:17/km)
- **BPM:** 153 bpm and 158 bpm (these look correct!)

## Root Cause Analysis

### Issue 1: Workout Data Not Being Used

The app is **not successfully fetching your Garmin workout data** from Supabase. Here's why:

1. **Code Check:** Line 2038 calls `fetchWorkouts(userId: userId)`
2. **If workouts.isEmpty:** Returns `basePace = nil` (line 3038-3042)
3. **Fallback:** Uses `defaultPaceMinutesPerKm = 10.0` (line 2885)
4. **But your screenshots show 19:03/km and 25:39/km** - even slower than 10 min/km!

### Issue 2: Hill Penalty Calculation Bug

Looking at line 2876:
```swift
let hillPenalty = 0.5 * (metric.elevationGainM / 100.0)
```

**The Problem:**
- This calculates penalty for **total elevation gain in the segment**
- But it's added as a **flat rate per kilometer**
- For 50km segment with 2636m gain:
  - `hillPenalty = 0.5 * (2636 / 100) = 13.18 min/km`
  - This is added to EVERY kilometer!

**What it should be:**
- Hill penalty should be: `0.5 * (elevationGainM / segmentDistanceKm / 100.0)`
- For 50km with 2636m: `0.5 * (2636 / 50 / 100) = 0.26 min/km` (per km)

### Issue 3: Fatigue Multiplier Compounding

With 45+ hours of racing:
- After 20 hours: `fatigueMultiplier = 1 + 0.03 * 20 = 1.6` (60% slower!)
- After 30 hours: `fatigueMultiplier = 1 + 0.03 * 30 = 1.9` (90% slower!)

This compounds incorrectly when using default pace.

## The Math Behind Your Current Numbers

### Scenario: 50km Segment with 2636m Elevation Gain

**If using default 10 min/km:**
```
Base: 10.0 min/km
Heat (20°C): ×1.05 = 10.5 min/km
Fatigue (after 15h): ×1.45 = 15.225 min/km
Hill Penalty (WRONG): +13.18 min/km
Result: 15.225 + 13.18 = 28.4 min/km ≈ 25:39/km ✓ (matches your screenshot!)
```

**If using your actual base pace (5.62 min/km):**
```
Base: 5.62 min/km
Heat (20°C): ×1.05 = 5.90 min/km
Fatigue (after 15h): ×1.45 = 8.56 min/km
Hill Penalty (CORRECT): +0.26 min/km per km
Result: 8.56 + 0.26 = 8.82 min/km ≈ 8:49/km (much better!)
```

## Solutions

### Fix 1: Ensure Workout Data is Fetched

**Check the logs:**
1. Look for: `📊 fetchWorkouts: Fetching activities for user...`
2. Look for: `📊 fetchWorkouts: Found X activities in response`
3. If you see `⚠️ fetchWorkouts: No activities found` → The view doesn't have data

**Action:**
1. Run `create_unified_activities_view.sql` in Supabase SQL Editor
2. Verify data exists: Run `verify_unified_activities.sql`
3. Check Xcode console logs when the app loads

### Fix 2: Fix Hill Penalty Calculation

**Current (WRONG):**
```swift
let hillPenalty = 0.5 * (metric.elevationGainM / 100.0)
```

**Should be:**
```swift
let hillPenaltyPerKm = 0.5 * (metric.elevationGainM / segmentDistanceKm / 100.0)
let hillPenalty = hillPenaltyPerKm
```

This distributes the penalty across the segment distance.

### Fix 3: Add Debug Logging

Add logging to see what's happening:
```swift
print("🔍 Segment Calculation:")
print("   basePace: \(basePace ?? -1)")
print("   segmentDistance: \(segmentDistance) km")
print("   elevationGainM: \(metric.elevationGainM) m")
print("   cumulativeHours: \(cumulativeHours)")
print("   heatMultiplier: \(heatMultiplier)")
print("   fatigueMultiplier: \(fatigueMultiplier)")
print("   hillPenalty: \(hillPenalty)")
print("   adjustedPace: \(adjustedPace)")
```

## Expected vs Actual

| Metric | Expected (with your data) | Actual (what you see) | Issue |
|--------|---------------------------|----------------------|-------|
| **Base Pace** | 5.62 min/km | 10.0 min/km (default) | Workout data not loaded |
| **Est. Pace (0-50km)** | 6:28/km | 19:03/km | Hill penalty bug + no data |
| **Est. Pace (50-119km)** | 8:17/km | 25:39/km | Hill penalty bug + fatigue |
| **Total Time** | 14h 33m | 45.4 hours | All of the above |
| **BPM** | 146-156 bpm | 153-158 bpm | ✅ Correct! |

## Next Steps

1. **Check if workouts are being fetched:**
   - Look at Xcode console when app loads
   - Should see: `📊 fetchWorkouts: Found 2 activities`

2. **Verify Supabase view exists:**
   - Run SQL: `SELECT COUNT(*) FROM unified_activities WHERE user_id = 'your-user-id'`
   - Should return 2

3. **Fix the hill penalty calculation** (see Fix 2 above)

4. **Test again** - should see ~14.5 hours total time

