-- ============================================================================
-- Create unified_activities View (if it doesn't exist)
-- ============================================================================
-- Run this in Supabase SQL Editor to ensure the view exists

-- Drop view if it exists (to recreate it)
DROP VIEW IF EXISTS unified_activities;

-- Create the unified_activities view
CREATE OR REPLACE VIEW unified_activities AS
SELECT 
    w.id,
    w.user_id,
    w.provider,
    w.provider_activity_id,
    w.name,
    w.start_time,
    w.elapsed_seconds AS duration_seconds,
    w.distance_m AS distance_meters,
    w.elevation_gain_m AS elevation_gain_meters,
    w.avg_hr AS average_heart_rate,
    w.max_hr AS max_heart_rate,
    w.activity_type_code AS activity_type,
    w.created_at,
    'workouts' AS source_table
FROM workouts w
WHERE w.provider != 'garmin'

UNION ALL

SELECT 
    ga.id,
    ga.user_id,
    'garmin' AS provider,
    ga.garmin_activity_id AS provider_activity_id,
    ga.activity_name AS name,
    ga.start_time,
    ga.duration_seconds,
    ga.distance_meters,
    ga.total_elevation_gain_meters AS elevation_gain_meters,
    ga.average_heart_rate,
    ga.max_heart_rate,
    ga.activity_type,
    ga.created_at,
    'garmin_activities' AS source_table
FROM garmin_activities ga;

-- Add comment
COMMENT ON VIEW unified_activities IS 'Combines activities from all providers (Garmin + others) for iOS app consumption';

-- Grant permissions (if needed)
GRANT SELECT ON unified_activities TO authenticated;
GRANT SELECT ON unified_activities TO anon;

-- Verify the view was created
SELECT 
    'View created successfully!' AS status,
    COUNT(*) AS total_activities_in_view
FROM unified_activities;

