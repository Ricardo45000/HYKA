# Calculation Example Based on Your Workout Data

## Input Data

**Workout 1:**
- Distance: 24,187.33 m (24.187 km)
- Duration: 8,509 seconds (141.82 minutes, 2.36 hours)
- Average HR: 148 bpm
- Max HR: 172 bpm
- Elevation gain: 380.93 m

**Workout 2:**
- Distance: 16,112.91 m (16.113 km)
- Duration: 5,204 seconds (86.73 minutes, 1.45 hours)
- Average HR: 145 bpm
- Max HR: 165 bpm
- Elevation gain: 57.39 m

---

## Step 1: Calculate Base Pace

### Top 20% of Workouts (by distance)
- Total workouts: 2
- Top 20%: `max(1, Int(2 * 0.2)) = 1` workout
- But we'll use both since there are only 2

**Workout 1 Pace:**
```
paceSecondsPerKm = 8509 / 24.187 = 351.5 seconds/km
paceMinutesPerKm = 351.5 / 60 = 5.86 min/km
```

**Workout 2 Pace:**
```
paceSecondsPerKm = 5204 / 16.113 = 322.8 seconds/km
paceMinutesPerKm = 322.8 / 60 = 5.38 min/km
```

**Average Base Pace:**
```
basePace = (5.86 + 5.38) / 2 = 5.62 min/km
```

**Result: Base Pace = 5.62 min/km**

---

## Step 2: Calculate Max Heart Rate

### Average HR from Workouts
```
averageHR = (148 + 145) / 2 = 146.5 bpm
```

### Max HR Calculation
```
maxHR = (averageHR / 75.0) × 100.0
maxHR = (146.5 / 75.0) × 100.0
maxHR = 1.953 × 100.0
maxHR = 195.33 bpm
```

**Result: Max HR = 195 bpm (rounded)**

---

## Step 3: Calculate BPM (Target Heart Rate)

### HR Percentage by Race Fraction

**First 25% of race:**
```
targetHR = 195.33 × 0.75 = 146.5 bpm
```
**Result: 147 bpm (rounded)**

**25-50% of race:**
```
targetHR = 195.33 × 0.775 = 151.4 bpm
```
**Result: 151 bpm (rounded)**

**After 50% of race:**
```
targetHR = 195.33 × 0.80 = 156.3 bpm
```
**Result: 156 bpm (rounded)**

---

## Step 4: Calculate Est. Pace (Adjusted Pace)

### Example Scenario: 5km Segment

**Assumptions:**
- Segment distance: 5 km
- Temperature: 20°C
- Cumulative hours: 2 hours (mid-race)
- Elevation gain: 200m

### Components:

**1. Base Pace:**
```
basePace = 5.62 min/km
```

**2. Heat Multiplier:**
```
heatMultiplier = 1 + 0.01 × max(0, 20 - 15)
heatMultiplier = 1 + 0.01 × 5
heatMultiplier = 1.05 (5% slower)
```

**3. Fatigue Multiplier:**
```
fatigueMultiplier = 1 + 0.03 × 2
fatigueMultiplier = 1 + 0.06
fatigueMultiplier = 1.06 (6% slower)
```

**4. Hill Penalty:**
```
hillPenalty = 0.5 × (200 / 100.0)
hillPenalty = 0.5 × 2.0
hillPenalty = 1.0 min/km
```

### Final Adjusted Pace:
```
adjustedPace = max(3.0, basePace × heatMultiplier × fatigueMultiplier + hillPenalty)
adjustedPace = max(3.0, 5.62 × 1.05 × 1.06 + 1.0)
adjustedPace = max(3.0, 5.62 × 1.113 + 1.0)
adjustedPace = max(3.0, 6.255 + 1.0)
adjustedPace = max(3.0, 7.255)
adjustedPace = 7.255 min/km
```

**Formatted: 7:15 /km** (7 minutes 15 seconds per kilometer)

---

## Step 5: Calculate Est. Time

### For the 5km Segment:
```
sectionMinutes = adjustedPace × segmentDistance
sectionMinutes = 7.255 × 5
sectionMinutes = 36.275 minutes
sectionHours = 36.275 / 60 = 0.604 hours
```

**Formatted: 36m** (36 minutes)

---

## Summary of Results

### Base Calculations:
- **Base Pace:** 5.62 min/km (from workout average)
- **Max HR:** 195 bpm (calculated from average HR)

### For a 5km Segment (20°C, 2 hours into race, 200m gain):

| Metric | Value | Calculation |
|--------|-------|-------------|
| **Est. Pace** | **7:15 /km** | 5.62 × 1.05 × 1.06 + 1.0 = 7.255 min/km |
| **Est. Time** | **36m** | 7.255 × 5 = 36.275 minutes |
| **BPM (0-25%)** | **147 bpm** | 195 × 0.75 = 146.5 bpm |
| **BPM (25-50%)** | **151 bpm** | 195 × 0.775 = 151.4 bpm |
| **BPM (50%+)** | **156 bpm** | 195 × 0.80 = 156.3 bpm |

---

## Different Scenarios

### Scenario 1: Flat Segment, Cool Weather (15°C), Early Race (0 hours)
- Heat multiplier: 1.0 (no penalty)
- Fatigue multiplier: 1.0 (no penalty)
- Hill penalty: 0 (flat)
- **Adjusted Pace:** 5.62 min/km
- **Est. Time for 5km:** 28.1 minutes

### Scenario 2: Hilly Segment (500m gain), Hot Weather (30°C), Late Race (5 hours)
- Heat multiplier: 1.15 (15% slower)
- Fatigue multiplier: 1.15 (15% slower)
- Hill penalty: 2.5 min/km
- **Adjusted Pace:** max(3.0, 5.62 × 1.15 × 1.15 + 2.5) = 9.93 min/km
- **Est. Time for 5km:** 49.65 minutes

### Scenario 3: Moderate Conditions (20°C, 3 hours, 300m gain)
- Heat multiplier: 1.05
- Fatigue multiplier: 1.09
- Hill penalty: 1.5 min/km
- **Adjusted Pace:** max(3.0, 5.62 × 1.05 × 1.09 + 1.5) = 7.93 min/km
- **Est. Time for 5km:** 39.65 minutes

---

## Notes

1. **Base Pace** is calculated from your actual workout performance (5.38-5.86 min/km range)
2. **Max HR** is estimated from your average HR (146.5 bpm → 195 bpm max)
3. **BPM targets** increase as you progress through the race (75% → 77.5% → 80% of max)
4. **Est. Pace** adjusts for:
   - Heat (1% per degree above 15°C)
   - Fatigue (3% per hour)
   - Elevation (0.5 min per 100m gain)
5. **Est. Time** is simply adjusted pace × distance

These calculations use your actual Garmin workout data, so they're personalized to your performance!

