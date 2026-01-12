# Calculations for User: 84b13928-a931-4841-9289-bf2ab30cb07d

## Calculation Functions in the App

### 1. **Segment Metrics Calculation** (`computeSegmentMetrics`)
**Location:** `ios/Auth/SupabaseService.swift:663`

```swift
private static func computeSegmentMetrics(
    trackPoints: [TrackPoint], 
    startIndex: Int, 
    endIndex: Int, 
    paceSecondsPerKm: Double
) -> AidStationSegmentMetrics
```

**Calculations:**
- **Segment Distance**: `round(max(0, endPoint.distFromStart - startPoint.distFromStart) * 100.0) / 100.0` (rounded to 2 decimals, 1cm precision)
- **Elevation Gain**: Sum of all positive elevation changes between points (rounded to 1 decimal)
- **Elevation Loss**: Sum of all negative elevation changes (absolute value, rounded to 1 decimal)
- **Estimated Time**: `round(distanceKm * paceSecondsPerKm)` (rounded to nearest second)
- **Average Heart Rate**: `round(hrTotal / hrCount)` (rounded to nearest integer)

### 2. **Pace Calculation** (from activities)
**Location:** `ios/Auth/SupabaseService.swift:1890`

```swift
// Calculate pace from speed if available (pace = 1000 / speed_mps)
let pace: Int?
if let speed = speedMps, speed > 0 {
    pace = Int(1000.0 / speed)
} else {
    pace = dict["pace_s_per_km"] as? Int
}
```

**Formula:** `pace (sec/km) = 1000 / speed (m/s)`

### 3. **Fitness Age Calculation** (`computeFitnessAge`)
**Location:** `ios/Auth/SupabaseService.swift:1954`

```swift
private static func computeFitnessAge(vo2Max: Decimal?, chronologicalAge: Int?) -> Decimal? {
    guard let vo2Max = vo2Max else { return nil }
    let vo2 = NSDecimalNumber(decimal: vo2Max).doubleValue
    guard vo2 > 0 else { return nil }
    let age = Double(chronologicalAge ?? 40)
    // Simple heuristic: estimate fitness age by adjusting chronological age based on VO2 Max.
    // Higher VO2 Max reduces fitness age, lower VO2 Max increases it.
    let adjustment = (vo2 - 40.0) * -0.8 // each VO2 point above 40 reduces ~0.8 years
    let estimatedAge = max(18.0, age + adjustment)
    return Decimal(estimatedAge)
}
```

**Formula:** `Fitness Age = max(18, Chronological Age + ((VO2 Max - 40) * -0.8))`

### 4. **Cumulative Elevation Gain**
**Location:** `ios/Features/RacePlan/RacePlanView.swift:2113`

```swift
// Calculate cumulative elevation gain from all track points
var cumulativeElevationGain: Double = 0
if trackPointsFromDB.count > 1 {
    for i in 1..<trackPointsFromDB.count {
        let delta = trackPointsFromDB[i].ele - trackPointsFromDB[i - 1].ele
        if delta > 0 {
            cumulativeElevationGain += delta
        }
    }
}
```

**Formula:** Sum of all positive elevation changes between consecutive track points

### 5. **Haversine Distance Calculation**
**Location:** `ios/Auth/SupabaseService.swift:785`

```swift
private static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let earthRadius = 6_371_000.0 // meters
    let dLat = (lat2 - lat1) * Double.pi / 180.0
    let dLon = (lon2 - lon1) * Double.pi / 180.0
    
    let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * Double.pi / 180.0) *
            cos(lat2 * Double.pi / 180.0) *
            sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    let distance = earthRadius * c
    return round(distance * 100.0) / 100.0 // Round to 2 decimal places (1cm precision)
}
```

**Formula:** Standard Haversine formula for calculating distance between two GPS coordinates

### 6. **Age Calculation**
**Location:** `ios/Auth/SupabaseService.swift:1949`

```swift
private static func calculateAgeYears(from birthDate: Date, referenceDate: Date = Date()) -> Int {
    let components = Calendar.current.dateComponents([.year], from: birthDate, to: referenceDate)
    return components.year ?? 0
}
```

## To View Actual Data for This User

Run these queries in Supabase SQL Editor or via API:

```sql
-- User Profile
SELECT * FROM profiles WHERE id = '84b13928-a931-4841-9289-bf2ab30cb07d';

-- Race Plans
SELECT * FROM race_plans WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d';

-- Race Plan Segments (with calculated metrics)
SELECT 
    rps.*,
    rps.segment_distance_m / 1000.0 as segment_distance_km,
    rps.estimated_time_seconds / 60.0 as estimated_time_minutes,
    rps.elevation_gain_m,
    rps.elevation_loss_m
FROM race_plan_segments rps
JOIN race_plans rp ON rps.race_plan_id = rp.id
WHERE rp.user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
ORDER BY rps.race_plan_id, rps.index;

-- Activities with calculated pace
SELECT 
    activity_name,
    distance_meters,
    elapsed_time,
    distance_meters / 1000.0 as distance_km,
    elapsed_time / 60.0 as elapsed_minutes,
    CASE 
        WHEN distance_meters > 0 AND elapsed_time > 0 
        THEN (elapsed_time / 60.0) / (distance_meters / 1000.0)
        ELSE NULL 
    END as pace_min_per_km,
    CASE 
        WHEN distance_meters > 0 AND elapsed_time > 0 
        THEN FLOOR((elapsed_time / 60.0) / (distance_meters / 1000.0))
        ELSE NULL 
    END as pace_minutes,
    CASE 
        WHEN distance_meters > 0 AND elapsed_time > 0 
        THEN ROUND((((elapsed_time / 60.0) / (distance_meters / 1000.0)) % 1) * 60)
        ELSE NULL 
    END as pace_seconds,
    average_heart_rate,
    start_date
FROM unified_activities
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
ORDER BY start_date DESC
LIMIT 10;

-- Health Metrics with Fitness Age calculation
SELECT 
    date,
    vo2_max,
    age_years,
    fitness_age,
    CASE 
        WHEN vo2_max IS NOT NULL AND age_years IS NOT NULL 
        THEN GREATEST(18.0, age_years + ((vo2_max - 40.0) * -0.8))
        ELSE NULL 
    END as calculated_fitness_age,
    resting_heart_rate,
    weight_kg
FROM health_metrics
WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
ORDER BY date DESC
LIMIT 5;

-- Track Points for elevation calculation
SELECT 
    race_plan_id,
    COUNT(*) as total_points,
    MIN(ele) as min_elevation,
    MAX(ele) as max_elevation,
    MAX(dist_from_start) / 1000.0 as total_distance_km
FROM race_plan_track_points
WHERE race_plan_id IN (
    SELECT id FROM race_plans WHERE user_id = '84b13928-a931-4841-9289-bf2ab30cb07d'
)
GROUP BY race_plan_id;
```

