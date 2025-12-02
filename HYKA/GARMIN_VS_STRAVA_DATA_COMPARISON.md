# Garmin vs Strava: Data Comparison for HYKA

## Summary

**Strava provides similar activity data to Garmin, but with some important differences:**

✅ **Similar**: Activity summaries, GPS tracks, heart rate, elevation, cadence, temperature  
❌ **Missing**: Health metrics (weight, VO2 max), FIT files  
⚠️ **Different**: Data structure and field names

---

## Activity Data Comparison

### ✅ Both Provide (Activity Summary)

| Data Field | Garmin | Strava | Used in HYKA |
|------------|--------|--------|--------------|
| **Distance** | ✅ `distanceInMeters` | ✅ `distance` | ✅ Race planning, pace calculations |
| **Duration** | ✅ `durationInSeconds` | ✅ `elapsed_time`, `moving_time` | ✅ Race planning |
| **Elevation Gain** | ✅ `totalElevationGainInMeters` | ✅ `total_elevation_gain` | ✅ Segment calculations, race strategy |
| **Elevation Loss** | ✅ Computed from samples | ❌ Not in summary (can compute from streams) | ✅ Segment calculations |
| **Average Heart Rate** | ✅ `averageHeartRateInBeatsPerMinute` | ✅ `average_heartrate` | ✅ Pacing recommendations |
| **Max Heart Rate** | ✅ `maxHeartRateInBeatsPerMinute` | ✅ `max_heartrate` | ✅ Athlete analytics |
| **Average Cadence** | ✅ `averageRunCadenceInStepsPerMinute` | ✅ `average_cadence` | ✅ Activity analysis |
| **Max Cadence** | ✅ `maxRunCadenceInStepsPerMinute` | ❌ Not available | ⚠️ Not critical |
| **Average Speed** | ✅ `averageSpeedInMetersPerSecond` | ✅ `average_speed` | ✅ Pace calculations |
| **Max Speed** | ✅ `maxSpeedInMetersPerSecond` | ✅ `max_speed` | ⚠️ Not critical |
| **Calories** | ✅ `activeKilocalories` | ✅ `calories` | ✅ Fueling calculations |
| **Steps** | ✅ `steps` | ❌ Not available | ⚠️ Not critical |
| **Device Name** | ✅ `deviceName` | ✅ `device_name` | ✅ Activity metadata |
| **Activity Type** | ✅ `activityType` | ✅ `type`, `sport_type` | ✅ Activity filtering |
| **Start Time** | ✅ `startTimeInSeconds` | ✅ `start_date`, `start_date_local` | ✅ Activity timeline |

### ✅ Both Provide (Activity Samples/Streams)

| Data Field | Garmin | Strava | Used in HYKA |
|------------|--------|--------|--------------|
| **GPS Coordinates** | ✅ `latitudeInDegree`, `longitudeInDegree` | ✅ `latlng` stream | ✅ Segment calculations, route analysis |
| **Elevation** | ✅ `elevationInMeters` | ✅ `altitude` stream | ✅ Elevation gain/loss calculations |
| **Heart Rate** | ✅ `heartRate` | ✅ `heartrate` stream | ✅ Segment-specific HR analysis |
| **Speed/Velocity** | ✅ `speedMetersPerSecond` | ✅ `velocity_smooth` stream | ✅ Pace analysis |
| **Cadence** | ✅ `stepsPerMinute` | ✅ `cadence` stream | ✅ Running form analysis |
| **Temperature** | ✅ `airTemperatureCelcius` | ✅ `temp` stream | ✅ Fueling recommendations |
| **Time Offset** | ✅ `startTimeInSeconds` | ✅ `time` stream | ✅ Timeline alignment |

### ❌ Strava Missing (But Not Critical for Race Planning)

| Data Field | Garmin | Strava | Impact |
|------------|--------|--------|--------|
| **FIT Files** | ✅ Raw binary data | ❌ Not available | ⚠️ Less detailed sensor data, but streams provide similar info |
| **Steps** | ✅ `steps` | ❌ Not available | ⚠️ Not used in race planning |
| **Max Cadence** | ✅ `maxRunCadenceInStepsPerMinute` | ❌ Not available | ⚠️ Not used in race planning |
| **Elevation Loss** | ✅ Computed from samples | ❌ Not in summary (can compute) | ⚠️ Can be computed from streams |

### ❌ Strava Missing (Important for Athlete Analytics)

| Data Field | Garmin | Strava | Impact |
|------------|--------|--------|--------|
| **Weight** | ✅ From health metrics | ❌ Not available | ⚠️ Affects calorie calculations, athlete analytics |
| **VO2 Max** | ✅ From health metrics | ❌ Not available | ⚠️ Affects fitness level estimation |
| **Body Metrics** | ✅ BMI, body fat, etc. | ❌ Not available | ⚠️ Affects personalized recommendations |

---

## How HYKA Uses This Data

### 1. **Race Planning** (Both Providers Work ✅)

- **Distance & Duration**: Used for pace calculations
- **Elevation Gain/Loss**: Used for segment-specific pacing recommendations
- **Heart Rate**: Used for effort level recommendations
- **Temperature**: Used for fueling recommendations (hydration, sodium needs)
- **GPS Tracks**: Used for route analysis and aid station placement

**Verdict**: ✅ **Strava provides all necessary data for race planning**

### 2. **Athlete Analytics** (Garmin Better ⚠️)

- **Historical Workouts**: Both provide ✅
- **Weight**: Garmin ✅, Strava ❌
- **VO2 Max**: Garmin ✅, Strava ❌
- **Body Metrics**: Garmin ✅, Strava ❌

**Verdict**: ⚠️ **Strava works but with reduced accuracy for:**
- Calorie burn calculations (needs weight)
- Fitness level estimation (needs VO2 max)
- Personalized recommendations (needs body metrics)

### 3. **Activity Details** (Both Work ✅)

- **GPS Tracks**: Both provide detailed coordinates
- **Elevation Profiles**: Both provide altitude data
- **Heart Rate Zones**: Both provide HR data
- **Pace Analysis**: Both provide speed/velocity data

**Verdict**: ✅ **Strava provides equivalent detail through streams**

---

## Database Schema Comparison

### Garmin Tables

```sql
garmin_activities
  - distance_meters ✅
  - duration_seconds ✅
  - total_elevation_gain_meters ✅
  - total_elevation_loss_meters ✅ (computed)
  - average_heart_rate ✅
  - max_heart_rate ✅
  - average_cadence ✅
  - max_cadence ✅
  - calories ✅
  - steps ✅
  - device_name ✅

garmin_activity_samples
  - latitude ✅
  - longitude ✅
  - elevation_meters ✅
  - heart_rate ✅
  - speed_mps ✅
  - steps_per_minute ✅
  - air_temperature_celsius ✅

garmin_fit_files
  - file_data ✅ (raw binary)
  - file_size ✅
```

### Strava Tables

```sql
strava_activities
  - distance_meters ✅
  - elapsed_time ✅
  - moving_time ✅
  - total_elevation_gain_meters ✅
  - average_heart_rate ✅
  - max_heart_rate ✅
  - average_cadence ✅
  - calories ✅
  - device_name ✅
  - sport_type ✅ (additional)

strava_activity_samples
  - latitude ✅
  - longitude ✅
  - altitude_meters ✅
  - heart_rate ✅
  - velocity_smooth ✅
  - cadence ✅
  - temperature ✅
  - grade_smooth ✅ (additional)
  - moving ✅ (additional)
```

---

## Recommendations

### ✅ **For Race Planning**: Strava is Sufficient

Strava provides all the data needed for:
- Route analysis
- Segment calculations
- Pacing recommendations
- Fueling recommendations
- Aid station placement

### ⚠️ **For Athlete Analytics**: Garmin is Better

If you need:
- Accurate calorie burn calculations → Need weight (Garmin only)
- Fitness level estimation → Need VO2 max (Garmin only)
- Body composition tracking → Need body metrics (Garmin only)

**Workaround**: Users can manually enter weight in their profile, but VO2 max and body metrics won't be available.

### 🔄 **Unified View**: Both Work

The app already has a unified `unified_activities` view that combines:
- `garmin_activities`
- `strava_activities`

Both providers' data will appear in the same interface.

---

## Implementation Status

### ✅ Already Implemented

- ✅ Strava activity storage (`strava-activity-store`)
- ✅ Strava activity samples/streams storage
- ✅ Strava webhook handling (`strava-activity-webhook`)
- ✅ Strava push notifications (`strava-activity-notify`)
- ✅ Unified activities view (combines Garmin + Strava)

### ⚠️ Potential Improvements

1. **Elevation Loss Calculation**: Currently Garmin computes this from samples. Strava should do the same.
2. **Health Metrics Fallback**: If weight/VO2 max not available from Strava, use profile data or defaults.
3. **Data Quality Indicators**: Show which provider the data came from and data completeness.

---

## Conclusion

**Strava provides ~90% of the data that Garmin provides for race planning purposes.**

**Key Differences:**
- ✅ Activity data: Equivalent
- ✅ GPS tracks: Equivalent  
- ✅ Health metrics: Garmin only (weight, VO2 max)
- ✅ FIT files: Garmin only (but streams provide similar data)

**For HYKA's use case (ultra-running race planning):**
- ✅ **Strava is sufficient** for race planning features
- ⚠️ **Garmin is better** for athlete analytics and personalized recommendations

**Recommendation**: Support both providers. Users can choose based on their preference, and the app will work with either.

