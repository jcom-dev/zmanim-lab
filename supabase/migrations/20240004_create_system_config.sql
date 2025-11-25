-- Migration: Create system_config table
-- Story: 1.3 Admin Publisher Management
-- Date: 2025-11-25

-- Create system_config table for admin-configurable settings
CREATE TABLE IF NOT EXISTS system_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now(),
    updated_by UUID REFERENCES auth.users(id)
);

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_system_config_updated_at ON system_config(updated_at DESC);

-- Add trigger to update updated_at timestamp
CREATE TRIGGER update_system_config_updated_at
BEFORE UPDATE ON system_config
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Seed default configuration values
INSERT INTO system_config (key, value, description) VALUES
    ('rate_limit_anonymous', '{"requests_per_hour": 100}', 'Rate limit for anonymous API requests'),
    ('rate_limit_authenticated', '{"requests_per_hour": 1000}', 'Rate limit for authenticated API requests'),
    ('cache_ttl_hours', '{"hours": 24}', 'Cache TTL in hours for zmanim calculations'),
    ('feature_flags', '{"algorithm_editor": true, "formula_reveal": true}', 'Feature flags for platform capabilities')
ON CONFLICT (key) DO NOTHING;

-- Add comment to table
COMMENT ON TABLE system_config IS 'System-wide configuration settings manageable by admins';
