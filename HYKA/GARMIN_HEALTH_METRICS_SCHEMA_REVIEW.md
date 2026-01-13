# Garmin Health Metrics Schema Review & Optimization

## ✅ What Works

1. **Both tables have `fitness_age`** - The error should be resolved ✅
2. **Proper indexes** - Good coverage for common queries
3. **Unique constraints** - Prevents duplicate data
4. **Foreign keys** - Proper referential integrity

## ⚠️ Critical Issues to Fix

### 1. Foreign Key Mismatch (CRITICAL)

**Problem:**
- `garmin_health_metrics.user_id` → references `auth.users(id)`
- `health_metrics.user_id` → references `profiles(id)`

**Why this matters:**
- The trigger syncs from `garmin_health_metrics` to `health_metrics`
- If `profiles.id` ≠ `auth.users.id`, the trigger will fail with foreign key violation

**Solution:**
Verify that `profiles.id` = `auth.users.id` (standard Supabase pattern). If they're the same, you're good. If not, you need to fix the foreign key:

```sql
-- Option 1: If profiles.id = auth.users.id (standard), keep as is
-- Option 2: If different, change health_metrics to reference auth.users:
ALTER TABLE public.health_metrics
DROP CONSTRAINT IF EXISTS health_metrics_user_id_fkey;

ALTER TABLE public.health_metrics
ADD CONSTRAINT health_metrics_user_id_fkey 
FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
```

### 2. Trigger Error Handling

The trigger doesn't handle cases where:
- User exists in `garmin_health_metrics` but not in `profiles`
- `fitness_age` is NULL (should be fine, but verify)

**Recommendation:** Add error handling to the trigger function.

## 📊 Schema Analysis

### `garmin_health_metrics` (35 columns)

**Good:**
- ✅ Comprehensive coverage of Garmin data
- ✅ All optional fields are nullable (good for partial data)
- ✅ Proper indexes on common query fields
- ✅ `raw_data` JSONB for flexibility

**Potential Issues:**
- ⚠️ **35 columns** - Large row size, but acceptable for health data
- ⚠️ **Many nullable fields** - Consider if some should have defaults
- ⚠️ **No partition strategy** - Could grow large over time

**Recommendations:**
1. **Consider partitioning** by `metric_date` if table grows > 10M rows
2. **Archive old data** - Move data > 2 years old to archive table
3. **Add check constraints** for data validation:
   ```sql
   ALTER TABLE garmin_health_metrics
   ADD CONSTRAINT check_steps_positive CHECK (steps IS NULL OR steps >= 0);
   
   ALTER TABLE garmin_health_metrics
   ADD CONSTRAINT check_heart_rate_range CHECK (
     resting_heart_rate IS NULL OR (resting_heart_rate >= 30 AND resting_heart_rate <= 220)
   );
   ```

### `health_metrics` (11 columns)

**Good:**
- ✅ Unified table design (good for multi-provider)
- ✅ Proper unique constraint on (user_id, provider, date)
- ✅ Numeric types for precision (vo2_max, weight_kg, fitness_age)

**Potential Issues:**
- ⚠️ **Missing `age_years`** - Referenced in trigger function but not in schema?
- ⚠️ **No provider-specific fields** - Some providers might have unique metrics

**Recommendations:**
1. **Add `age_years` column** if needed by app:
   ```sql
   ALTER TABLE public.health_metrics
   ADD COLUMN IF NOT EXISTS age_years INTEGER;
   ```

2. **Consider adding provider metadata**:
   ```sql
   ALTER TABLE public.health_metrics
   ADD COLUMN IF NOT EXISTS provider_metadata JSONB;
   ```

## 🚀 Optimization Recommendations

### 1. Index Optimization

**Current indexes are good, but consider adding:**

```sql
-- Composite index for common queries (user + date range)
CREATE INDEX IF NOT EXISTS idx_health_metrics_user_provider_date 
ON public.health_metrics(user_id, provider, date DESC);

-- Index for fitness_age queries (if you filter by this)
CREATE INDEX IF NOT EXISTS idx_health_metrics_fitness_age 
ON public.health_metrics(user_id, fitness_age) 
WHERE fitness_age IS NOT NULL;
```

### 2. Query Performance

**For time-series queries, consider:**

```sql
-- Partial index for recent data (faster queries)
CREATE INDEX IF NOT EXISTS idx_garmin_health_metrics_recent 
ON public.garmin_health_metrics(user_id, metric_date DESC) 
WHERE metric_date >= CURRENT_DATE - INTERVAL '1 year';
```

### 3. Data Retention Policy

**Add a function to archive old data:**

```sql
CREATE OR REPLACE FUNCTION archive_old_garmin_health_metrics()
RETURNS void AS $$
BEGIN
  -- Move data older than 2 years to archive table
  INSERT INTO garmin_health_metrics_archive
  SELECT * FROM garmin_health_metrics
  WHERE metric_date < CURRENT_DATE - INTERVAL '2 years';
  
  DELETE FROM garmin_health_metrics
  WHERE metric_date < CURRENT_DATE - INTERVAL '2 years';
END;
$$ LANGUAGE plpgsql;
```

### 4. Trigger Optimization

**Current trigger is good, but consider:**

```sql
-- Only sync if data actually changed
CREATE OR REPLACE FUNCTION sync_garmin_to_health_metrics()
RETURNS TRIGGER AS $$
BEGIN
  -- Skip if no meaningful data
  IF NEW.vo2_max IS NULL 
     AND NEW.sleep_score IS NULL 
     AND NEW.recovery_score IS NULL 
     AND NEW.resting_heart_rate IS NULL 
     AND NEW.fitness_age IS NULL THEN
    RETURN NEW;
  END IF;
  
  -- Rest of trigger logic...
END;
$$ LANGUAGE plpgsql;
```

## 📋 Field Count Analysis

### `garmin_health_metrics`: 35 columns

**Breakdown:**
- **Core fields (5):** id, user_id, garmin_user_id, timestamp, metric_date
- **Daily activity (7):** steps, active_calories, total_calories, resting_heart_rate, avg_heart_rate, max_heart_rate, min_heart_rate
- **Sleep (8):** sleep_duration_seconds, sleep_score, deep_sleep_seconds, light_sleep_seconds, rem_sleep_seconds, awake_seconds, sleep_start_time, sleep_end_time
- **Recovery (3):** recovery_score, recovery_time_hours, stress_level, body_battery
- **Training (3):** training_load, training_status, training_readiness
- **Body metrics (5):** weight_kg, avg_respiration_rate, avg_spo2, min_spo2, hrv_status, hrv_value
- **Metadata (4):** device_name, raw_data, created_at, updated_at
- **Fitness (2):** fitness_age, vo2_max

**Verdict:** ✅ **Not too many** - This is appropriate for comprehensive health data. Garmin provides all these metrics, so storing them makes sense.

### `health_metrics`: 11 columns

**Verdict:** ✅ **Perfect size** - Unified table should be lean.

## ✅ Final Recommendations

### Must Fix:
1. ✅ **Verify foreign key consistency** - Ensure `profiles.id` = `auth.users.id`
2. ✅ **Test trigger** - Make sure sync works end-to-end

### Should Consider:
1. **Add data validation constraints** (steps >= 0, heart rate ranges)
2. **Add `age_years` to health_metrics** if needed
3. **Consider partitioning** if table grows large
4. **Add archive strategy** for old data

### Nice to Have:
1. **Add composite indexes** for common query patterns
2. **Add partial indexes** for recent data queries
3. **Optimize trigger** to skip empty rows

## 🎯 Conclusion

**Your schema is well-designed!** 

- ✅ Field count is appropriate (not too many)
- ✅ Structure is logical (provider-specific + unified)
- ✅ Indexes are good
- ⚠️ Just verify the foreign key consistency

The main thing to check is that `profiles.id` matches `auth.users.id` (which is standard in Supabase). If they do, you're all set! 🚀
