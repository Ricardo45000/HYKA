# Garmin Health Webhook Data Breakdown

## Overview

Each webhook type contains different data. Here's what each one provides:

---

## 1. **userMetrics** Webhook ✅ KEEP

**Contains:**
- ✅ `fitnessAge` (fitness age)
- ✅ `vo2Max` (VO2 Max)
- ✅ `calendarDate` (date)
- ⚠️ `callbackURL` (may need to fetch more data)

**What it's missing:**
- ❌ `steps`
- ❌ `activeCalories`
- ❌ `totalCalories`
- ❌ `restingHeartRate`
- ❌ `avgHeartRate`
- ❌ `maxHeartRate`
- ❌ `minHeartRate`
- ❌ Sleep data
- ❌ Stress/Body Battery

**Frequency:** Daily (when fitness metrics update)

**Recommendation:** ✅ **KEEP** - This is the ONLY source of `fitness_age` and `vo2_max`

---

## 2. **dailies** Webhook ✅ KEEP

**Contains:**
- ✅ `steps` (daily step count)
- ✅ `activeKilocalories` (active calories burned)
- ✅ `bmrKilocalories` (total calories = BMR + active)
- ✅ `restingHeartRateInBeatsPerMinute` (resting HR)
- ✅ `averageHeartRateInBeatsPerMinute` (avg HR)
- ✅ `maxHeartRateInBeatsPerMinute` (max HR)
- ✅ `minHeartRateInBeatsPerMinute` (min HR)
- ✅ `stressLevel` (from `timeOffsetStressLevelValues` - average)
- ✅ `bodyBattery` (from `timeOffsetBodyBatteryValues` - average)
- ✅ `calendarDate` (date)
- ✅ `distanceInMeters` (total distance)
- ✅ `durationInSeconds` (active time)
- ✅ `floorsClimbed` (if available)

**What it's missing:**
- ❌ `fitnessAge`
- ❌ `vo2Max`
- ❌ Sleep data (duration, stages, etc.)
- ❌ Per-epoch respiration data

**Frequency:** Daily (once per day)

**Recommendation:** ✅ **KEEP** - This is the PRIMARY source of daily activity data (steps, calories, heart rate)

---

## 3. **sleeps** Webhook ✅ KEEP

**Contains:**
- ✅ `durationInSeconds` (total sleep duration)
- ✅ `deepSleepDurationInSeconds` (deep sleep)
- ✅ `lightSleepDurationInSeconds` (light sleep)
- ✅ `remSleepInSeconds` (REM sleep)
- ✅ `awakeDurationInSeconds` (awake time)
- ✅ `startTimeInSeconds` (sleep start)
- ✅ `calendarDate` (date)
- ✅ `sleepLevelsMap` (detailed sleep stages)
- ✅ `timeOffsetSleepRespiration` (respiration during sleep)
- ✅ `timeOffsetSleepSpo2` (SpO2 during sleep, if available)

**What it's missing:**
- ❌ `fitnessAge`
- ❌ `vo2Max`
- ❌ `steps`
- ❌ `activeCalories`
- ❌ `restingHeartRate`
- ❌ `avgHeartRate`

**Frequency:** Daily (once per day, after sleep ends)

**Recommendation:** ✅ **KEEP** - This is the ONLY source of detailed sleep data

---

## 4. **epochs** Webhook ⚠️ CONSIDER REMOVING

**Contains:**
- ✅ `steps` (per 15-minute epoch)
- ✅ `activeKilocalories` (per epoch)
- ✅ `avgRespirationRate` (from `timeOffsetEpochToBreaths`)
- ✅ `startTimeInSeconds` (epoch start time)
- ✅ `durationInSeconds` (900 seconds = 15 minutes)
- ✅ `intensity` (SEDENTARY, ACTIVE, etc.)
- ✅ `activityType` (GENERIC, SEDENTARY, etc.)

**What it's missing:**
- ❌ `fitnessAge`
- ❌ `vo2Max`
- ❌ Daily totals (only per-epoch data)
- ❌ Sleep data
- ❌ Heart rate data

**Frequency:** Very frequent (every 15 minutes = 96 webhooks per day!)

**Recommendation:** ⚠️ **CONSIDER REMOVING** - This creates 96 rows per day with minimal data. The `dailies` webhook already provides daily totals.

**Why remove:**
- Creates excessive database rows (96 per day)
- Data is already aggregated in `dailies` webhook
- Per-epoch data is rarely needed for daily summaries
- Increases database storage and processing costs

**When to keep:**
- If you need minute-by-minute activity tracking
- If you're building detailed activity graphs
- If you need per-epoch respiration data

---

## 5. **stressDetails** Webhook ⚠️ CONSIDER REMOVING

**Contains:**
- ✅ `timeOffsetStressLevelValues` (stress level over time)
- ✅ `calendarDate` (date)

**What it's missing:**
- ❌ Everything else (steps, calories, heart rate, sleep, fitness metrics)

**Frequency:** Daily (once per day)

**Recommendation:** ⚠️ **CONSIDER REMOVING** - Stress data is already included in `dailies` webhook as `averageStressLevel`

**Why remove:**
- Redundant (stress is in `dailies`)
- Creates duplicate rows
- Minimal additional value

**When to keep:**
- If you need minute-by-minute stress tracking
- If you're building detailed stress graphs

---

## 6. **allDayRespiration** Webhook ⚠️ CONSIDER REMOVING

**Contains:**
- ✅ `timeOffsetEpochToBreaths` (respiration rate over time)
- ✅ `startTimeInSeconds` (start time)

**What it's missing:**
- ❌ Everything else (steps, calories, heart rate, sleep, fitness metrics)

**Frequency:** Daily (once per day)

**Recommendation:** ⚠️ **CONSIDER REMOVING** - Respiration data is already included in `sleeps` webhook (`timeOffsetSleepRespiration`)

**Why remove:**
- Redundant (respiration is in `sleeps` for sleep period)
- Creates duplicate rows
- Minimal additional value (only awake respiration)

**When to keep:**
- If you need awake respiration tracking
- If you're building detailed respiration graphs

---

## 7. **healthSnapshot** Webhook ✅ KEEP (if available)

**Contains:**
- ✅ `fitnessAge` (fitness age)
- ✅ `vo2Max` (VO2 Max)
- ✅ `calendarDate` (date)
- ✅ May include other health metrics

**What it's missing:**
- ❌ `steps`
- ❌ `activeCalories`
- ❌ Sleep data

**Frequency:** Periodic (when health snapshot updates)

**Recommendation:** ✅ **KEEP** - Similar to `userMetrics`, provides fitness metrics

---

## 8. **bodyComposition** Webhook ⚠️ OPTIONAL

**Contains:**
- ✅ `weight` (body weight)
- ✅ `bodyFatPercentage` (if available)
- ✅ `muscleMass` (if available)
- ✅ `boneMass` (if available)
- ✅ `bodyWaterPercentage` (if available)

**What it's missing:**
- ❌ Everything else (steps, calories, heart rate, sleep, fitness metrics)

**Frequency:** Periodic (when body composition is measured)

**Recommendation:** ⚠️ **OPTIONAL** - Only keep if you need body composition tracking

---

## Recommended Webhook Configuration

### ✅ **KEEP (Essential):**
1. **`userMetrics`** - Fitness age & VO2 Max
2. **`dailies`** - Daily activity (steps, calories, heart rate, stress, body battery)
3. **`sleeps`** - Sleep data (duration, stages, respiration)

### ⚠️ **REMOVE (Redundant/Excessive):**
1. **`epochs`** - Creates 96 rows/day, data already in `dailies`
2. **`stressDetails`** - Redundant (stress in `dailies`)
3. **`allDayRespiration`** - Redundant (respiration in `sleeps`)

### ⚠️ **OPTIONAL:**
1. **`healthSnapshot`** - Keep if available (similar to `userMetrics`)
2. **`bodyComposition`** - Keep only if you need weight/body composition tracking

---

## Data Coverage with Recommended Webhooks

With **`userMetrics`**, **`dailies`**, and **`sleeps`** only:

| Field | Source | Coverage |
|-------|--------|----------|
| `fitness_age` | `userMetrics` | ✅ Complete |
| `vo2_max` | `userMetrics` | ✅ Complete |
| `steps` | `dailies` | ✅ Complete |
| `active_calories` | `dailies` | ✅ Complete |
| `total_calories` | `dailies` | ✅ Complete |
| `resting_heart_rate` | `dailies` | ✅ Complete |
| `avg_heart_rate` | `dailies` | ✅ Complete |
| `max_heart_rate` | `dailies` | ✅ Complete |
| `min_heart_rate` | `dailies` | ✅ Complete |
| `stress_level` | `dailies` | ✅ Complete |
| `body_battery` | `dailies` | ✅ Complete |
| `sleep_duration_seconds` | `sleeps` | ✅ Complete |
| `deep_sleep_seconds` | `sleeps` | ✅ Complete |
| `light_sleep_seconds` | `sleeps` | ✅ Complete |
| `rem_sleep_seconds` | `sleeps` | ✅ Complete |
| `awake_seconds` | `sleeps` | ✅ Complete |
| `avg_respiration_rate` | `sleeps` | ✅ Complete (during sleep) |

**Result:** ✅ **100% coverage** with just 3 webhooks!

---

## How to Remove Webhooks in Garmin Developer Portal

1. Go to: https://developer.garmin.com/health-api/health-api/developer-guide/
2. Navigate to your app's webhook configuration
3. Remove the following webhook types:
   - `epochs`
   - `stressDetails`
   - `allDayRespiration`
4. Keep only:
   - `userMetrics`
   - `dailies`
   - `sleeps`
   - (Optional: `healthSnapshot`, `bodyComposition`)

---

## Impact of Removing Webhooks

### Before (with all webhooks):
- **Rows per day:** ~100+ (userMetrics + dailies + sleeps + 96 epochs + stressDetails + allDayRespiration)
- **Database size:** Large (many redundant rows)
- **Processing time:** High (many webhook calls)

### After (with recommended webhooks):
- **Rows per day:** 3 (userMetrics + dailies + sleeps) → **merged to 1** with daily summary
- **Database size:** ~97% reduction
- **Processing time:** ~97% reduction

**Result:** ✅ Much cleaner, more efficient, complete data coverage!
