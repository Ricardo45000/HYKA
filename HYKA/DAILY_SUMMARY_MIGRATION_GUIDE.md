# Daily Summary Migration Guide

## Problem

Currently, `garmin_health_metrics` creates **multiple rows per day** - one for each webhook type:
- `userMetrics` webhook → row with `fitness_age`, `vo2_max` (no steps/calories)
- `dailies` webhook → row with `steps`, `active_calories` (no fitness_age/vo2_max)
- `sleeps` webhook → row with sleep data (no daily activity)
- `epochs` webhook → row with per-epoch data

This results in:
- ❌ Multiple rows per day with incomplete data
- ❌ NULL values scattered across rows
- ❌ Difficult to query "daily summary"

## Solution

**Merge all webhook types into ONE daily summary row per user per day.**

### Benefits:
- ✅ One complete row per day with all metrics
- ✅ No NULL values (data merged from all webhooks)
- ✅ Easier queries (just filter by `metric_date`)
- ✅ Better data consistency

## Migration Steps

### Step 1: Run SQL Migration

Execute `change_to_daily_summary.sql` in Supabase SQL Editor:

1. **Drops old constraint**: Removes `(user_id, timestamp)` unique constraint
2. **Creates new constraint**: Adds `(user_id, garmin_user_id, metric_date)` unique constraint
3. **Consolidates existing data**: Merges all existing rows per date into one summary
4. **Verifies results**: Shows statistics on consolidation

### Step 2: Deploy Updated Webhook

The webhook has been updated to:
- Use the new `(user_id, garmin_user_id, metric_date)` constraint
- Merge data using `COALESCE` (only fills NULLs, doesn't overwrite existing data)
- Automatically consolidate all webhook types into one daily row

Deploy with:
```bash
cd "/Volumes/Rissie T7/Ricardo/Project/HYKA_V1_Starter/HYKA/HYKA"
SUPABASE_ACCESS_TOKEN=sbp_8c07a6059f0aa70a55feee1882bbee574cd6e175 \
npx supabase functions deploy garmin-health-webhook \
  --project-ref gvfhtiljkybbrbxoyqsq \
  --no-verify-jwt
```

## How It Works

### Before (Multiple Rows):
```
Date: 2026-01-13
├─ Row 1: userMetrics → fitness_age: 18, vo2_max: 49, steps: NULL
├─ Row 2: dailies → steps: 3005, active_calories: 131, fitness_age: NULL
└─ Row 3: sleeps → rem_sleep_seconds: 16020, steps: NULL
```

### After (One Daily Summary):
```
Date: 2026-01-13
└─ Row 1: Daily Summary
   ├─ fitness_age: 18 (from userMetrics)
   ├─ vo2_max: 49 (from userMetrics)
   ├─ steps: 3005 (from dailies)
   ├─ active_calories: 131 (from dailies)
   └─ rem_sleep_seconds: 16020 (from sleeps)
```

### Webhook Flow:

1. **`userMetrics` webhook arrives** (2026-01-13):
   - Creates row with `fitness_age: 18`, `vo2_max: 49`
   - ✅ Stored

2. **`dailies` webhook arrives** (same date):
   - Looks up existing row for 2026-01-13
   - Merges: `steps: 3005`, `active_calories: 131`
   - Updates existing row (doesn't create new one)
   - ✅ Complete data

3. **`sleeps` webhook arrives** (same date):
   - Looks up existing row for 2026-01-13
   - Merges: `rem_sleep_seconds: 16020`
   - Updates existing row
   - ✅ Complete data

## Data Merging Logic

The webhook uses **COALESCE** logic:
- **New value is NULL** → Keep existing value
- **New value exists** → Use new value (overwrites NULL, but not existing non-NULL)
- **Both exist** → Keep existing (first write wins for non-NULL values)

This ensures:
- All webhook types contribute their data
- No data loss
- Most complete record wins

## Verification

After migration, verify with:

```sql
-- Should show 0 duplicates (one row per date)
SELECT 
  user_id,
  garmin_user_id,
  metric_date,
  COUNT(*) as row_count
FROM garmin_health_metrics
WHERE metric_date IS NOT NULL
GROUP BY user_id, garmin_user_id, metric_date
HAVING COUNT(*) > 1;

-- Should show complete data (no NULLs for common fields)
SELECT 
  metric_date,
  fitness_age,
  vo2_max,
  steps,
  active_calories,
  rem_sleep_seconds
FROM garmin_health_metrics
WHERE metric_date = '2026-01-13'
ORDER BY metric_date DESC
LIMIT 10;
```

## Rollback (If Needed)

If you need to rollback:

```sql
-- Drop new constraint
ALTER TABLE public.garmin_health_metrics
DROP CONSTRAINT IF EXISTS garmin_health_metrics_user_date_unique;

-- Recreate old constraint
ALTER TABLE public.garmin_health_metrics
ADD CONSTRAINT garmin_health_metrics_user_id_timestamp_key 
UNIQUE (user_id, timestamp);
```

**Note**: Rollback will NOT restore the original multiple rows (they've been consolidated). You'd need a database backup to fully restore.

## Next Steps

1. ✅ Run `change_to_daily_summary.sql`
2. ✅ Deploy updated webhook
3. ✅ Verify consolidation worked
4. ✅ Test with new webhook data

Future webhooks will automatically merge into daily summaries! 🎉
