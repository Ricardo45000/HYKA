-- ============================================================================
-- Check Existing Backfill Requests
-- ============================================================================
-- Run this first to see what backfill requests exist in the database
-- This helps identify which requests need to be deleted
-- ============================================================================

-- View all backfill requests for a specific user
SELECT 
    id,
    user_id,
    status,
    summary_start_time_seconds,
    summary_end_time_seconds,
    TO_TIMESTAMP(summary_start_time_seconds) as start_date,
    TO_TIMESTAMP(summary_end_time_seconds) as end_date,
    EXTRACT(EPOCH FROM (TO_TIMESTAMP(summary_end_time_seconds) - TO_TIMESTAMP(summary_start_time_seconds))) / 86400 as days_span,
    created_at,
    completed_at,
    CASE 
        WHEN status = 'pending' THEN '⚠️ Still processing'
        WHEN status = 'completed' THEN '✅ Completed'
        WHEN status = 'failed' THEN '❌ Failed'
        ELSE status
    END as status_display
FROM garmin_backfill_requests
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
ORDER BY created_at DESC;

-- Summary by status
SELECT 
    status,
    COUNT(*) as count,
    MIN(created_at) as oldest_request,
    MAX(created_at) as newest_request
FROM garmin_backfill_requests
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
GROUP BY status
ORDER BY status;





