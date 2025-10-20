-- Step 1: Enable pg_cron extension
-- Run this first in Supabase SQL Editor
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Step 2: Schedule the Garmin sync job
-- This will run every 6 hours (at 00:00, 06:00, 12:00, 18:00 UTC)
SELECT cron.schedule(
  'sync-garmin-activities',
  '0 */6 * * *', -- Every 6 hours
  $$
  SELECT
    net.http_post(
      url := 'https://gvfhtiljkybbrbxoyqsq.supabase.co/functions/v1/garmin-sync-all-users',
      headers := '{"Content-Type": "application/json"}'::jsonb
    ) AS request_id;
  $$
);

-- Step 3: Verify the cron job was created
SELECT * FROM cron.job WHERE jobname = 'sync-garmin-activities';

-- Optional: To unschedule the job later
-- SELECT cron.unschedule('sync-garmin-activities');

-- Optional: To see all scheduled jobs
-- SELECT * FROM cron.job;

