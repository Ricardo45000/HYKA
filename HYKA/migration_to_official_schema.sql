-- ============================================================================
-- Migration: Update garmin_connections to Official Schema
-- ============================================================================
-- 
-- This migration updates the existing garmin_connections table to match
-- the official Garmin integration schema requirements.
--
-- Run this if you get errors about missing columns like:
-- - permission_revoked
-- - connected_at
-- ============================================================================

-- Add permission_revoked column (required for certification)
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- Add connected_at column (for backfill calculation)
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS connected_at TIMESTAMPTZ;

-- Set connected_at to created_at for existing rows if it's NULL
UPDATE garmin_connections 
SET connected_at = created_at 
WHERE connected_at IS NULL;

-- Add index for permission_revoked
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked 
ON garmin_connections(permission_revoked);

-- Add comments
COMMENT ON COLUMN garmin_connections.permission_revoked IS 
'Flag for certification: user removed permissions but did not disconnect';

COMMENT ON COLUMN garmin_connections.connected_at IS 
'Timestamp when user first connected (for backfill calculation)';

-- Update existing rows to have default values
UPDATE garmin_connections 
SET permission_revoked = FALSE 
WHERE permission_revoked IS NULL;

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- 
-- The garmin_connections table now has:
-- ✅ permission_revoked (required for certification)
-- ✅ connected_at (for backfill calculation)
--
-- Next steps:
-- 1. Run the full garmin_official_schema.sql for other tables
-- 2. Deploy Edge Functions
-- 3. Test OAuth flow
-- ============================================================================

