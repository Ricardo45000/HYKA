-- ============================================================================
-- Verify unified_activities View and Data
-- ============================================================================
-- Run this in Supabase SQL Editor to verify the view exists and has data

-- 1. Check if view exists
SELECT 
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name = 'unified_activities';

-- 2. Check view definition
SELECT 
    view_definition
FROM information_schema.views
WHERE table_schema = 'public'
AND table_name = 'unified_activities';

-- 3. Count activities in garmin_activities table
SELECT 
    COUNT(*) as total_garmin_activities,
    COUNT(DISTINCT user_id) as users_with_activities,
    MIN(start_time) as oldest_activity,
    MAX(start_time) as newest_activity
FROM garmin_activities;

-- 4. Count activities in workouts table (non-Garmin)
SELECT 
    COUNT(*) as total_workouts,
    COUNT(DISTINCT user_id) as users_with_workouts
FROM workouts
WHERE provider != 'garmin';

-- 5. Count activities in unified_activities view
SELECT 
    COUNT(*) as total_unified_activities,
    COUNT(DISTINCT user_id) as users_with_unified_activities,
    COUNT(*) FILTER (WHERE provider = 'garmin') as garmin_count,
    COUNT(*) FILTER (WHERE provider != 'garmin') as other_providers_count
FROM unified_activities;

-- 6. Sample data from unified_activities (first 10)
SELECT 
    id,
    user_id,
    provider,
    name,
    start_time,
    duration_seconds,
    distance_meters,
    activity_type,
    created_at
FROM unified_activities
ORDER BY start_time DESC
LIMIT 10;

-- 7. Check for a specific user (replace with your user_id)
-- SELECT 
--     id,
--     provider,
--     name,
--     start_time,
--     distance_meters,
--     activity_type
-- FROM unified_activities
-- WHERE user_id = 'YOUR_USER_ID_HERE'
-- ORDER BY start_time DESC
-- LIMIT 20;

