-- ============================================================================
-- Migration: Add permission_revoked column to garmin_connections
-- ============================================================================
-- 
-- This migration adds the permission_revoked column required for certification
-- compliance with Garmin Developer Program requirements.
--
-- Run this migration if you get:
-- ERROR: 42703: column "permission_revoked" does not exist
-- ============================================================================

-- Add permission_revoked column if it doesn't exist
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- Add index for efficient queries
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked 
ON garmin_connections(permission_revoked);

-- Add comment
COMMENT ON COLUMN garmin_connections.permission_revoked IS 
'Flag for certification: user removed permissions but did not disconnect';

-- Update existing rows to have default value
UPDATE garmin_connections 
SET permission_revoked = FALSE 
WHERE permission_revoked IS NULL;

-- ============================================================================
-- Migration Complete
-- ============================================================================

