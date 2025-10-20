-- ============================================================================
-- Migration: Add Missing Columns to Existing garmin_connections Table
-- ============================================================================
-- 
-- This migration adds missing columns to an existing garmin_connections table
-- that was created from the old schema.
--
-- Run this if you get errors like:
-- ERROR: 42703: column "connected_at" does not exist
-- ERROR: 42703: column "permission_revoked" does not exist
-- ============================================================================

-- Add connected_at column (if missing)
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS connected_at TIMESTAMPTZ;

-- Add permission_revoked column (if missing)
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- Set default values for existing rows
UPDATE garmin_connections 
SET connected_at = COALESCE(connected_at, created_at, NOW())
WHERE connected_at IS NULL;

UPDATE garmin_connections 
SET permission_revoked = FALSE 
WHERE permission_revoked IS NULL;

-- Add index for permission_revoked (if missing)
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked 
ON garmin_connections(permission_revoked);

-- Add comments
COMMENT ON COLUMN garmin_connections.connected_at IS 
'Timestamp when user first connected (for backfill calculation)';

COMMENT ON COLUMN garmin_connections.permission_revoked IS 
'Flag for certification: user removed permissions but did not disconnect';

-- Verify columns exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'garmin_connections' 
        AND column_name = 'connected_at'
    ) THEN
        RAISE EXCEPTION 'Column connected_at was not added successfully';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'garmin_connections' 
        AND column_name = 'permission_revoked'
    ) THEN
        RAISE EXCEPTION 'Column permission_revoked was not added successfully';
    END IF;
    
    RAISE NOTICE '✅ All columns added successfully!';
END $$;

-- ============================================================================
-- Migration Complete
-- ============================================================================
-- 
-- The garmin_connections table now has:
-- ✅ connected_at (for backfill calculation)
-- ✅ permission_revoked (required for certification)
--
-- You can now run garmin_official_schema.sql without errors.
-- ============================================================================

