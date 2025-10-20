-- ============================================================================
-- Garmin Hourly Sync - Cron Job Setup
-- ============================================================================
--
-- Purpose: Backup mechanism to pull Garmin data every hour
--
-- Why needed:
-- - Garmin webhooks are the primary mechanism
-- - Webhooks can fail or be delayed
-- - Hourly sync ensures data is never more than 1 hour stale
-- - Catches any missed webhook notifications
--
-- How it works:
-- 1. Cron job runs every hour
-- 2. Loops through all garmin_connections
-- 3. Fetches activities from last 24 hours (webhooks should handle most)
-- 4. Incremental approach - only new activities are added
--
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Enable pg_cron extension
-- ----------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Verify extension is enabled
SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- ----------------------------------------------------------------------------
-- 2. Create Edge Function: garmin-hourly-sync
-- ----------------------------------------------------------------------------

-- This Edge Function will be created separately
-- It loops through all garmin_connections and calls garmin-activity-fetch

-- ----------------------------------------------------------------------------
-- 3. Schedule hourly cron job
-- ----------------------------------------------------------------------------

-- Run every hour at minute 0
-- Example: 00:00, 01:00, 02:00, etc.

SELECT cron.schedule(
    'garmin-hourly-sync',           -- Job name
    '0 * * * *',                    -- Cron expression: every hour at minute 0
    $$
    SELECT net.http_post(
        url := 'https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-hourly-sync',
        headers := jsonb_build_object(
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2Zmh0aWxqa3liYnJieG95cXNxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDc2NjI1OCwiZXhwIjoyMDc2MzQyMjU4fQ.jP0v7Xp6q_YPY2mdC0kiFfQM6xHWGZ2ty9fk7zmOcXs',
            'Content-Type', 'application/json'
        ),
        body := '{}'::jsonb
    );
    $$
);

-- ----------------------------------------------------------------------------
-- 4. Verify cron job is scheduled
-- ----------------------------------------------------------------------------

SELECT * FROM cron.job WHERE jobname = 'garmin-hourly-sync';

-- Expected output:
-- jobid | schedule   | command                 | nodename | nodeport | database | username | active
-- ------+------------+------------------------+----------+----------+----------+----------+--------
-- 123   | 0 * * * *  | SELECT net.http_post... | ...      | ...      | ...      | ...      | t

-- ----------------------------------------------------------------------------
-- 5. View cron job execution history
-- ----------------------------------------------------------------------------

-- Check recent executions
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'garmin-hourly-sync')
ORDER BY start_time DESC 
LIMIT 10;

-- Check for errors
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'garmin-hourly-sync')
  AND status = 'failed'
ORDER BY start_time DESC 
LIMIT 10;

-- ----------------------------------------------------------------------------
-- 6. Unschedule cron job (if needed)
-- ----------------------------------------------------------------------------

-- Use this to stop/remove the cron job
-- SELECT cron.unschedule('garmin-hourly-sync');

-- ----------------------------------------------------------------------------
-- 7. Alternative schedules
-- ----------------------------------------------------------------------------

-- Every 30 minutes:
-- '*/30 * * * *'

-- Every 2 hours:
-- '0 */2 * * *'

-- Every 6 hours at minute 0:
-- '0 */6 * * *'

-- Daily at 2 AM:
-- '0 2 * * *'

-- ============================================================================
-- Monitoring and Maintenance
-- ============================================================================

-- Create a view to monitor sync health
CREATE OR REPLACE VIEW garmin_sync_health AS
SELECT 
    gc.user_id,
    gc.garmin_user_id,
    gc.last_sync_at,
    EXTRACT(EPOCH FROM (NOW() - gc.last_sync_at)) / 3600 AS hours_since_sync,
    COUNT(ga.id) AS total_activities,
    MAX(ga.start_time) AS latest_activity_time,
    CASE 
        WHEN gc.last_sync_at IS NULL THEN 'Never synced'
        WHEN EXTRACT(EPOCH FROM (NOW() - gc.last_sync_at)) / 3600 < 2 THEN 'Healthy'
        WHEN EXTRACT(EPOCH FROM (NOW() - gc.last_sync_at)) / 3600 < 24 THEN 'Warning'
        ELSE 'Stale'
    END AS sync_status
FROM garmin_connections gc
LEFT JOIN garmin_activities ga ON ga.user_id = gc.user_id
GROUP BY gc.user_id, gc.garmin_user_id, gc.last_sync_at;

-- Check sync health
SELECT * FROM garmin_sync_health ORDER BY hours_since_sync DESC;

-- Count users needing sync
SELECT 
    sync_status,
    COUNT(*) as user_count
FROM garmin_sync_health
GROUP BY sync_status;

-- ============================================================================
-- Troubleshooting
-- ============================================================================

-- Problem: Cron job not running
-- Solution: Check if pg_cron extension is enabled
--   SELECT * FROM pg_extension WHERE extname = 'pg_cron';

-- Problem: Cron job runs but Edge Function fails
-- Solution: Check Edge Function logs in Supabase Dashboard

-- Problem: Pull Token expired
-- Solution: Update Pull Token daily from Garmin Developer Portal
--   SELECT update_garmin_pull_token('NEW_TOKEN_HERE');

-- Problem: All syncs failing with 401 Unauthorized
-- Solution: Access tokens may have expired. Users need to reconnect Garmin.

-- ============================================================================
-- Summary
-- ============================================================================
--
-- 1. ✅ Enable pg_cron extension
-- 2. ✅ Create garmin-hourly-sync Edge Function
-- 3. ✅ Schedule cron job (replace service role key!)
-- 4. ✅ Monitor sync health using garmin_sync_health view
-- 5. ✅ Update Pull Token daily
--
-- The hourly sync is a BACKUP mechanism:
-- - Primary: Garmin webhooks (real-time)
-- - Backup: Hourly cron job (catches missed webhooks)
--
-- Users don't need to do anything - data flows automatically!
-- ============================================================================

