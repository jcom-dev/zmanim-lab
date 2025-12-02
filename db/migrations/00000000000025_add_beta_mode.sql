-- Migration: Add beta mode support for publisher zmanim
-- Allows publishers to release zmanim for public feedback before certification

-- Add is_beta column with default false (existing zmanim are considered stable)
ALTER TABLE publisher_zmanim ADD COLUMN IF NOT EXISTS is_beta BOOLEAN DEFAULT false NOT NULL;

-- Add certified_at timestamp to track when beta was removed
ALTER TABLE publisher_zmanim ADD COLUMN IF NOT EXISTS certified_at TIMESTAMPTZ;

-- Index for efficient querying of beta zmanim
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_beta ON publisher_zmanim(publisher_id, is_beta) WHERE is_beta = true;

-- Comments for documentation
COMMENT ON COLUMN publisher_zmanim.is_beta IS 'When true, this zman is in beta mode and displayed with a warning to users. Publishers use beta mode to gather feedback before certifying a zman as stable.';
COMMENT ON COLUMN publisher_zmanim.certified_at IS 'Timestamp when is_beta was changed from true to false, indicating publisher certification';
