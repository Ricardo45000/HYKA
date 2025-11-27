-- ============================================================================
-- User Devices Table for Push Notifications
-- ============================================================================
-- Purpose: Store device tokens for push notifications
-- 
-- This table stores:
-- - Device tokens (APNs tokens for iOS)
-- - Device type (ios, android)
-- - Push notification preferences
-- ============================================================================

-- Create user_devices table
CREATE TABLE IF NOT EXISTS user_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  device_type TEXT NOT NULL CHECK (device_type IN ('ios', 'android')),
  push_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, device_token)
);

-- Enable RLS
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can manage their own devices" ON user_devices;
DROP POLICY IF EXISTS "Users can read their own devices" ON user_devices;
DROP POLICY IF EXISTS "Service role can manage all devices" ON user_devices;

-- RLS Policies
-- Users can manage their own devices
CREATE POLICY "Users can manage their own devices"
  ON user_devices
  FOR ALL
  USING (auth.uid() = user_id);

-- Service role can manage all devices (for edge functions)
CREATE POLICY "Service role can manage all devices"
  ON user_devices
  FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- Indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_push_enabled ON user_devices(user_id, push_enabled) WHERE push_enabled = true;
CREATE INDEX IF NOT EXISTS idx_user_devices_device_token ON user_devices(device_token);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_user_devices_updated_at_trigger ON user_devices;
CREATE TRIGGER update_user_devices_updated_at_trigger
  BEFORE UPDATE ON user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_user_devices_updated_at();

-- Grant permissions
GRANT ALL ON user_devices TO authenticated;
GRANT ALL ON user_devices TO service_role;

