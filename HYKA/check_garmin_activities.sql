-- ============================================================================
-- Diagnostic Queries for Garmin Activities
-- ============================================================================
-- Run these in Supabase SQL Editor to debug why activities aren't appearing
-- ============================================================================

-- 1. Check if tables exist
SELECT 
  table_name,
  (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = t.table_name) as column_count
FROM information_schema.tables t
WHERE table_schema = 'public' 
  AND table_name IN ('garmin_activities', 'garmin_activity_samples', 'garmin_connections', 'app_config')
ORDER BY table_name;

-- 2. Check Garmin connections (should have at least one)
SELECT 
  id,
  user_id,
  garmin_user_id,
  created_at,
  last_sync_at,
  token_expires_at
FROM garmin_connections
ORDER BY created_at DESC;

-- 3. Check if activities exist
SELECT 
  COUNT(*) as total_activities,
  COUNT(DISTINCT user_id) as unique_users,
  MIN(created_at) as oldest_activity,
  MAX(created_at) as newest_activity
FROM garmin_activities;

-- 4. Check recent activities
SELECT 
  id,
  user_id,
  garmin_activity_id,
  activity_name,
  activity_type,
  start_time,
  distance_meters,
  duration_seconds,
  created_at
FROM garmin_activities
ORDER BY created_at DESC
LIMIT 10;

-- 5. Check activity samples
SELECT 
  COUNT(*) as total_samples,
  COUNT(DISTINCT activity_id) as activities_with_samples
FROM garmin_activity_samples;

-- 6. Check unified_activities view
SELECT 
  source_table,
  COUNT(*) as count
FROM unified_activities
GROUP BY source_table;

-- 7. Check if user has connection but no activities
SELECT 
  gc.user_id,
  gc.garmin_user_id,
  gc.created_at as connection_created,
  gc.last_sync_at,
  COUNT(ga.id) as activity_count
FROM garmin_connections gc
LEFT JOIN garmin_activities ga ON ga.user_id = gc.user_id
GROUP BY gc.id, gc.user_id, gc.garmin_user_id, gc.created_at, gc.last_sync_at
ORDER BY activity_count ASC, gc.created_at DESC;

-- 8. Check RLS policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename IN ('garmin_activities', 'garmin_activity_samples', 'garmin_connections')
ORDER BY tablename, policyname;

-- 9. Check Pull Token
SELECT 
  key,
  value,
  description,
  updated_at
FROM app_config
WHERE key = 'garmin_pull_token';

-- 10. Check for errors in recent activities (check raw_data for clues)
SELECT 
  garmin_activity_id,
  activity_type,
  start_time,
  created_at,
  CASE 
    WHEN raw_data IS NULL THEN 'No raw data'
    WHEN raw_data::text = '{}' THEN 'Empty raw data'
    ELSE 'Has raw data'
  END as raw_data_status
FROM garmin_activities
ORDER BY created_at DESC
LIMIT 5;

