# Optimize Fitness Metrics (fitness_age & vo2_max)

## Problem

Many rows in `garmin_health_metrics` have NULL values for `fitness_age` and `vo2_max` because:
- These fields only come from `userMetrics` webhooks
- `sleeps`, `epochs`, and `dailies` webhooks don't include them
- This leaves many rows with NULL values

## Solution: 3-Step Approach

### Step 1: Backfill Existing NULL Values

Run `backfill_fitness_age_vo2max.sql` to update all existing NULL values:

```sql
-- This will:
-- 1. Create a helper function to get latest values
-- 2. Update all NULL values with latest available values per user
-- 3. Show statistics on the update
```

**Run this once** to fix existing data.

### Step 2: Auto-Fill Trigger (Recommended)

Run `auto_fill_fitness_metrics_trigger.sql` to create a trigger that automatically fills NULL values:

```sql
-- This creates a trigger that:
-- 1. Runs BEFORE INSERT OR UPDATE
-- 2. Automatically fills NULL fitness_age and vo2_max with latest available values
-- 3. Works for all future webhooks automatically
```

**This ensures all new records are automatically filled.**

### Step 3: Webhook Enhancement (Already Done)

The webhook function has been updated to:
- Extract `fitness_age` and `vo2_max` when present
- Look up latest values when missing (for sleeps/epochs/dailies)

## Execution Order

1. **First**: Run `backfill_fitness_age_vo2max.sql` to fix existing data
2. **Second**: Run `auto_fill_fitness_metrics_trigger.sql` to enable auto-fill for future records
3. **Done**: All records (existing and future) will have `fitness_age` and `vo2_max` populated

## Expected Results

### Before:
- Many rows with `fitness_age: NULL` and `vo2_max: NULL`
- Only `userMetrics` webhooks have these values

### After:
- All rows have `fitness_age` and `vo2_max` (from latest available values)
- Trigger automatically fills new records
- Webhook also tries to fill them on insert

## Performance Considerations

### Trigger Performance:
- The trigger performs a single SELECT query per insert/update
- It only runs when `fitness_age` or `vo2_max` is NULL
- Uses an index on `(user_id, garmin_user_id, metric_date DESC)`
- Should be fast (< 10ms per insert)

### Optimization Tips:

1. **Add index** (if not exists):
   ```sql
   CREATE INDEX IF NOT EXISTS idx_garmin_health_metrics_user_fitness 
   ON garmin_health_metrics(user_id, garmin_user_id, metric_date DESC) 
   WHERE fitness_age IS NOT NULL AND vo2_max IS NOT NULL;
   ```

2. **Monitor trigger performance**:
   ```sql
   -- Check trigger execution time
   EXPLAIN ANALYZE 
   INSERT INTO garmin_health_metrics (user_id, garmin_user_id, timestamp, metric_date)
   VALUES ('test-user-id', 'test-garmin-id', NOW(), CURRENT_DATE);
   ```

## Alternative: Periodic Update Function

If you prefer not to use a trigger, you can create a scheduled function:

```sql
-- Run this periodically (e.g., daily) to update NULL values
CREATE OR REPLACE FUNCTION update_null_fitness_metrics()
RETURNS void AS $$
BEGIN
  UPDATE garmin_health_metrics ghm
  SET 
    fitness_age = COALESCE(
      ghm.fitness_age,
      (SELECT fitness_age FROM get_latest_fitness_metrics(ghm.user_id, ghm.garmin_user_id))
    ),
    vo2_max = COALESCE(
      ghm.vo2_max,
      (SELECT vo2_max FROM get_latest_fitness_metrics(ghm.user_id, ghm.garmin_user_id))
    )
  WHERE (ghm.fitness_age IS NULL OR ghm.vo2_max IS NULL)
    AND EXISTS (
      SELECT 1 FROM get_latest_fitness_metrics(ghm.user_id, ghm.garmin_user_id)
    );
END;
$$ LANGUAGE plpgsql;
```

## Verification

After running both scripts, verify with:

```sql
-- Check NULL counts
SELECT 
  COUNT(*) as total_rows,
  COUNT(fitness_age) as rows_with_fitness_age,
  COUNT(vo2_max) as rows_with_vo2_max,
  COUNT(*) - COUNT(fitness_age) as null_fitness_age,
  COUNT(*) - COUNT(vo2_max) as null_vo2_max
FROM garmin_health_metrics;

-- Should show 0 NULL values (or very few if no userMetrics webhooks have arrived yet)
```

## Notes

- The trigger only fills values if they exist for that user
- If a user has never received a `userMetrics` webhook, values will remain NULL
- Values are filled from the most recent available record (by `metric_date` and `updated_at`)
- The trigger runs **before** insert/update, so it's transparent to the webhook function
