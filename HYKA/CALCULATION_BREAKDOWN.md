# Race Strategy Calculation Breakdown

This document explains how the values shown in the race strategy cards are calculated.

## 1. "19.9 hours" - Total Estimated Duration (Race Details Card)

**Location:** `formattedEstimatedDuration()` (line 2117)

**Calculation:**
```swift
let distanceKm = aidStations.last?.distance ?? 0  // e.g., 119 km
let paceMinutesPerKm = 10.0  // Fixed at 10 minutes per km
let totalMinutes = distanceKm * paceMinutesPerKm  // 119 * 10 = 1190 minutes
let hours = totalMinutes / 60.0  // 1190 / 60 = 19.833... hours
return String(format: "%.1f hours", hours)  // "19.8 hours" (rounded to 1 decimal)
```

**Example:**
- Distance: 119 km
- Pace: 10.0 min/km (fixed value)
- Total minutes: 119 × 10 = 1,190 minutes
- Hours: 1,190 ÷ 60 = **19.8 hours** (displayed as "19.8 hours")

**Note:** This is a simplified calculation that doesn't account for elevation, fatigue, or temperature. It's used only for the race details card summary.

---

## 2. "15h 59m" - Segment Duration (Pacing Card)

**Location:** `buildSectionPlans()` → `formatDuration()` (lines 2764-2952)

**Step-by-Step Calculation:**

### Step 1: Determine Race Fraction
```swift
let raceFraction = totalDistanceKm > 0 ? toStation.distance / totalDistanceKm : 0
// For 0K-50K segment in a 119K race: 50 / 119 = 0.420 (42%)
```

### Step 2: Calculate Heart Rate Percentage
```swift
let hrPercent: Double
if raceFraction <= 0.25 {      // First 25% of race
    hrPercent = 0.75           // 75% of max HR
} else if raceFraction <= 0.5 { // 25-50% of race
    hrPercent = 0.775          // 77.5% of max HR
} else {                        // After 50% of race
    hrPercent = 0.80           // 80% of max HR
}
// For 0K-50K (42%): hrPercent = 0.775
```

### Step 3: Get Base Pace
```swift
let basePace = analytics.basePaceMinutesPerKilometer ?? 6.0
// Base pace calculated from top 20% of longest workouts
// Example: 6.0 min/km (from athlete's historical data)
```

### Step 4: Apply Adjustments
```swift
let heatMultiplier = 1 + 0.01 * max(0, temperature - 15.0)
// Example: temperature = 20°C
// heatMultiplier = 1 + 0.01 * (20 - 15) = 1 + 0.05 = 1.05

let fatigueMultiplier = 1 + analytics.fatigueRatePerHour * cumulativeHours
// Example: fatigueRatePerHour = 0.03, cumulativeHours = 0 (start of race)
// fatigueMultiplier = 1 + 0.03 * 0 = 1.0

let hillPenalty = 0.5 * (metric.elevationGainM / 100.0)
// Example: elevationGainM = 2636m
// hillPenalty = 0.5 * (2636 / 100) = 0.5 * 26.36 = 13.18 min/km
```

### Step 5: Calculate Adjusted Pace
```swift
let adjustedPace = max(3.0, basePace * heatMultiplier * fatigueMultiplier + hillPenalty)
// adjustedPace = max(3.0, 6.0 * 1.05 * 1.0 + 13.18)
// adjustedPace = max(3.0, 6.3 + 13.18)
// adjustedPace = max(3.0, 19.48)
// adjustedPace = 19.48 min/km
```

### Step 6: Calculate Segment Duration
```swift
let segmentDistance = max(0.1, toStation.distance - fromStation.distance)
// segmentDistance = 50.0 km (0K to 50K)

let sectionMinutes = adjustedPace * segmentDistance
// sectionMinutes = 19.48 * 50 = 974 minutes

let sectionHours = sectionMinutes / 60.0
// sectionHours = 974 / 60 = 16.233 hours
```

### Step 7: Format Duration
```swift
private func formatDuration(hours: Double) -> String {
    let totalMinutes = Int(round(hours * 60))  // 16.233 * 60 = 974 minutes
    let h = totalMinutes / 60                   // 974 / 60 = 16 hours
    let m = totalMinutes % 60                   // 974 % 60 = 14 minutes
    return "\(h)h \(m)m"                        // "16h 14m"
}
```

**Example Calculation:**
- Segment: 0K-50K (50.0 km)
- Base pace: 6.0 min/km
- Heat multiplier: 1.05 (20°C)
- Fatigue multiplier: 1.0 (start of race)
- Hill penalty: 13.18 min/km (2,636m elevation gain)
- Adjusted pace: 19.48 min/km
- Duration: 19.48 × 50 = 974 minutes = **16h 14m**

**Note:** The displayed "15h 59m" suggests slightly different input values (possibly lower elevation gain or different base pace).

---

## 3. "145 bpm" - Target Heart Rate (Pacing Card)

**Location:** `buildSectionPlans()` (lines 2796-2806)

**Calculation:**
```swift
// Step 1: Determine race fraction
let raceFraction = totalDistanceKm > 0 ? toStation.distance / totalDistanceKm : 0
// For 0K-50K in 119K race: 50 / 119 = 0.420 (42%)

// Step 2: Get heart rate percentage based on race fraction
let hrPercent: Double
if raceFraction <= 0.25 {      // First 25% of race
    hrPercent = 0.75           // 75% of max HR
} else if raceFraction <= 0.5 { // 25-50% of race
    hrPercent = 0.775          // 77.5% of max HR
} else {                        // After 50% of race
    hrPercent = 0.80           // 80% of max HR
}
// For 42%: hrPercent = 0.775

// Step 3: Calculate max heart rate
let maxHeartRate = analytics.maxHeartRate ?? ((analytics.averageHeartRate ?? 140.0) / 75.0 * 100.0)
// If maxHR not available: maxHR = (avgHR / 75) * 100
// Example: avgHR = 140 → maxHR = (140 / 75) * 100 = 186.67 bpm

// Step 4: Calculate target heart rate
let targetHR = maxHeartRate * hrPercent
// targetHR = 186.67 * 0.775 = 144.67 bpm

// Step 5: Round and format
let heartRateString = "\(Int(round(targetHR))) bpm"
// heartRateString = "145 bpm"
```

**Example:**
- Race fraction: 42% (0K-50K in 119K race)
- HR percentage: 77.5% (since 25% < 42% ≤ 50%)
- Max HR: 186.67 bpm (calculated from avg HR of 140 bpm)
- Target HR: 186.67 × 0.775 = **144.67 bpm** → rounded to **145 bpm**

**Heart Rate Zones by Race Fraction:**
- **0-25% of race:** 75% of max HR (steady build)
- **25-50% of race:** 77.5% of max HR (focused effort)
- **50%+ of race:** 80% of max HR (sustained effort)

---

## 4. "Est. Pace 19:11 / km" - Estimated Pace (Pacing Card)

**Location:** `buildSectionPlans()` → `formatPace()` (lines 2808-2959)

**Calculation:**

### Step 1: Base Pace
```swift
let basePace = analytics.basePaceMinutesPerKilometer ?? 6.0
// Calculated from athlete's top 20% longest workouts
// Example: 6.0 min/km
```

### Step 2: Heat Multiplier
```swift
let heatMultiplier = 1 + 0.01 * max(0, temperature - 15.0)
// Example: temperature = 20°C
// heatMultiplier = 1 + 0.01 * (20 - 15) = 1.05
// This adds 5% to pace for every degree above 15°C
```

### Step 3: Fatigue Multiplier
```swift
let fatigueMultiplier = 1 + analytics.fatigueRatePerHour * cumulativeHours
// Example: fatigueRatePerHour = 0.03, cumulativeHours = 0 (start of segment)
// fatigueMultiplier = 1 + 0.03 * 0 = 1.0
// This increases pace by 3% per hour of cumulative race time
```

### Step 4: Hill Penalty
```swift
let hillPenalty = 0.5 * (metric.elevationGainM / 100.0)
// Example: elevationGainM = 2636m
// hillPenalty = 0.5 * (2636 / 100) = 0.5 * 26.36 = 13.18 min/km
// This adds 0.5 min/km for every 100m of elevation gain
```

### Step 5: Adjusted Pace
```swift
let adjustedPace = max(3.0, basePace * heatMultiplier * fatigueMultiplier + hillPenalty)
// adjustedPace = max(3.0, 6.0 * 1.05 * 1.0 + 13.18)
// adjustedPace = max(3.0, 6.3 + 13.18)
// adjustedPace = max(3.0, 19.48)
// adjustedPace = 19.48 min/km
```

### Step 6: Format Pace
```swift
private func formatPace(minutesPerKm: Double) -> String {
    let totalSeconds = Int(round(minutesPerKm * 60))  // 19.48 * 60 = 1168.8 → 1169 seconds
    let minutes = totalSeconds / 60                   // 1169 / 60 = 19 minutes
    let seconds = totalSeconds % 60                   // 1169 % 60 = 29 seconds
    return String(format: "%d:%02d /km", minutes, seconds)  // "19:29 /km"
}
```

**Example Calculation:**
- Base pace: 6.0 min/km
- Heat multiplier: 1.05 (20°C)
- Fatigue multiplier: 1.0 (start of race)
- Hill penalty: 13.18 min/km (2,636m elevation gain)
- Adjusted pace: 6.0 × 1.05 × 1.0 + 13.18 = **19.48 min/km**
- Formatted: 19.48 × 60 = 1,168.8 seconds = **19:29 /km**

**Note:** The displayed "19:11 /km" suggests slightly different input values (possibly lower elevation gain of ~2,222m instead of 2,636m, or different base pace).

---

## Summary of Key Formulas

### Total Estimated Duration (Race Details Card)
```
Hours = (Distance in km × 10.0 minutes/km) ÷ 60
```

### Segment Duration (Pacing Card)
```
Adjusted Pace = max(3.0, BasePace × HeatMultiplier × FatigueMultiplier + HillPenalty)
Segment Hours = (Adjusted Pace × Segment Distance) ÷ 60
```

### Target Heart Rate (Pacing Card)
```
HR Percentage = 75% (0-25% race) | 77.5% (25-50% race) | 80% (50%+ race)
Target HR = Max HR × HR Percentage
```

### Estimated Pace (Pacing Card)
```
Heat Multiplier = 1 + 0.01 × max(0, Temperature - 15°C)
Fatigue Multiplier = 1 + FatigueRatePerHour × CumulativeHours
Hill Penalty = 0.5 × (ElevationGainM ÷ 100)
Adjusted Pace = max(3.0, BasePace × HeatMultiplier × FatigueMultiplier + HillPenalty)
```

---

## Key Variables

- **Base Pace:** Calculated from athlete's top 20% longest workouts (default: 6.0 min/km)
- **Max Heart Rate:** From analytics or calculated as (Average HR ÷ 75) × 100
- **Fatigue Rate:** 0.03 (3% per hour) by default, calculated from longest workout
- **Heat Adjustment:** +1% pace per degree above 15°C
- **Hill Penalty:** +0.5 min/km per 100m elevation gain
- **Minimum Pace:** 3.0 min/km (cap to prevent unrealistic fast paces)

