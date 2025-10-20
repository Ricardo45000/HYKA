?-- ============================================================================
-- QUICK FIX: Add permission_revoked column
-- ============================================================================
-- 
-- Run this in Supabase SQL Editor to fix the error:
-- ERROR: 42703: column "permission_revoked" does not exist
-- ============================================================================

-- Add permission_revoked column
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS permission_revoked BOOLEAN DEFAULT FALSE;

-- Add connected_at column (also needed by new code)
ALTER TABLE garmin_connections 
ADD COLUMN IF NOT EXISTS connected_at TIMESTAMPTZ;

-- Set connected_at to created_at for existing rows
UPDATE garmin_connections 
SET connected_at = COALESCE(connected_at, created_at)
WHERE connected_at IS NULL;

-- Add index
CREATE INDEX IF NOT EXISTS idx_garmin_connections_permission_revoked 
ON garmin_connections(permission_revoked);

-- Set default for existing rows
UPDATE garmin_connections 
SET permission_revoked = FALSE 
WHERE permission_revoked IS NULL;

-- Done!
SELECT 'Migration complete! permission_revoked and connected_at columns added.' AS status;

