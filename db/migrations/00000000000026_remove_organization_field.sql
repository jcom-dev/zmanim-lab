-- Migration: 00000000000026_remove_organization_field.sql
-- Purpose: Remove organization field from publishers and publisher_requests tables
--          Publisher IS the organization, so organization field is redundant

-- Remove organization column from publishers
-- Existing data: organization text is discarded (publisher name serves this purpose now)
ALTER TABLE publishers DROP COLUMN IF EXISTS organization;

-- Remove organization column from publisher_requests
ALTER TABLE publisher_requests DROP COLUMN IF EXISTS organization;

-- Note: logo_url remains nullable for now. Application logic will:
-- 1. Allow existing publishers without logos to continue
-- 2. Prompt them to add a logo on next profile visit
-- 3. Require logo for new publisher registrations

-- Comment for clarity
COMMENT ON TABLE publishers IS 'Publishers who provide zmanim calculations. Publisher name IS the organization name.';
COMMENT ON TABLE publisher_requests IS 'Requests from users to become publishers. Publisher name IS the organization name.';
