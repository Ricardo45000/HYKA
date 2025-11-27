-- ============================================================================
-- Clear Backfill Requests - Multiple Options
-- ============================================================================
-- This script provides different ways to remove backfill requests
-- Choose the option that fits your needs
--
-- ⚠️ IMPORTANT NOTES ABOUT GARMIN DUPLICATES:
-- 1. Garmin remembers backfill requests for a LONG TIME (weeks/months)
-- 2. Deleting from our database does NOT delete it from Garmin's servers
-- 3. If Garmin returns 409 (duplicate), it means they still remember the request
-- 4. The backfill function now allows retries after 30 days automatically
-- 5. If you get 409 even after deleting, Garmin still remembers it - wait 30+ days
-- 6. The function now treats 409 as "success" since Garmin is processing it
--
-- What to do if you get duplicates:
-- - Check the request age in the error message
-- - If < 30 days old: Wait or contact Garmin support
-- - If > 30 days old: The function will automatically allow retry
-- - Deleting from database helps track new requests but won't clear Garmin's memory
-- ============================================================================

-- OPTION 1: Delete a specific backfill request by ID
-- Replace 'YOUR_BACKFILL_REQUEST_ID' with the actual ID
/*
DELETE FROM garmin_backfill_requests
WHERE id = 'YOUR_BACKFILL_REQUEST_ID';
*/

-- OPTION 2: Delete all pending backfill requests for a specific user
-- Replace 'YOUR_USER_ID' with the actual user ID
/*
DELETE FROM garmin_backfill_requests
WHERE user_id = 'YOUR_USER_ID' 
  AND status = 'pending';
*/

-- OPTION 3: Delete all backfill requests for a specific user (any status)
-- Replace 'YOUR_USER_ID' with the actual user ID
/*
DELETE FROM garmin_backfill_requests
WHERE user_id = 'YOUR_USER_ID';
*/

-- OPTION 4: Delete all pending backfill requests (all users)
-- WARNING: This will delete pending requests for ALL users
/*
DELETE FROM garmin_backfill_requests
WHERE status = 'pending';
*/

-- OPTION 5: Delete old completed/failed backfill requests (cleanup)
-- This removes completed or failed requests older than 30 days
/*
DELETE FROM garmin_backfill_requests
WHERE status IN ('completed', 'failed')
  AND created_at < NOW() - INTERVAL '30 days';
*/

-- ============================================================================
-- STEP 1: First, check what backfill requests exist
-- ============================================================================
-- Run this to see all backfill requests for your user
SELECT 
    id,
    user_id,
    status,
    summary_start_time_seconds,
    summary_end_time_seconds,
    TO_TIMESTAMP(summary_start_time_seconds) as start_date,
    TO_TIMESTAMP(summary_end_time_seconds) as end_date,
    created_at,
    completed_at
FROM garmin_backfill_requests
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
ORDER BY created_at DESC;

-- ============================================================================
-- STEP 2: Delete all pending/completed backfill requests for your user
-- ============================================================================
-- This will allow you to retry the backfill request
-- IMPORTANT: This deletes ALL pending and completed requests for your user
DELETE FROM garmin_backfill_requests
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
  AND status IN ('pending', 'completed');

-- ============================================================================
-- Alternative: Delete ALL backfill requests for your user (any status)
-- ============================================================================
-- Uncomment this if you want to delete everything, including failed requests
/*
DELETE FROM garmin_backfill_requests
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c';
*/

-- ============================================================================
-- STEP 3: Verify deletion
-- ============================================================================
-- Run this to confirm all requests are deleted
SELECT 
    COUNT(*) as remaining_requests,
    status,
    COUNT(*) as count_by_status
FROM garmin_backfill_requests
WHERE user_id = 'fc600af9-2926-4b86-b841-25a25d17c10c'
GROUP BY status;

