-- ============================================================================
-- Check and Handle Processed Garmin Backfill Requests
-- ============================================================================
-- This script helps you:
-- 1. Check the status of backfill requests
-- 2. See if activities exist for the requested date ranges
-- 3. Manually mark requests as completed if activities have arrived
-- ============================================================================

-- STEP 1: Check all backfill requests for your user
-- ============================================================================
SELECT 
    br.id,
    br.user_id,
    br.status,
    TO_TIMESTAMP(br.summary_start_time_seconds) as start_date,
    TO_TIMESTAMP(br.summary_end_time_seconds) as end_date,
    br.created_at,
    br.completed_at,
    EXTRACT(EPOCH FROM (NOW() - br.created_at)) / 86400 as days_since_created,
    EXTRACT(EPOCH FROM (br.summary_end_time_seconds - br.summary_start_time_seconds)) / 86400 as date_range_days
FROM garmin_backfill_requests br
WHERE br.user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
ORDER BY br.created_at DESC;

-- STEP 2: Check if activities exist for each pending backfill request
-- ============================================================================
-- This shows pending requests and whether activities exist in those date ranges
WITH pending_requests AS (
    SELECT 
        br.id as backfill_id,
        br.summary_start_time_seconds,
        br.summary_end_time_seconds,
        br.created_at,
        TO_TIMESTAMP(br.summary_start_time_seconds) as start_date,
        TO_TIMESTAMP(br.summary_end_time_seconds) as end_date
    FROM garmin_backfill_requests br
    WHERE br.user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
      AND br.status = 'pending'
)
SELECT 
    pr.backfill_id,
    pr.start_date,
    pr.end_date,
    COUNT(ga.id) as activities_found,
    MIN(TO_TIMESTAMP(ga.start_time_seconds)) as earliest_activity,
    MAX(TO_TIMESTAMP(ga.start_time_seconds)) as latest_activity,
    EXTRACT(EPOCH FROM (NOW() - pr.created_at)) / 86400 as days_since_requested
FROM pending_requests pr
LEFT JOIN garmin_activities ga ON 
    ga.user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
    AND ga.start_time_seconds >= pr.summary_start_time_seconds
    AND ga.start_time_seconds <= pr.summary_end_time_seconds
GROUP BY pr.backfill_id, pr.start_date, pr.end_date, pr.created_at
ORDER BY pr.start_date;

-- STEP 3: Manually mark backfill requests as completed if activities exist
-- ============================================================================
-- This will mark pending requests as completed if activities exist in their date range
-- Uncomment and run this if you want to mark them as completed

/*
UPDATE garmin_backfill_requests br
SET 
    status = 'completed',
    completed_at = NOW()
WHERE br.user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
  AND br.status = 'pending'
  AND EXISTS (
      SELECT 1
      FROM garmin_activities ga
      WHERE ga.user_id = br.user_id
        AND ga.start_time_seconds >= br.summary_start_time_seconds
        AND ga.start_time_seconds <= br.summary_end_time_seconds
  );
*/

-- STEP 4: Mark old pending requests as completed (if you're sure Garmin processed them)
-- ============================================================================
-- This marks pending requests older than X days as completed
-- Use this if you're confident Garmin has processed them (even if no activities in range)
-- Uncomment and adjust the days threshold as needed

/*
UPDATE garmin_backfill_requests
SET 
    status = 'completed',
    completed_at = NOW()
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
  AND status = 'pending'
  AND created_at < NOW() - INTERVAL '7 days';  -- Adjust days as needed (e.g., 5, 7, 10)
*/

-- STEP 5: Check activities in the backfill date ranges
-- ============================================================================
-- This shows all activities that fall within pending backfill request date ranges
SELECT 
    br.id as backfill_id,
    TO_TIMESTAMP(br.summary_start_time_seconds) as backfill_start,
    TO_TIMESTAMP(br.summary_end_time_seconds) as backfill_end,
    ga.id as activity_id,
    ga.garmin_activity_id,
    ga.activity_type,
    TO_TIMESTAMP(ga.start_time_seconds) as activity_start,
    ga.distance_meters,
    ga.duration_seconds
FROM garmin_backfill_requests br
INNER JOIN garmin_activities ga ON 
    ga.user_id = br.user_id
    AND ga.start_time_seconds >= br.summary_start_time_seconds
    AND ga.start_time_seconds <= br.summary_end_time_seconds
WHERE br.user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
  AND br.status = 'pending'
ORDER BY br.created_at DESC, ga.start_time_seconds;

-- STEP 6: Summary - Get overview of all backfill requests and their status
-- ============================================================================
SELECT 
    br.status,
    COUNT(*) as count,
    MIN(br.created_at) as oldest_request,
    MAX(br.created_at) as newest_request,
    AVG(EXTRACT(EPOCH FROM (NOW() - br.created_at)) / 86400) as avg_days_old
FROM garmin_backfill_requests br
WHERE br.user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'  -- Replace with your user_id
GROUP BY br.status
ORDER BY br.status;

-- ============================================================================
-- RECOMMENDATIONS:
-- ============================================================================
-- 1. Run STEP 2 first to see if activities exist for pending requests
-- 2. If activities exist, run STEP 3 to mark them as completed
-- 3. If no activities exist but it's been >5 days, consider:
--    - The date range might not have had any activities
--    - Garmin might still be processing (webhooks delayed)
--    - Run STEP 4 to mark old requests as completed if you're sure
-- 4. Check STEP 5 to see which activities match which backfill requests
-- ============================================================================

