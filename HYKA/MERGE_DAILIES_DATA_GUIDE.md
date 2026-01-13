# Merge Dailies Data Guide

## Problem

Different Garmin webhook types contain different data:
- **`userMetrics`** webhooks: `fitnessAge`, `vo2Max` (NO daily activity data)
- **`dailies`** webhooks: `steps`, `activeCalories`, `restingHeartRate`, etc. (daily activity data)
- **`sleeps`** webhooks: Sleep data only
- **`epochs`** webhooks: Per-epoch data (15-minute intervals)

This results in many rows with NULL values for `steps`, `active_calories`, `resting_heart_rate`, etc.

## Solution

### 1. Webhook Enhancement (Already Deployed ✅)

The webhook now:
- Extracts daily activity data from `dailies` webhooks
- When processing `userMetrics`/`healthSnapshot` webhooks, looks up existing `dailies` data for the same date
- Merges the data so all records have complete information

### 2. Backfill Existing Data

Run `merge_dailies_data.sql` to merge existing data:

```sql
-- This script:
-- 1. Creates a function to merge dailies data for a specific date
-- 2. Runs the merge for all unique date/user combinations
-- 3. Shows statistics on the merge results
```

**Run this once** to fix existing data.

## How It Works

### Webhook Flow:

1. **`dailies` webhook arrives**:
   - Extracts: `steps`, `activeCalories`, `restingHeartRate`, etc.
   - Stores in database ✅

2. **`userMetrics` webhook arrives** (same date):
   - Extracts: `fitnessAge`, `vo2Max`
   - Looks up existing `dailies` data for that date
   - Merges: Includes `steps`, `activeCalories`, etc. from dailies
   - Stores in database ✅

3. **`sleeps` webhook arrives** (same date):
   - Extracts: Sleep data
   - Looks up existing `dailies` data for that date
   - Merges: Includes daily activity data
   - Stores in database ✅

### Backfill Script:

The backfill script:
1. Finds the most complete `dailies` record for each date
2. Merges its data into all other records for that date
3. Only fills NULL values (doesn't overwrite existing data)

## Expected Results

### Before:
- `userMetrics` records: `fitness_age: 18`, `vo2_max: 49`, but `steps: NULL`, `active_calories: NULL`
- `dailies` records: `steps: 3005`, `active_calories: 131`, but `fitness_age: NULL`, `vo2_max: NULL`
- Many NULL values across different webhook types

### After:
- All records for the same date have complete data:
  - `fitness_age` and `vo2_max` (from `userMetrics`)
  - `steps`, `active_calories`, `resting_heart_rate` (from `dailies`)
  - Sleep data (from `sleeps`)
  - Minimal NULL values ✅

## Execution

1. **Run the backfill script**:
   ```sql
   -- Execute: merge_dailies_data.sql
   ```

2. **Verify results**:
   ```sql
   SELECT 
     COUNT(*) as total_rows,
     COUNT(steps) as rows_with_steps,
     COUNT(active_calories) as rows_with_active_calories
   FROM garmin_health_metrics;
   ```

## Notes

- The webhook merge happens **on insert** (for new webhooks)
- The backfill script fixes **existing data**
- Both approaches use `COALESCE` to only fill NULL values (never overwrite existing data)
- The merge is based on `metric_date`, not `timestamp` (since different webhook types have different timestamps)
