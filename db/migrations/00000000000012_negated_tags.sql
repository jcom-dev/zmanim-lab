-- Migration 12: Add is_negated column to tag join tables
-- This enables expressions like "All Yom Tov except Pesach"

-- Add is_negated column to master_zman_tags
ALTER TABLE master_zman_tags
ADD COLUMN IF NOT EXISTS is_negated BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN master_zman_tags.is_negated IS
'When true, this zman should NOT appear on days matching this tag';

-- Add is_negated column to publisher_zman_tags
ALTER TABLE publisher_zman_tags
ADD COLUMN IF NOT EXISTS is_negated BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN publisher_zman_tags.is_negated IS
'When true, this zman should NOT appear on days matching this tag';

-- Create indexes for efficient filtering
CREATE INDEX IF NOT EXISTS idx_master_zman_tags_negated
ON master_zman_tags(master_zman_id, is_negated);

CREATE INDEX IF NOT EXISTS idx_publisher_zman_tags_negated
ON publisher_zman_tags(publisher_zman_id, is_negated);
