# Segment Calculations: 0-50km and 50-119km

## Your Workout Data
- **Max HR:** 172 bpm (from Activity 1)
- **Average HR:** 146.5 bpm (average of 148 and 145)
- **Base Pace:** 5.62 min/km
- **Calories/Hour:** 600 kcal/h (from workouts)

## Assumptions
- **Temperature:** 20°C (moderate)
- **Total Elevation:** 6,035m (from your race data)
- **Elevation Distribution:**
  - 0-50km: ~2,636m (from screenshot)
  - 50-119km: ~3,399m (from screenshot)

---

## Segment 1: 0-50km (42% of race)

### BPM Calculation
**Race Fraction:** 50/119 = 0.42 (42%)
- Since 0.42 is between 25-50%, use **hrPercent = 0.775**

**Target HR:**
```
targetHR = maxHR × hrPercent
targetHR = 172 × 0.775
targetHR = 133.3 bpm
```

**Result: 133 bpm** (rounded)

---

### Time Calculation
**Base Pace:** 5.62 min/km
**Segment Distance:** 50 km
**Elevation Gain:** 2,636m
**Cumulative Hours:** ~0 hours (start)

**Pace Adjustments:**
```
Heat Multiplier: 1 + 0.01 × (20 - 15) = 1.05
Fatigue Multiplier: 1 + 0.03 × 0 = 1.0 (no fatigue at start)
Hill Penalty: 0.5 × (2636 / 50 / 100) = 0.264 min/km

Adjusted Pace = max(3.0, 5.62 × 1.05 × 1.0 + 0.264)
             = max(3.0, 5.901 + 0.264)
             = max(3.0, 6.165)
             = 6.165 min/km
```

**Time:**
```
Time = 6.165 × 50 = 308.25 minutes = 5h 8m
```

**Result: 5h 8m**

---

### Carbs Calculation
**Total Race Time:** ~14.5 hours (estimated)
**Glycogen:** 600 kcal total
**Glycogen per hour:** 600 / 14.5 = 41.4 kcal/h
**Fat:** 5 kcal/h
**Calories needed:** 600 kcal/h (from workouts)

**Carbs per hour:**
```
carbKcalPerHour = caloriesPerHour - fatKcalPerHour - glycogenPerHour
carbKcalPerHour = 600 - 5 - 41.4
carbKcalPerHour = 553.6 kcal/h

carbGramsPerHour = 553.6 / 4 = 138.4 g/h
```

**Carbs for 0-50km (5h 8m = 5.133 hours):**
```
carbs = 138.4 × 5.133 = 710.4 g
```

**Result: 710g carbs**

---

### Sodium Calculation
**Temperature:** 20°C
**Sodium per hour:** 600 mg/h (moderate temperature: 15-22°C)

**Sodium for 0-50km (5.133 hours):**
```
sodium = 600 × 5.133 = 3,080 mg
```

**Result: 3,080mg sodium**

---

### Water Calculation
**Temperature:** 20°C
**Water per hour:** 650 ml/h (moderate temperature: 15-22°C)

**Water for 0-50km (5.133 hours):**
```
water = 650 × 5.133 = 3,336 ml
```

**Result: 3,336ml water**

---

## Segment 2: 50-119km (58% of race)

### BPM Calculation
**Race Fraction:** 119/119 = 1.0 (100%)
- Since it's after 50%, use **hrPercent = 0.80**

**Target HR:**
```
targetHR = maxHR × hrPercent
targetHR = 172 × 0.80
targetHR = 137.6 bpm
```

**Result: 138 bpm** (rounded)

---

### Time Calculation
**Base Pace:** 5.62 min/km
**Segment Distance:** 69 km (119 - 50)
**Elevation Gain:** 3,399m
**Cumulative Hours:** ~5.133 hours (from first segment)

**Pace Adjustments:**
```
Heat Multiplier: 1 + 0.01 × (20 - 15) = 1.05
Fatigue Multiplier: 1 + 0.03 × 5.133 = 1.154
Hill Penalty: 0.5 × (3399 / 69 / 100) = 0.246 min/km

Adjusted Pace = max(3.0, 5.62 × 1.05 × 1.154 + 0.246)
             = max(3.0, 6.808 + 0.246)
             = max(3.0, 7.054)
             = 7.054 min/km
```

**Time:**
```
Time = 7.054 × 69 = 486.7 minutes = 8h 7m
```

**Result: 8h 7m**

---

### Carbs Calculation
**Carbs per hour:** 138.4 g/h (same as segment 1)

**Carbs for 50-119km (8h 7m = 8.117 hours):**
```
carbs = 138.4 × 8.117 = 1,123.4 g
```

**Result: 1,123g carbs**

---

### Sodium Calculation
**Sodium per hour:** 600 mg/h (same temperature)

**Sodium for 50-119km (8.117 hours):**
```
sodium = 600 × 8.117 = 4,870 mg
```

**Result: 4,870mg sodium**

---

### Water Calculation
**Water per hour:** 650 ml/h (same temperature)

**Water for 50-119km (8.117 hours):**
```
water = 650 × 8.117 = 5,276 ml
```

**Result: 5,276ml water**

---

## Summary Table

| Segment | Distance | BPM | Est. Time | Carbs | Sodium | Water |
|---------|----------|-----|-----------|-------|--------|-------|
| **0-50km** | 50km | **133 bpm** | **5h 8m** | **710g** | **3,080mg** | **3,336ml** |
| **50-119km** | 69km | **138 bpm** | **8h 7m** | **1,123g** | **4,870mg** | **5,276ml** |
| **Total** | 119km | - | **13h 15m** | **1,833g** | **7,950mg** | **8,612ml** |

---

## Notes

1. **BPM increases** from 133 → 138 bpm as you progress (more effort needed to maintain pace)
2. **Pace slows** from 6:10/km → 7:03/km due to fatigue and elevation
3. **Carbs needed** increases in second half (longer time + higher intensity)
4. **Sodium/Water** scale with time and temperature
5. **Total time:** 13h 15m (slightly less than 14.5h estimate due to more accurate segment calculations)

---

## Per Hour Breakdown

### Segment 1 (0-50km):
- **Carbs:** 138 g/h
- **Sodium:** 600 mg/h
- **Water:** 650 ml/h

### Segment 2 (50-119km):
- **Carbs:** 138 g/h (same)
- **Sodium:** 600 mg/h (same)
- **Water:** 650 ml/h (same)

*Note: Per-hour rates are constant, but total amounts increase because the second segment takes longer.*

