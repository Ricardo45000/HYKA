-- ============================================================================
-- Garmin Official Integration - Database Schema
-- ============================================================================
-- 
-- Based on official Garmin Developer Program specifications:
-- - OAuth 2.0 PKCE authentication
-- - Webhook-based data sync (PING/PUSH modes)
-- - Official backfill endpoint for historical data
-- - FIT file processing for ultra-runner activities
--
-- Architecture:
-- 1. User connects Garmin → OAuth 2.0 → stores in garmin_connections
-- 2. Historical backfill → triggers webhooks → stores in garmin_activities
-- 3. New activities → webhooks → stores in garmin_activities + samples
-- 4. Ultra-runner activities → FIT files → parsed and stored
-- 5. iOS app reads from Supabase (never calls Garmin APIs directly)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Garmin Connections Table
-- ----------------------------------------------------------------------------
-- Stores OAuth 2.0 tokens and user mapping
-- Required for certification: permission_revoked flag

CREATE TABLE IF NOT EXISTS garmin_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_user_id TEXT NOT NULL, -- Garmin's userId (from /rest/user/id)
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    connected_at TIMESTAMPTZ DEFAULT NOW(), -- When user connected
    last_sync_at TIMESTAMPTZ, -- Last successful data sync
    permission_revoked BOOLEAN DEFAULT FALSE, -- Required for certification
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id), -- One Garmin connection per HYKA user
    UNIQUE(garmin_user_id) -- One HYKA user per Garmin account
);

CREATE INDEX IF NOT EXISTS idx_garmin_connections_user_id ON garmin_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_connections_garmin_user_id ON garmin_connections(garmin_user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked ON garmin_connections(permission_revoked);

COMMENT ON TABLE garmin_connections IS 'Stores Garmin OAuth 2.0 tokens and user mapping';
COMMENT ON COLUMN garmin_connections.garmin_user_id IS 'Garmin userId from /rest/user/id endpoint';
COMMENT ON COLUMN garmin_connections.permission_revoked IS 'Flag for certification: user removed permissions but did not disconnect';
COMMENT ON COLUMN garmin_connections.connected_at IS 'Timestamp when user first connected (for backfill calculation)';

-- ----------------------------------------------------------------------------
-- 2. Garmin Activities Table
-- ----------------------------------------------------------------------------
-- Stores activity summaries from Garmin Activity API
-- Data comes from webhooks (PING/PUSH) or backfill

CREATE TABLE IF NOT EXISTS garmin_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_activity_id TEXT NOT NULL, -- summaryId from Garmin
    activity_name TEXT,
    activity_type TEXT, -- "running", "hiking", "walking", etc.
    start_time TIMESTAMPTZ,
    start_time_seconds BIGINT NOT NULL, -- startTimeInSeconds from Garmin (for backfill)
    duration_seconds INT,
    distance_meters DOUBLE PRECISION,
    total_elevation_gain_meters DOUBLE PRECISION, -- Computed from samples
    total_elevation_loss_meters DOUBLE PRECISION, -- Computed from samples
    average_heart_rate INT,
    max_heart_rate INT,
    average_speed_mps DOUBLE PRECISION, -- meters per second
    max_speed_mps DOUBLE PRECISION,
    calories INT,
    steps INT,
    average_cadence INT, -- steps per minute
    max_cadence INT,
    device_name TEXT, -- Device that recorded the activity
    raw_summary JSONB, -- Full JSON summary from Garmin
    has_fit_file BOOLEAN DEFAULT FALSE, -- Whether FIT file is available
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, garmin_activity_id)
);

CREATE INDEX IF NOT EXISTS idx_garmin_activities_user_id ON garmin_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_start_time ON garmin_activities(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_start_time_seconds ON garmin_activities(start_time_seconds DESC);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_activity_type ON garmin_activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_garmin_id ON garmin_activities(garmin_activity_id);

COMMENT ON TABLE garmin_activities IS 'Activity summaries from Garmin Activity API (via webhooks or backfill)';
COMMENT ON COLUMN garmin_activities.start_time_seconds IS 'Unix timestamp from Garmin (for backfill queries)';
COMMENT ON COLUMN garmin_activities.total_elevation_gain_meters IS 'Computed from samples (for ultra-runner accuracy)';
COMMENT ON COLUMN garmin_activities.has_fit_file IS 'True if FIT file is available for this activity';

-- ----------------------------------------------------------------------------
-- 3. Garmin Activity Samples Table
-- ----------------------------------------------------------------------------
-- Stores per-second data from Garmin Activity Details API or FIT files
-- For ultra-runners: FIT files provide complete data when JSON is truncated

CREATE TABLE IF NOT EXISTS garmin_activity_samples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES garmin_activities(id) ON DELETE CASCADE,
    timestamp_seconds BIGINT NOT NULL, -- startTimeInSeconds from Garmin
    sample_time TIMESTAMPTZ, -- Derived from timestamp_seconds
    latitude DOUBLE PRECISION, -- latitudeInDegree
    longitude DOUBLE PRECISION, -- longitudeInDegree
    elevation_meters DOUBLE PRECISION, -- elevationInMeters
    heart_rate INT, -- heartRate (BPM)
    speed_mps DOUBLE PRECISION, -- speedMetersPerSecond
    steps_per_minute INT, -- stepsPerMinute (cadence)
    air_temperature_celsius DOUBLE PRECISION, -- airTemperatureCelcius [sic]
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(activity_id, timestamp_seconds) -- Prevent duplicate samples
);

CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_activity_id ON garmin_activity_samples(activity_id);
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_timestamp ON garmin_activity_samples(timestamp_seconds);
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_time ON garmin_activity_samples(sample_time);

COMMENT ON TABLE garmin_activity_samples IS 'Per-second GPS/HR/cadence data from Garmin Activity Details API or FIT files';
COMMENT ON COLUMN garmin_activity_samples.timestamp_seconds IS 'Unix timestamp from Garmin startTimeInSeconds';

-- ----------------------------------------------------------------------------
-- 4. Garmin FIT Files Table
-- ----------------------------------------------------------------------------
-- Stores raw FIT files for ultra-runner activities (>24 hours)
-- FIT files contain complete data when JSON payloads are truncated

CREATE TABLE IF NOT EXISTS garmin_fit_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id UUID NOT NULL REFERENCES garmin_activities(id) ON DELETE CASCADE,
    file_data BYTEA NOT NULL, -- Raw FIT file binary data
    file_size BIGINT NOT NULL, -- Size in bytes
    device_name TEXT, -- Device that recorded the activity
    file_version TEXT, -- FIT file format version
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(activity_id) -- One FIT file per activity
);

CREATE INDEX IF NOT EXISTS idx_garmin_fit_files_activity_id ON garmin_fit_files(activity_id);

COMMENT ON TABLE garmin_fit_files IS 'Raw FIT files for ultra-runner activities (activities >24 hours)';
COMMENT ON COLUMN garmin_fit_files.file_data IS 'Binary FIT file data (can be large for ultra-runs)';

-- ----------------------------------------------------------------------------
-- 5. Garmin Health Metrics Table
-- ----------------------------------------------------------------------------
-- Stores health data from Garmin (Fitness Age, VO2 Max, etc.)
-- Data comes from User Metrics and Health Snapshot webhooks

CREATE TABLE IF NOT EXISTS garmin_health_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_user_id TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL, -- When the metric was recorded
    fitness_age INT, -- Fitness Age in years
    vo2_max DOUBLE PRECISION, -- VO2 Max value
    raw_data JSONB, -- Full JSON from Garmin for other metrics
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, timestamp) -- One metric per user per timestamp
);

CREATE INDEX IF NOT EXISTS idx_garmin_health_metrics_user_id ON garmin_health_metrics(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_health_metrics_timestamp ON garmin_health_metrics(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_garmin_health_metrics_garmin_user_id ON garmin_health_metrics(garmin_user_id);

COMMENT ON TABLE garmin_health_metrics IS 'Health metrics from Garmin (Fitness Age, VO2 Max, etc.)';
COMMENT ON COLUMN garmin_health_metrics.fitness_age IS 'Fitness Age in years (calculated by Garmin)';
COMMENT ON COLUMN garmin_health_metrics.vo2_max IS 'VO2 Max value (ml/kg/min)';

-- ----------------------------------------------------------------------------
-- 6. Backfill Requests Table (for deduplication)
-- ----------------------------------------------------------------------------
-- Tracks backfill requests to prevent duplicates (HTTP 409)
-- Garmin rejects duplicate backfill requests for the same time period

CREATE TABLE IF NOT EXISTS garmin_backfill_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    summary_start_time_seconds BIGINT NOT NULL,
    summary_end_time_seconds BIGINT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, completed, failed
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    UNIQUE(user_id, summary_start_time_seconds, summary_end_time_seconds)
);

CREATE INDEX IF NOT EXISTS idx_garmin_backfill_requests_user_id ON garmin_backfill_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_backfill_requests_status ON garmin_backfill_requests(status);

COMMENT ON TABLE garmin_backfill_requests IS 'Tracks backfill requests to prevent duplicates (Garmin returns 409 for duplicates)';

-- ----------------------------------------------------------------------------
-- 7. Views for iOS App
-- ----------------------------------------------------------------------------
-- Unified view that combines garmin_activities with other providers

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

COMMENT ON VIEW unified_activities IS 'Combines activities from all providers for iOS app consumption';

-- ----------------------------------------------------------------------------
-- 8. RPC Functions for iOS App
-- ----------------------------------------------------------------------------

-- Fetch activities for a user (iOS app calls this)
CREATE OR REPLACE FUNCTION get_user_activities(
    p_user_id UUID,
    p_limit INT DEFAULT 50,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    provider TEXT,
    activity_name TEXT,
    activity_type TEXT,
    start_time TIMESTAMPTZ,
    duration_seconds INT,
    distance_meters DOUBLE PRECISION,
    elevation_gain_meters DOUBLE PRECISION,
    average_heart_rate INT,
    max_heart_rate INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ua.id,
        ua.provider,
        ua.name AS activity_name,
        ua.activity_type,
        ua.start_time,
        ua.duration_seconds::INT,
        ua.distance_meters,
        ua.elevation_gain_meters,
        ua.average_heart_rate,
        ua.max_heart_rate
    FROM unified_activities ua
    WHERE ua.user_id = p_user_id
    ORDER BY ua.start_time DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Fetch activity samples (GPS/HR data) for a specific activity
CREATE OR REPLACE FUNCTION get_activity_samples(p_activity_id UUID)
RETURNS TABLE (
    timestamp_seconds BIGINT,
    sample_time TIMESTAMPTZ,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    elevation_meters DOUBLE PRECISION,
    heart_rate INT,
    speed_mps DOUBLE PRECISION,
    steps_per_minute INT
) AS $$
BEGIN
    -- Try garmin_activity_samples first
    IF EXISTS (SELECT 1 FROM garmin_activities WHERE id = p_activity_id) THEN
        RETURN QUERY
        SELECT 
            gas.timestamp_seconds,
            gas.sample_time,
            gas.latitude,
            gas.longitude,
            gas.elevation_meters,
            gas.heart_rate,
            gas.speed_mps,
            gas.steps_per_minute
        FROM garmin_activity_samples gas
        WHERE gas.activity_id = p_activity_id
        ORDER BY gas.timestamp_seconds;
    ELSE
        -- Fallback to samples table for other providers
        RETURN QUERY
        SELECT 
            s.t_s::BIGINT AS timestamp_seconds,
            NULL::TIMESTAMPTZ AS sample_time,
            s.lat AS latitude,
            s.lon AS longitude,
            s.alt_m AS elevation_meters,
            s.hr AS heart_rate,
            s.speed_m_per_s AS speed_mps,
            s.steps_per_minute
        FROM samples s
        WHERE s.workout_id = p_activity_id
        ORDER BY s.t_s;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Get latest health metrics for a user (Fitness Age, VO2 Max)
CREATE OR REPLACE FUNCTION get_latest_health_metrics(p_user_id UUID)
RETURNS TABLE (
    fitness_age INT,
    vo2_max DOUBLE PRECISION,
    metric_timestamp TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ghm.fitness_age,
        ghm.vo2_max,
        ghm.timestamp AS metric_timestamp
    FROM garmin_health_metrics ghm
    WHERE ghm.user_id = p_user_id
    ORDER BY ghm.timestamp DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 9. Row Level Security (RLS)
-- ----------------------------------------------------------------------------

ALTER TABLE garmin_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_activity_samples ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_fit_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_health_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_backfill_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to allow re-running this script)
DROP POLICY IF EXISTS "Users can view own garmin connections" ON garmin_connections;
DROP POLICY IF EXISTS "Users can view own garmin activities" ON garmin_activities;
DROP POLICY IF EXISTS "Users can view own garmin activity samples" ON garmin_activity_samples;
DROP POLICY IF EXISTS "Users can view own garmin fit files" ON garmin_fit_files;
DROP POLICY IF EXISTS "Service role full access to garmin_connections" ON garmin_connections;
DROP POLICY IF EXISTS "Service role full access to garmin_activities" ON garmin_activities;
DROP POLICY IF EXISTS "Service role full access to garmin_activity_samples" ON garmin_activity_samples;
DROP POLICY IF EXISTS "Service role full access to garmin_fit_files" ON garmin_fit_files;
DROP POLICY IF EXISTS "Service role full access to garmin_backfill_requests" ON garmin_backfill_requests;

-- Users can only see their own Garmin connections
CREATE POLICY "Users can view own garmin connections"
    ON garmin_connections FOR SELECT
    USING (auth.uid() = user_id);

-- Users can only see their own activities
CREATE POLICY "Users can view own garmin activities"
    ON garmin_activities FOR SELECT
    USING (auth.uid() = user_id);

-- Users can only see samples for their own activities
CREATE POLICY "Users can view own garmin activity samples"
    ON garmin_activity_samples FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM garmin_activities ga
            WHERE ga.id = garmin_activity_samples.activity_id
            AND ga.user_id = auth.uid()
        )
    );

-- Users can only see FIT files for their own activities
CREATE POLICY "Users can view own garmin fit files"
    ON garmin_fit_files FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM garmin_activities ga
            WHERE ga.id = garmin_fit_files.activity_id
            AND ga.user_id = auth.uid()
        )
    );

-- Service role can do everything (for Edge Functions)
CREATE POLICY "Service role full access to garmin_connections"
    ON garmin_connections FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access to garmin_activities"
    ON garmin_activities FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access to garmin_activity_samples"
    ON garmin_activity_samples FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access to garmin_fit_files"
    ON garmin_fit_files FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- Users can only see their own health metrics
CREATE POLICY "Users can view own garmin health metrics"
    ON garmin_health_metrics FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role full access to garmin_health_metrics"
    ON garmin_health_metrics FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service role full access to garmin_backfill_requests"
    ON garmin_backfill_requests FOR ALL
    USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- Summary
-- ============================================================================
-- 
-- Tables created:
-- 1. garmin_connections - OAuth 2.0 tokens and user mapping
-- 2. garmin_activities - Activity summaries
-- 3. garmin_activity_samples - Per-second GPS/HR data
-- 4. garmin_fit_files - Raw FIT files for ultra-runners
-- 5. garmin_health_metrics - Health metrics (Fitness Age, VO2 Max, etc.)
-- 6. garmin_backfill_requests - Backfill request tracking (deduplication)
--
-- Views created:
-- 1. unified_activities - Combines Garmin + other providers
--
-- RPC functions created:
-- 1. get_user_activities(user_id, limit, offset) - For iOS app
-- 2. get_activity_samples(activity_id) - For iOS app
-- 3. get_latest_health_metrics(user_id) - For iOS app (Fitness Age, VO2 Max)
--
-- Next steps:
-- 1. Deploy Edge Functions (see implementation files)
-- 2. Configure webhooks in Garmin Developer Portal
-- 3. Test OAuth 2.0 flow
-- 4. Test backfill endpoint
-- ============================================================================

