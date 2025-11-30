-- Migration: Admin Zmanim Management Fields
-- Adds hidden field to master_zmanim_registry for admin visibility control

-- Add is_hidden field to master_zmanim_registry
-- Hidden zmanim won't appear in public registry queries but can be seen by admins
ALTER TABLE master_zmanim_registry
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT false NOT NULL;

-- Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_master_registry_hidden ON master_zmanim_registry(is_hidden);

-- Add comment explaining the field
COMMENT ON COLUMN master_zmanim_registry.is_hidden IS 'When true, this zman is hidden from public registry queries but visible to admins. Useful for deprecated or experimental zmanim.';

-- Also add audit fields for tracking who modified registry entries
ALTER TABLE master_zmanim_registry
ADD COLUMN IF NOT EXISTS created_by VARCHAR(255),
ADD COLUMN IF NOT EXISTS updated_by VARCHAR(255);

COMMENT ON COLUMN master_zmanim_registry.created_by IS 'Clerk user ID of the admin who created this zman';
COMMENT ON COLUMN master_zmanim_registry.updated_by IS 'Clerk user ID of the admin who last updated this zman';
