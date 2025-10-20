-- ============================================================================
-- Complete Schema Migration: Update Existing Tables to Official Schema
-- ============================================================================
-- 
-- This migration updates existing Garmin tables to match the official schema.
-- Run this BEFORE running garmin_official_schema.sql to avoid errors.
--
-- Fixes:
-- - garmin_connections: Adds connected_at, permission_revoked
-- - garmin_activities: Updates column names, adds missing columns
-- ============================================================================

-- ============================================================================
-- 1. Update garmin_connections Table
-- ============================================================================

-- Add connected_at column
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS connected_at TIMESTAMPTZ;

-- Add permission_revoked column
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- Set default values for existing rows
UPDATE garmin_connections 
SET connected_at = COALESCE(connected_at, created_at, NOW())
WHERE connected_at IS NULL;

UPDATE garmin_connections 
SET permission_revoked = FALSE 
WHERE permission_revoked IS NULL;

-- Add index
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked 
ON garmin_connections(permission_revoked);

-- Add comments
COMMENT ON COLUMN garmin_connections.connected_at IS 
'Timestamp when user first connected (for backfill calculation)';

COMMENT ON COLUMN garmin_connections.permission_revoked IS 
'Flag for certification: user removed permissions but did not disconnect';

-- ============================================================================
-- 2. Update garmin_activities Table
-- ============================================================================

-- Add start_time_seconds column (if missing)
ALTER TABLE garmin_activities 
ADD COLUMN IF NOT EXISTS start_time_seconds BIGINT;

-- Add total_elevation_loss_meters column (if missing)
ALTER TABLE garmin_activities 
ADD COLUMN IF NOT EXISTS total_elevation_loss_meters DOUBLE PRECISION;

-- Add device_name column (if missing)
ALTER TABLE garmin_activities 
ADD COLUMN IF NOT EXISTS device_name TEXT;

-- Add has_fit_file column (if missing)
ALTER TABLE garmin_activities 
ADD COLUMN IF NOT EXISTS has_fit_file BOOLEAN DEFAULT FALSE;

-- Rename raw_data to raw_summary (if raw_data exists and raw_summary doesn't)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'garmin_activities' 
        AND column_name = 'raw_data'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'garmin_activities' 
        AND column_name = 'raw_summary'
    ) THEN
        ALTER TABLE garmin_activities 
        RENAME COLUMN raw_data TO raw_summary;
        
        RAISE NOTICE 'Renamed raw_data to raw_summary';
    END IF;
END $$;

-- Add raw_summary column if neither exists
ALTER TABLE garmin_activities 
ADD COLUMN IF NOT EXISTS raw_summary JSONB;

-- Populate start_time_seconds from start_time if missing
UPDATE garmin_activities 
SET start_time_seconds = EXTRACT(EPOCH FROM start_time)::BIGINT
WHERE start_time_seconds IS NULL AND start_time IS NOT NULL;

-- Add index for start_time_seconds
CREATE INDEX IF NOT EXISTS idx_garmin_activities_start_time_seconds 
ON garmin_activities(start_time_seconds DESC);

-- Add comments
COMMENT ON COLUMN garmin_activities.start_time_seconds IS 
'Unix timestamp from Garmin (for backfill queries)';

COMMENT ON COLUMN garmin_activities.total_elevation_gain_meters IS 
'Computed from samples (for ultra-runner accuracy)';

COMMENT ON COLUMN garmin_activities.has_fit_file IS 
'True if FIT file is available for this activity';

-- ============================================================================
-- 3. Update garmin_activity_samples Table
-- ============================================================================

-- Add sample_time column (if missing)
ALTER TABLE garmin_activity_samples 
ADD COLUMN IF NOT EXISTS sample_time TIMESTAMPTZ;

-- Add air_temperature_celsius column (if missing - note: old schema might have air_temperature_c)
ALTER TABLE garmin_activity_samples 
ADD COLUMN IF NOT EXISTS air_temperature_celsius DOUBLE PRECISION;

-- Rename air_temperature_c to air_temperature_celsius if needed
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'garmin_activity_samples' 
        AND column_name = 'air_temperature_c'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'garmin_activity_samples' 
        AND column_name = 'air_temperature_celsius'
    ) THEN
        ALTER TABLE garmin_activity_samples 
        RENAME COLUMN air_temperature_c TO air_temperature_celsius;
        
        RAISE NOTICE 'Renamed air_temperature_c to air_temperature_celsius';
    END IF;
END $$;

-- Populate sample_time from timestamp_seconds if missing
UPDATE garmin_activity_samples 
SET sample_time = TO_TIMESTAMP(timestamp_seconds)
WHERE sample_time IS NULL AND timestamp_seconds IS NOT NULL;

-- Add index for sample_time
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_time 
ON garmin_activity_samples(sample_time);

-- ============================================================================
-- 4. Create Missing Tables (if they don't exist)
-- ============================================================================

-- Create garmin_fit_files table
CREATE TABLE IF NOT EXISTS garmin_fit_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES garmin_activities(id) ON DELETE CASCADE,
    file_data BYTEA NOT NULL,
    file_size BIGINT NOT NULL,
    device_name TEXT,
    file_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(activity_id)
);

CREATE INDEX IF NOT EXISTS idx_garmin_fit_files_activity_id 
ON garmin_fit_files(activity_id);

-- Create garmin_backfill_requests table
CREATE TABLE IF NOT EXISTS garmin_backfill_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    summary_start_time_seconds BIGINT NOT NULL,
    summary_end_time_seconds BIGINT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(user_id, summary_start_time_seconds, summary_end_time_seconds)
);

CREATE INDEX IF NOT EXISTS idx_garmin_backfill_requests_user_id 
ON garmin_backfill_requests(user_id);

CREATE INDEX IF NOT EXISTS idx_garmin_backfill_requests_status 
ON garmin_backfill_requests(status);

-- ============================================================================
-- 5. Verify Migration
-- ============================================================================

DO $$
DECLARE
    connections_count INTEGER;
    activities_count INTEGER;
    samples_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO connections_count FROM garmin_connections;
    SELECT COUNT(*) INTO activities_count FROM garmin_activities;
    SELECT COUNT(*) INTO samples_count FROM garmin_activity_samples;
    
    RAISE NOTICE '✅ Migration complete!';
    RAISE NOTICE '   garmin_connections: % rows', connections_count;
    RAISE NOTICE '   garmin_activities: % rows', activities_count;
    RAISE NOTICE '   garmin_activity_samples: % rows', samples_count;
END $$;

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- 
-- All tables are now updated to match the official schema.
-- You can now run garmin_official_schema.sql without errors.
-- 
-- Note: The official schema uses CREATE TABLE IF NOT EXISTS, so it will
-- skip creating tables that already exist, but it will create views,
-- functions, and RLS policies.
-- ============================================================================

