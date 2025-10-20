-- Create app_config table to store Garmin Pull Token
-- Pull Tokens expire every 24 hours and need to be updated daily

CREATE TABLE IF NOT EXISTS app_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_app_config_key ON app_config(key);

-- Insert initial Pull Token (update this with your current Pull Token from Garmin Developer Portal)
INSERT INTO app_config (key, value, description)
VALUES (
    'garmin_pull_token',
    'CPT1763250098.9HZ__7xckH4',  -- Replace with your current Pull Token
    'Garmin Wellness API Pull Token - expires every 24 hours. Update daily from Garmin Developer Portal.'
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = NOW();

-- Create a function to update the Pull Token
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

-- Grant access to authenticated users (optional - adjust based on your security needs)
-- ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow authenticated users to read app_config" ON app_config
--     FOR SELECT USING (auth.role() = 'authenticated');

