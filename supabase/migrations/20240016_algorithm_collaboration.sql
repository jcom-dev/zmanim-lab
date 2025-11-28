-- Migration: Algorithm Collaboration for Story 4-12
-- Adds support for public algorithms and fork/copy functionality

-- Add columns to algorithms table for collaboration
ALTER TABLE algorithms
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS forked_from UUID REFERENCES algorithms(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS attribution_text TEXT,
ADD COLUMN IF NOT EXISTS fork_count INT DEFAULT 0;

-- Index for public algorithms browse
CREATE INDEX IF NOT EXISTS idx_algorithms_public
ON algorithms(is_public) WHERE is_public = true;

-- Index for fork tracking
CREATE INDEX IF NOT EXISTS idx_algorithms_forked_from
ON algorithms(forked_from) WHERE forked_from IS NOT NULL;

-- Comments
COMMENT ON COLUMN algorithms.is_public IS 'Whether this algorithm is visible and can be copied/forked by other publishers';
COMMENT ON COLUMN algorithms.forked_from IS 'Reference to the source algorithm if this was forked';
COMMENT ON COLUMN algorithms.attribution_text IS 'Attribution text shown for forked algorithms';
COMMENT ON COLUMN algorithms.fork_count IS 'Number of times this algorithm has been forked';
