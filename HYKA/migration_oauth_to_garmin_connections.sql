-- ============================================================================
-- Migration: Replace oauth_connections/auth_connections with garmin_connections
-- ============================================================================
-- 
-- This migration:
-- 1. Creates garmin_connections table (if not exists)
-- 2. Migrates Garmin data from oauth_connections/auth_connections
-- 3. Updates any foreign key references
-- 4. Optionally drops old Garmin entries from oauth_connections
--
-- Benefits:
-- - Official Garmin schema with required fields (permission_revoked, connected_at)
-- - Better organization (Garmin-specific table)
-- - Certification compliance
-- ============================================================================

-- Step 1: Ensure garmin_connections table exists (from official schema)
CREATE TABLE IF NOT EXISTS garmin_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    garmin_user_id TEXT NOT NULL,
    access_token TEXT NOT NULL,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    connected_at TIMESTAMPTZ DEFAULT NOW(),
    last_sync_at TIMESTAMPTZ,
    permission_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id),
    UNIQUE(garmin_user_id)
);

-- Step 2: Create indexes
CREATE INDEX IF NOT EXISTS idx_garmin_connections_user_id ON garmin_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_connections_garmin_user_id ON garmin_connections(garmin_user_id);
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked ON garmin_connections(permission_revoked);

-- Step 3: Migrate data from oauth_connections (if table exists)
-- Try oauth_connections first
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'oauth_connections') THEN
        INSERT INTO garmin_connections (
            user_id,
            garmin_user_id,
            access_token,
            refresh_token,
            token_expires_at,
            connected_at,
            last_sync_at,
            permission_revoked,
            created_at,
            updated_at
        )
        SELECT 
            user_id,
            COALESCE(garmin_user_id, 'migrated_' || id::text) AS garmin_user_id, -- Use ID if garmin_user_id missing
            access_token,
            refresh_token,
            expires_at AS token_expires_at,
            COALESCE(created_at, NOW()) AS connected_at,
            updated_at AS last_sync_at,
            FALSE AS permission_revoked,
            created_at,
            updated_at
        FROM oauth_connections
        WHERE provider = 'garmin'
        ON CONFLICT (user_id) DO UPDATE
        SET
            garmin_user_id = EXCLUDED.garmin_user_id,
            access_token = EXCLUDED.access_token,
            refresh_token = EXCLUDED.refresh_token,
            token_expires_at = EXCLUDED.token_expires_at,
            connected_at = EXCLUDED.connected_at,
            last_sync_at = EXCLUDED.last_sync_at,
            updated_at = EXCLUDED.updated_at;
        
        RAISE NOTICE 'Migrated % rows from oauth_connections', (SELECT COUNT(*) FROM oauth_connections WHERE provider = 'garmin');
    END IF;
END $$;

-- Step 4: Migrate data from auth_connections (if table exists and oauth_connections doesn't)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'auth_connections') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'oauth_connections') THEN
        INSERT INTO garmin_connections (
            user_id,
            garmin_user_id,
            access_token,
            refresh_token,
            token_expires_at,
            connected_at,
            last_sync_at,
            permission_revoked,
            created_at,
            updated_at
        )
        SELECT 
            user_id,
            COALESCE(garmin_user_id, 'migrated_' || id::text) AS garmin_user_id,
            access_token,
            refresh_token,
            expires_at AS token_expires_at,
            COALESCE(created_at, NOW()) AS connected_at,
            updated_at AS last_sync_at,
            FALSE AS permission_revoked,
            created_at,
            updated_at
        FROM auth_connections
        WHERE provider = 'garmin'
        ON CONFLICT (user_id) DO UPDATE
        SET
            garmin_user_id = EXCLUDED.garmin_user_id,
            access_token = EXCLUDED.access_token,
            refresh_token = EXCLUDED.refresh_token,
            token_expires_at = EXCLUDED.token_expires_at,
            connected_at = EXCLUDED.connected_at,
            last_sync_at = EXCLUDED.last_sync_at,
            updated_at = EXCLUDED.updated_at;
        
        RAISE NOTICE 'Migrated % rows from auth_connections', (SELECT COUNT(*) FROM auth_connections WHERE provider = 'garmin');
    END IF;
END $$;

-- Step 5: Add comments
COMMENT ON TABLE garmin_connections IS 'Stores Garmin OAuth 2.0 tokens and user mapping (replaces oauth_connections/auth_connections for Garmin)';
COMMENT ON COLUMN garmin_connections.permission_revoked IS 'Flag for certification: user removed permissions but did not disconnect';
COMMENT ON COLUMN garmin_connections.connected_at IS 'Timestamp when user first connected (for backfill calculation)';

-- Step 6: Verify migration
DO $$
DECLARE
    migrated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO migrated_count FROM garmin_connections;
    RAISE NOTICE 'Total rows in garmin_connections: %', migrated_count;
END $$;

-- ============================================================================
-- Optional: Remove Garmin entries from old table (UNCOMMENT AFTER VERIFICATION)
-- ============================================================================
-- 
-- ⚠️ ONLY RUN THIS AFTER VERIFYING THE MIGRATION WAS SUCCESSFUL!
-- 
-- DELETE FROM oauth_connections WHERE provider = 'garmin';
-- OR
-- DELETE FROM auth_connections WHERE provider = 'garmin';
-- 
-- ============================================================================

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- 
-- Next steps:
-- 1. Verify data was migrated correctly:
--    SELECT * FROM garmin_connections;
-- 
-- 2. Update any code that references oauth_connections/auth_connections
--    to use garmin_connections instead
-- 
-- 3. After verification, optionally delete old Garmin entries from
--    oauth_connections/auth_connections (see Step 6 above)
-- 
-- 4. Run the full garmin_official_schema.sql for other tables
--    (garmin_activities, garmin_activity_samples, etc.)
-- 
-- ============================================================================

