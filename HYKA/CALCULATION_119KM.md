# 119km Race Calculation Based on Your Workout Data

## Base Values (from your workouts)

- **Base Pace:** 5.62 min/km
- **Max HR:** 195 bpm
- **Average HR:** 146.5 bpm

---

## Race Breakdown: 119km

### Assumptions:
- **Temperature:** 20°C (moderate)
- **Total Elevation Gain:** 3,000m (typical for ultra-marathon)
- **Average Elevation Gain per km:** 3,000m / 119km = 25.2m per km

---

## Calculation by Race Segments

### Segment 1: 0-30km (First 25% of race)

**Distance:** 30km  
**Cumulative Hours:** ~2.5 hours  
**Elevation Gain:** 30 × 25.2 = 756m  
**Race Fraction:** 0.25 (25%)

**BPM:**
```
targetHR = 195 × 0.75 = 146.25 bpm
Result: 146 bpm
```

**Est. Pace:**
```
Base Pace: 5.62 min/km
Heat Multiplier: 1 + 0.01 × (20 - 15) = 1.05
Fatigue Multiplier: 1 + 0.03 × 2.5 = 1.075
Hill Penalty: 0.5 × (756 / 100) = 3.78 min/km (for total segment)
Hill Penalty per km: 3.78 / 30 = 0.126 min/km

Adjusted Pace = max(3.0, 5.62 × 1.05 × 1.075 + 0.126)
              = max(3.0, 5.62 × 1.129 + 0.126)
              = max(3.0, 6.470)
              = 6.47 min/km
```

**Est. Time:**
```
Time = 6.47 × 30 = 194.1 minutes = 3h 14m
```

**Summary:**
- **BPM:** 146 bpm
- **Est. Pace:** 6:28 /km
- **Est. Time:** 3h 14m

---

### Segment 2: 30-60km (25-50% of race)

**Distance:** 30km  
**Cumulative Hours:** ~5.5 hours (3h 14m + 2h 20m)  
**Elevation Gain:** 30 × 25.2 = 756m  
**Race Fraction:** 0.50 (50%)

**BPM:**
```
targetHR = 195 × 0.775 = 151.125 bpm
Result: 151 bpm
```

**Est. Pace:**
```
Base Pace: 5.62 min/km
Heat Multiplier: 1.05
Fatigue Multiplier: 1 + 0.03 × 5.5 = 1.165
Hill Penalty per km: 0.126 min/km

Adjusted Pace = max(3.0, 5.62 × 1.05 × 1.165 + 0.126)
              = max(3.0, 5.62 × 1.223 + 0.126)
              = max(3.0, 6.999)
              = 7.00 min/km
```

**Est. Time:**
```
Time = 7.00 × 30 = 210 minutes = 3h 30m
```

**Summary:**
- **BPM:** 151 bpm
- **Est. Pace:** 7:00 /km
- **Est. Time:** 3h 30m

---

### Segment 3: 60-90km (50-75% of race)

**Distance:** 30km  
**Cumulative Hours:** ~9 hours (3h 14m + 3h 30m + 2h 20m)  
**Elevation Gain:** 30 × 25.2 = 756m  
**Race Fraction:** 0.75 (75%)

**BPM:**
```
targetHR = 195 × 0.80 = 156 bpm
Result: 156 bpm
```

**Est. Pace:**
```
Base Pace: 5.62 min/km
Heat Multiplier: 1.05
Fatigue Multiplier: 1 + 0.03 × 9 = 1.27
Hill Penalty per km: 0.126 min/km

Adjusted Pace = max(3.0, 5.62 × 1.05 × 1.27 + 0.126)
              = max(3.0, 5.62 × 1.334 + 0.126)
              = max(3.0, 7.621)
              = 7.62 min/km
```

**Est. Time:**
```
Time = 7.62 × 30 = 228.6 minutes = 3h 49m
```

**Summary:**
- **BPM:** 156 bpm
- **Est. Pace:** 7:37 /km
- **Est. Time:** 3h 49m

---

### Segment 4: 90-119km (75-100% of race)

**Distance:** 29km  
**Cumulative Hours:** ~12.8 hours (3h 14m + 3h 30m + 3h 49m + 2h 27m)  
**Elevation Gain:** 29 × 25.2 = 731m  
**Race Fraction:** 1.0 (100%)

**BPM:**
```
targetHR = 195 × 0.80 = 156 bpm
Result: 156 bpm
```

**Est. Pace:**
```
Base Pace: 5.62 min/km
Heat Multiplier: 1.05
Fatigue Multiplier: 1 + 0.03 × 12.8 = 1.384
Hill Penalty per km: 0.5 × (731 / 100) / 29 = 0.126 min/km

Adjusted Pace = max(3.0, 5.62 × 1.05 × 1.384 + 0.126)
              = max(3.0, 5.62 × 1.453 + 0.126)
              = max(3.0, 8.291)
              = 8.29 min/km
```

**Est. Time:**
```
Time = 8.29 × 29 = 240.4 minutes = 4h 0m
```

**Summary:**
- **BPM:** 156 bpm
- **Est. Pace:** 8:17 /km
- **Est. Time:** 4h 0m

---

## Total Race Summary

| Segment | Distance | BPM | Est. Pace | Est. Time | Cumulative Time |
|---------|----------|-----|-----------|-----------|-----------------|
| 0-30km | 30km | 146 bpm | 6:28 /km | 3h 14m | 3h 14m |
| 30-60km | 30km | 151 bpm | 7:00 /km | 3h 30m | 6h 44m |
| 60-90km | 30km | 156 bpm | 7:37 /km | 3h 49m | 10h 33m |
| 90-119km | 29km | 156 bpm | 8:17 /km | 4h 0m | **14h 33m** |

---

## Overall Race Statistics

### Total Time: **14 hours 33 minutes**

### Average Pace: **7:20 /km**
```
Total Time: 14h 33m = 873 minutes
Average Pace: 873 / 119 = 7.34 min/km = 7:20 /km
```

### Pace Progression:
- **Start (0km):** 6:28 /km
- **Mid (60km):** 7:00 /km
- **Late (90km):** 7:37 /km
- **Finish (119km):** 8:17 /km

### Heart Rate Progression:
- **0-30km:** 146 bpm (75% max)
- **30-60km:** 151 bpm (77.5% max)
- **60-119km:** 156 bpm (80% max)

---

## Alternative Scenarios

### Scenario 1: Cooler Weather (15°C), Less Elevation (2,000m)

**Average Elevation:** 2,000m / 119km = 16.8m per km

**Segment 1 (0-30km):**
- Heat: 1.0 (no penalty)
- Fatigue: 1.075
- Hill: 0.084 min/km
- **Pace:** 6.13 min/km
- **Time:** 3h 4m

**Segment 4 (90-119km):**
- Heat: 1.0
- Fatigue: 1.384
- Hill: 0.084 min/km
- **Pace:** 7.87 min/km
- **Time:** 3h 48m

**Total Time:** ~13h 30m (1 hour faster!)

---

### Scenario 2: Hot Weather (25°C), More Elevation (4,000m)

**Average Elevation:** 4,000m / 119km = 33.6m per km

**Segment 1 (0-30km):**
- Heat: 1.10 (10% slower)
- Fatigue: 1.075
- Hill: 0.168 min/km
- **Pace:** 6.80 min/km
- **Time:** 3h 24m

**Segment 4 (90-119km):**
- Heat: 1.10
- Fatigue: 1.384
- Hill: 0.168 min/km
- **Pace:** 8.88 min/km
- **Time:** 4h 18m

**Total Time:** ~15h 30m (1 hour slower)

---

## Key Insights

1. **Pace Degradation:** Your pace slows from 6:28/km to 8:17/km over 119km due to:
   - Fatigue accumulation (3% per hour)
   - Cumulative elevation gain
   - Heat effects

2. **Heart Rate Increase:** HR target increases from 146 bpm to 156 bpm as you progress, requiring more effort to maintain pace

3. **Time Distribution:**
   - First 30km: 3h 14m (fastest)
   - Last 29km: 4h 0m (slowest)
   - 30% time increase in final segment

4. **Fatigue Impact:** After 12.8 hours, fatigue multiplier is 1.384 (38.4% slower than base pace)

---

## Recommendations

1. **Start Conservative:** Your base pace is 5.62 min/km, but start at 6:28/km to preserve energy
2. **Monitor HR:** Keep HR at 146 bpm for first 30km, then gradually increase
3. **Fuel Strategy:** Plan for 14+ hours of racing - need consistent fueling
4. **Pace Management:** Expect 2 min/km slowdown from start to finish
5. **Mental Preparation:** Final 29km will take 4 hours - prepare for the long haul!

---

## Comparison to Your Workouts

**Your Best Workout:**
- 24.2km in 2.36 hours = 5.86 min/km average

**119km Race Projection:**
- Average: 7.34 min/km
- **25% slower** than your best workout pace (expected for ultra-distance)

This is realistic for an ultra-marathon where you need to pace yourself for 14+ hours!

