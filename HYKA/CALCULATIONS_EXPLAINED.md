# Race Plan Calculations Explained

This document explains how **Est. Time**, **BPM (Heart Rate)**, and **Est. Pace** are calculated in the race plan.

---

## 1. Est. Time (Estimated Time)

**Formula:**
```
sectionMinutes = adjustedPace * segmentDistance
sectionHours = sectionMinutes / 60.0
durationString = formatDuration(hours: sectionHours)
```

**Where:**
- `adjustedPace` = Adjusted pace in minutes per kilometer (see Est. Pace calculation below)
- `segmentDistance` = Distance of the segment in kilometers
- `sectionHours` = Time in hours for the segment

**Example:**
- If adjusted pace = 10.0 min/km and segment = 5 km
- `sectionMinutes = 10.0 * 5 = 50 minutes`
- `sectionHours = 50 / 60 = 0.833 hours = 50 minutes`

**Code Location:** `RacePlanView.swift:2878-2881`

---

## 2. BPM (Heart Rate / Beats Per Minute)

**Formula:**
```
targetHR = maxHR * hrPercent
```

**HR Percentage by Race Fraction:**
- **First 25% of race:** `hrPercent = 0.75` (75% of max HR)
- **25-50% of race:** `hrPercent = 0.775` (77.5% of max HR)
- **After 50% of race:** `hrPercent = 0.80` (80% of max HR)

**Max HR Calculation:**
```
maxHR = (averageHR / 75.0) * 100.0
```

**Where:**
- `averageHR` = Average heart rate from top 20% of workouts (by distance)
- If no provider data: Shows "Connexion needed"

**Example:**
- If average HR from workouts = 150 bpm
- `maxHR = (150 / 75.0) * 100.0 = 200 bpm`
- For first 25% of race: `targetHR = 200 * 0.75 = 150 bpm`
- For 25-50% of race: `targetHR = 200 * 0.775 = 155 bpm`
- For after 50%: `targetHR = 200 * 0.80 = 160 bpm`

**Code Location:** `RacePlanView.swift:2850-2866, 3089`

---

## 3. Est. Pace (Estimated Pace)

**Formula:**
```
adjustedPace = max(3.0, baseP * heatMultiplier * fatigueMultiplier + hillPenalty)
```

**Components:**

### Base Pace
- Calculated from **top 20% of workouts** (sorted by distance)
- For each workout: `paceSecondsPerKm = elapsedSeconds / (distanceM / 1000.0)`
- Convert to minutes: `paceMinutesPerKm = paceSecondsPerKm / 60.0`
- Average of all top 20% workouts
- If no provider data: Uses default `10.0 min/km` and shows "Connexion needed"

### Heat Multiplier
```
heatMultiplier = 1 + 0.01 * max(0, temperature - 15.0)
```
- No penalty below 15°C
- Adds 1% per degree above 15°C
- Example: At 25°C → `1 + 0.01 * (25 - 15) = 1.10` (10% slower)

### Fatigue Multiplier
```
fatigueMultiplier = 1 + analytics.fatigueRatePerHour * cumulativeHours
```
- `fatigueRatePerHour` = 0.03 (3% per hour) by default
- Increases with cumulative hours into the race
- Example: After 5 hours → `1 + 0.03 * 5 = 1.15` (15% slower)

### Hill Penalty
```
hillPenalty = 0.5 * (elevationGainM / 100.0)
```
- Adds 0.5 minutes per 100m of elevation gain
- Example: 500m gain → `0.5 * (500 / 100) = 2.5 minutes` added to pace

**Final Calculation:**
```
adjustedPace = max(3.0, basePace * heatMultiplier * fatigueMultiplier + hillPenalty)
```
- Minimum pace is 3.0 min/km (20 km/h max speed)

**Example:**
- Base pace = 8.0 min/km
- Temperature = 20°C → heatMultiplier = 1.05
- After 3 hours → fatigueMultiplier = 1.09
- 300m elevation gain → hillPenalty = 1.5
- `adjustedPace = max(3.0, 8.0 * 1.05 * 1.09 + 1.5) = max(3.0, 10.656) = 10.656 min/km`

**Code Location:** `RacePlanView.swift:2873-2882, 3059-3064`

---

## 4. Supporting Calculations

### Average Heart Rate (for Max HR calculation)
- Takes **top 20% of workouts** by distance
- Averages the `avgHR` values from those workouts
- Code: `RacePlanView.swift:3053-3056`

### Fatigue Rate
- Default: `0.03` (3% per hour)
- Can be calculated from longest workout's pace degradation
- Range: 0.015 to 0.08 (1.5% to 8% per hour)
- Code: `RacePlanView.swift:3082-3086`

### Base Pace Calculation
- Sorts workouts by distance (descending)
- Takes top 20% (`focusCount = max(1, Int(Double(sortedWorkouts.count) * 0.2))`)
- For each workout: `paceSecondsPerKm = elapsedSeconds / (distanceM / 1000.0)`
- Converts to minutes: `paceMinutesPerKm = paceSecondsPerKm / 60.0`
- Averages all values
- Code: `RacePlanView.swift:3049-3064`

---

## 5. Display Format

### Est. Time
- Formatted as hours and minutes (e.g., "4h 7m", "15h59m")
- Code: `formatDuration(hours:)` function

### BPM
- Rounded to nearest integer
- Format: `"\(Int(round(targetHR))) bpm"`
- If no data: `"Connexion needed"`

### Est. Pace
- Formatted as minutes:seconds per km (e.g., "9:53 /km", "19:11 /km")
- Code: `formatPace(minutesPerKm:)` function
- If no data: `"Connexion needed"`

---

## 6. Data Requirements

### For Accurate Calculations:
1. **Provider Connection** (Garmin, Coros, Suunto, or Polar)
   - Provides workout history
   - Enables base pace calculation
   - Enables max HR calculation

### Without Provider Data:
- Base pace: Default `10.0 min/km`
- Max HR: Shows "Connexion needed"
- Est. Pace: Shows "Connexion needed"
- Est. Time: Still calculated using default pace

---

## 7. Code References

- **Est. Time calculation:** `RacePlanView.swift:2878-2881`
- **BPM calculation:** `RacePlanView.swift:2850-2866`
- **Est. Pace calculation:** `RacePlanView.swift:2873-2882`
- **Base pace calculation:** `RacePlanView.swift:3059-3064`
- **Max HR calculation:** `RacePlanView.swift:3089`
- **Athlete analytics:** `RacePlanView.swift:3036-3099`

