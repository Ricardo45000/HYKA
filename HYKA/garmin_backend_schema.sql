-- ============================================================================
-- Garmin Backend Architecture - Database Schema
-- ============================================================================
-- 
-- This schema supports the official Garmin Developer Program approach:
-- - OAuth 2.0 authentication in iOS app
-- - Webhook-based data sync via Supabase Edge Functions
-- - Server-side data fetching with Pull Token
--
-- Architecture:
-- 1. User connects Garmin → stores in garmin_connections
-- 2. Garmin sends webhooks → stores in garmin_activities + garmin_activity_samples
-- 3. iOS app reads from garmin_activities (never calls Garmin APIs)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. App Config Table (for Pull Token storage)
-- ----------------------------------------------------------------------------
-- Stores the Pull Token which expires every 24 hours
-- Must be updated daily from Garmin Developer Portal

CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Insert initial Pull Token (update this with your current token)
INSERT INTO app_config (key, value, description)
VALUES (
    'garmin_pull_token',
    'CPT1763250098.9HZ__7xckH4',  -- REPLACE WITH YOUR CURRENT PULL TOKEN
    'Garmin Wellness API Pull Token - expires every 24 hours. Update daily from Garmin Developer Portal.'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = NOW();

-- Function to update Pull Token
CREATE OR REPLACE FUNCTION update_garmin_pull_token(new_token TEXT)
RETURNS void AS $$
BEGIN
    INSERT INTO app_config (key, value, description, updated_at)
    VALUES (
        'garmin_pull_token',
        new_token,
        'Garmin Wellness API Pull Token - expires every 24 hours. Update daily from Garmin Developer Portal.',
        NOW()
    )
    ON CONFLICT (key) DO UPDATE
    SET value = EXCLUDED.value,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 2. Garmin Connections Table
-- ----------------------------------------------------------------------------
-- Stores OAuth 2.0 tokens and Garmin user mapping
-- One connection per HYKA user (replaces oauth_connections for Garmin)

CREATE TABLE IF NOT EXISTS garmin_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_user_id TEXT NOT NULL, -- Garmin's userId (from /rest/user/id)
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    last_sync_at TIMESTAMPTZ, -- Last time we fetched data from Garmin
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id), -- One Garmin connection per HYKA user
    UNIQUE(garmin_user_id) -- One HYKA user per Garmin account
);

CREATE INDEX IF NOT EXISTS idx_garmin_connections_user_id ON garmin_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_connections_garmin_user_id ON garmin_connections(garmin_user_id);

COMMENT ON TABLE garmin_connections IS 'Stores Garmin OAuth 2.0 tokens and user mapping';
COMMENT ON COLUMN garmin_connections.garmin_user_id IS 'Garmin userId from /rest/user/id endpoint';
COMMENT ON COLUMN garmin_connections.last_sync_at IS 'Last successful data sync from Garmin webhooks';

-- ----------------------------------------------------------------------------
-- 3. Garmin Activities Table
-- ----------------------------------------------------------------------------
-- Stores activity summaries from Garmin Wellness API
-- Data comes from Edge Functions via webhooks (not from iOS app)

CREATE TABLE IF NOT EXISTS garmin_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_activity_id TEXT NOT NULL, -- activityId or summaryId from Garmin
    activity_name TEXT,
    activity_type TEXT, -- "running", "hiking", "walking", etc.
    start_time TIMESTAMPTZ,
    start_time_seconds BIGINT, -- startTimeInSeconds from Garmin
    duration_seconds INT,
    distance_meters DOUBLE PRECISION,
    total_elevation_gain_meters DOUBLE PRECISION, -- From Garmin's totalElevationGainInMeters
    total_elevation_loss_meters DOUBLE PRECISION,
    average_heart_rate INT,
    max_heart_rate INT,
    average_speed_mps DOUBLE PRECISION, -- meters per second
    max_speed_mps DOUBLE PRECISION,
    calories INT,
    steps INT,
    average_cadence INT, -- steps per minute
    max_cadence INT,
    raw_data JSONB, -- Full JSON from Garmin for debugging
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, garmin_activity_id)
);

CREATE INDEX IF NOT EXISTS idx_garmin_activities_user_id ON garmin_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_start_time ON garmin_activities(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_activity_type ON garmin_activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_garmin_activities_garmin_id ON garmin_activities(garmin_activity_id);

COMMENT ON TABLE garmin_activities IS 'Activity summaries from Garmin Wellness API (fetched server-side)';
COMMENT ON COLUMN garmin_activities.start_time_seconds IS 'Unix timestamp from Garmin (for sample correlation)';
COMMENT ON COLUMN garmin_activities.total_elevation_gain_meters IS 'Cumulative elevation gain from Garmin';

-- ----------------------------------------------------------------------------
-- 4. Garmin Activity Samples Table
-- ----------------------------------------------------------------------------
-- Stores per-second data from Garmin /rest/activityDetails endpoint
-- Data comes from Edge Functions (not from iOS app)

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
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_activity_id ON garmin_activity_samples(activity_id);
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_timestamp ON garmin_activity_samples(timestamp_seconds);
CREATE INDEX IF NOT EXISTS idx_garmin_activity_samples_time ON garmin_activity_samples(sample_time);

COMMENT ON TABLE garmin_activity_samples IS 'Per-second GPS/HR/cadence data from Garmin Wellness API';
COMMENT ON COLUMN garmin_activity_samples.timestamp_seconds IS 'Unix timestamp from Garmin startTimeInSeconds';

-- ----------------------------------------------------------------------------
-- 5. Update oauth_connections for Garmin
-- ----------------------------------------------------------------------------
-- Modify existing oauth_connections to store garmin_user_id
-- This allows lookup by garmin_user_id when webhooks arrive

ALTER TABLE oauth_connections 
ADD COLUMN IF NOT EXISTS garmin_user_id TEXT;

CREATE INDEX IF NOT EXISTS idx_oauth_connections_garmin_user_id 
ON oauth_connections(garmin_user_id) 
WHERE provider = 'garmin';

COMMENT ON COLUMN oauth_connections.garmin_user_id IS 'Garmin userId for webhook lookup (Garmin only)';

-- ----------------------------------------------------------------------------
-- 6. Migration Function: Copy existing Garmin connections
-- ----------------------------------------------------------------------------
-- Migrates existing oauth_connections to garmin_connections table

CREATE OR REPLACE FUNCTION migrate_garmin_connections()
RETURNS void AS $$
BEGIN
    INSERT INTO garmin_connections (
        user_id,
        garmin_user_id,
        access_token,
        refresh_token,
        token_expires_at,
        created_at,
        updated_at
    )
    SELECT 
        user_id,
        COALESCE(garmin_user_id, 'unknown'), -- Placeholder for existing connections
        access_token,
        refresh_token,
        expires_at,
        created_at,
        updated_at
    FROM oauth_connections
    WHERE provider = 'garmin'
    ON CONFLICT (user_id) DO NOTHING;
    
    RAISE NOTICE 'Migrated % Garmin connections', (SELECT COUNT(*) FROM oauth_connections WHERE provider = 'garmin');
END;
$$ LANGUAGE plpgsql;

-- Run migration (comment out after first run)
-- SELECT migrate_garmin_connections();

-- ----------------------------------------------------------------------------
-- 7. Views for iOS App
-- ----------------------------------------------------------------------------
-- Unified view that combines garmin_activities with the existing workouts table
-- iOS app can query this view to get all activities across providers

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

-- ----------------------------------------------------------------------------
-- 9. Row Level Security (RLS)
-- ----------------------------------------------------------------------------

ALTER TABLE garmin_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE garmin_activity_samples ENABLE ROW LEVEL SECURITY;

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

-- ----------------------------------------------------------------------------
-- 10. Cleanup (OPTIONAL - only run if migrating from old schema)
-- ----------------------------------------------------------------------------

-- After confirming garmin_connections works, optionally remove Garmin entries from oauth_connections
-- UNCOMMENT ONLY AFTER SUCCESSFUL MIGRATION AND TESTING

-- DELETE FROM oauth_connections WHERE provider = 'garmin';

-- ----------------------------------------------------------------------------
-- Summary
-- ----------------------------------------------------------------------------
-- 
-- Tables created:
-- 1. app_config - stores Pull Token (updated daily)
-- 2. garmin_connections - stores OAuth tokens per user
-- 3. garmin_activities - stores activity summaries
-- 4. garmin_activity_samples - stores per-second GPS/HR data
--
-- Views created:
-- 1. unified_activities - combines Garmin + other providers
--
-- RPC functions created:
-- 1. get_user_activities(user_id, limit, offset) - for iOS app
-- 2. get_activity_samples(activity_id) - for iOS app
--
-- Next steps:
-- 1. Update Pull Token in app_config daily
-- 2. Deploy Edge Functions (garmin-activity-ping, garmin-activity-push, garmin-activity-fetch)
-- 3. Configure Garmin webhooks in Developer Portal
-- 4. Set up hourly cron job for backup sync
-- ============================================================================

