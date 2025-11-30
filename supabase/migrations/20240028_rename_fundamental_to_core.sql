-- Migration: Rename is_fundamental to is_core
-- Better terminology: "core" zmanim are the essential ones that cannot be removed

-- Rename the column in master_zmanim_registry
ALTER TABLE master_zmanim_registry
  RENAME COLUMN is_fundamental TO is_core;

-- Update the comment
COMMENT ON COLUMN master_zmanim_registry.is_core IS 'If true, this zman is a core/essential zman that cannot be removed from the registry';
