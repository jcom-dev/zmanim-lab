-- Add is_published flag to publisher_zmanim
-- This separates "enabled for calculation" from "published for public consumption"
-- - is_enabled: whether the zman is active in the publisher's algorithm
-- - is_published: whether the zman is visible to the public

-- Add the is_published column (defaults to false - zmanim start unpublished)
ALTER TABLE publisher_zmanim ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT false NOT NULL;

-- Add index for efficient queries on published zmanim
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_published ON publisher_zmanim(publisher_id, is_published) WHERE is_published = true;

-- Update comment
COMMENT ON COLUMN publisher_zmanim.is_enabled IS 'Whether this zman is active in the algorithm (for preview/calculation)';
COMMENT ON COLUMN publisher_zmanim.is_published IS 'Whether this zman is publicly visible to end users';

-- Also add is_published to publishers table to track overall publish state
ALTER TABLE publishers ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT false NOT NULL;
COMMENT ON COLUMN publishers.is_published IS 'Whether the publisher profile and zmanim are publicly visible';
