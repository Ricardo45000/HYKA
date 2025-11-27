-- ============================================================================
-- Strava Integration - Database Schema
-- ============================================================================
-- 
-- Based on Strava API v3 specifications:
-- - OAuth 2.0 authentication
-- - Webhook-based data sync for activity completion
-- - Activity data storage for running activities
--
-- Architecture:
-- 1. User connects Strava → OAuth 2.0 → stores in strava_connections
-- 2. Activity completed → webhook → stores in strava_activities
-- 3. Activity details → fetched and stored in strava_activity_samples
-- 4. Push notification sent to iOS app
-- 5. iOS app reads from Supabase (never calls Strava APIs directly)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Strava Connections Table
-- ----------------------------------------------------------------------------
-- Stores OAuth 2.0 tokens and user mapping

CREATE TABLE IF NOT EXISTS strava_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    strava_athlete_id BIGINT NOT NULL, -- Strava's athlete ID
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    connected_at TIMESTAMPTZ DEFAULT NOW(), -- When user connected
    last_sync_at TIMESTAMPTZ, -- Last successful data sync
    permission_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id), -- One Strava connection per HYKA user
    UNIQUE(strava_athlete_id) -- One HYKA user per Strava account
);

CREATE INDEX IF NOT EXISTS idx_strava_connections_user_id ON strava_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_strava_connections_athlete_id ON strava_connections(strava_athlete_id);
CREATE INDEX IF NOT EXISTS idx_strava_connections_permission_revoked ON strava_connections(permission_revoked);

COMMENT ON TABLE strava_connections IS 'Stores Strava OAuth 2.0 tokens and user mapping';
COMMENT ON COLUMN strava_connections.strava_athlete_id IS 'Strava athlete ID from authenticated athlete endpoint';

-- ----------------------------------------------------------------------------
-- 2. Strava Activities Table
-- ----------------------------------------------------------------------------
-- Stores activity summaries from Strava Activity API
-- Data comes from webhooks when activities are completed

CREATE TABLE IF NOT EXISTS strava_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    strava_activity_id BIGINT NOT NULL, -- Strava activity ID
    activity_name TEXT,
    activity_type TEXT, -- "Run", "TrailRun", "Walk", "Hike", etc.
    sport_type TEXT, -- "Run", "Walk", "Hike", etc.
    start_date TIMESTAMPTZ,
    start_date_local TIMESTAMPTZ,
    elapsed_time INTEGER, -- Duration in seconds
    moving_time INTEGER, -- Moving time in seconds
    distance_meters DOUBLE PRECISION,
    total_elevation_gain_meters DOUBLE PRECISION,
    average_speed_mps DOUBLE PRECISION, -- meters per second
    max_speed_mps DOUBLE PRECISION,
    average_cadence DOUBLE PRECISION, -- steps per minute
    average_heart_rate DOUBLE PRECISION,
    max_heart_rate DOUBLE PRECISION,
    calories INTEGER,
    device_name TEXT, -- Device that recorded the activity
    trainer BOOLEAN DEFAULT FALSE,
    commute BOOLEAN DEFAULT FALSE,
    manual BOOLEAN DEFAULT FALSE,
    private BOOLEAN DEFAULT FALSE,
    flagged BOOLEAN DEFAULT FALSE,
    workout_type INTEGER, -- 0=default, 1=race, 2=long run, 3=workout, 4=rest
    raw_summary JSONB, -- Full JSON summary from Strava
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, strava_activity_id)
);

CREATE INDEX IF NOT EXISTS idx_strava_activities_user_id ON strava_activities(user_id);
CREATE INDEX IF NOT EXISTS idx_strava_activities_start_date ON strava_activities(start_date DESC);
CREATE INDEX IF NOT EXISTS idx_strava_activities_activity_type ON strava_activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_strava_activities_strava_id ON strava_activities(strava_activity_id);

COMMENT ON TABLE strava_activities IS 'Activity summaries from Strava Activity API (via webhooks)';
COMMENT ON COLUMN strava_activities.activity_type IS 'Activity type: Run, TrailRun, Walk, Hike, etc.';
COMMENT ON COLUMN strava_activities.sport_type IS 'Sport type: Run, Walk, Hike, etc.';

-- ----------------------------------------------------------------------------
-- 3. Strava Activity Samples Table
-- ----------------------------------------------------------------------------
-- Stores per-second data from Strava Activity Streams API
-- Used for detailed analysis and race strategy

CREATE TABLE IF NOT EXISTS strava_activity_samples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_id UUID NOT NULL REFERENCES strava_activities(id) ON DELETE CASCADE,
    strava_activity_id BIGINT NOT NULL, -- Strava activity ID (for easy lookups)
    time_offset INTEGER NOT NULL, -- Seconds from activity start
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    altitude_meters DOUBLE PRECISION,
    distance_meters DOUBLE PRECISION,
    heart_rate INTEGER,
    cadence INTEGER, -- steps per minute
    watts DOUBLE PRECISION, -- Power (for cycling)
    velocity_smooth DOUBLE PRECISION, -- meters per second
    grade_smooth DOUBLE PRECISION, -- percentage
    temperature DOUBLE PRECISION, -- Celsius
    moving BOOLEAN,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, activity_id, time_offset)
);

CREATE INDEX IF NOT EXISTS idx_strava_samples_user_id ON strava_activity_samples(user_id);
CREATE INDEX IF NOT EXISTS idx_strava_samples_activity_id ON strava_activity_samples(activity_id);
CREATE INDEX IF NOT EXISTS idx_strava_samples_strava_activity_id ON strava_activity_samples(strava_activity_id);
CREATE INDEX IF NOT EXISTS idx_strava_samples_time_offset ON strava_activity_samples(activity_id, time_offset);

COMMENT ON TABLE strava_activity_samples IS 'Per-second activity data from Strava Activity Streams API';

-- ----------------------------------------------------------------------------
-- 4. Row-Level Security (RLS) Policies
-- ----------------------------------------------------------------------------

ALTER TABLE strava_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE strava_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE strava_activity_samples ENABLE ROW LEVEL SECURITY;

-- Users can only see their own connections
CREATE POLICY "Users can view their own Strava connections" ON strava_connections
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own Strava connections" ON strava_connections
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own Strava connections" ON strava_connections
    FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own Strava connections" ON strava_connections
    FOR DELETE USING (auth.uid() = user_id);

-- Users can only see their own activities
CREATE POLICY "Users can view their own Strava activities" ON strava_activities
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert Strava activities" ON strava_activities
    FOR INSERT WITH CHECK (true); -- Edge functions use service role

CREATE POLICY "Service role can update Strava activities" ON strava_activities
    FOR UPDATE USING (true) WITH CHECK (true);

-- Users can only see their own activity samples
CREATE POLICY "Users can view their own Strava activity samples" ON strava_activity_samples
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert Strava activity samples" ON strava_activity_samples
    FOR INSERT WITH CHECK (true); -- Edge functions use service role

-- ----------------------------------------------------------------------------
-- 5. Functions and Triggers
-- ----------------------------------------------------------------------------

-- Update updated_at timestamp
CREATE OR REPLACE FUNCTION update_strava_connections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_strava_connections_updated_at
    BEFORE UPDATE ON strava_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_strava_connections_updated_at();

CREATE OR REPLACE FUNCTION update_strava_activities_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_strava_activities_updated_at
    BEFORE UPDATE ON strava_activities
    FOR EACH ROW
    EXECUTE FUNCTION update_strava_activities_updated_at();

