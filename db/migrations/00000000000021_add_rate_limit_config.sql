-- Migration: Add rate limiting configuration keys
-- These are required for the admin System Settings page

INSERT INTO system_config (key, value, description)
VALUES
  ('rate_limit_anonymous', '{"requests_per_hour": 100}', 'Rate limit for anonymous API requests'),
  ('rate_limit_authenticated', '{"requests_per_hour": 1000}', 'Rate limit for authenticated API requests')
ON CONFLICT (key) DO NOTHING;
