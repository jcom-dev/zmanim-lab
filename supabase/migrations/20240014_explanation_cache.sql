-- Migration: Explanation Cache for Story 4-9
-- Caches AI-generated formula explanations to reduce API calls

CREATE TABLE IF NOT EXISTS explanation_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    formula_hash VARCHAR(64) NOT NULL,
    language VARCHAR(10) NOT NULL,
    explanation TEXT NOT NULL,
    source VARCHAR(20) DEFAULT 'ai',  -- 'ai', 'custom'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,

    UNIQUE(formula_hash, language)
);

-- Index for fast lookup
CREATE INDEX IF NOT EXISTS idx_explanation_cache_lookup
ON explanation_cache(formula_hash, language);

-- Index for cleanup of expired entries
CREATE INDEX IF NOT EXISTS idx_explanation_cache_expiry
ON explanation_cache(expires_at);

-- Comments
COMMENT ON TABLE explanation_cache IS 'Cache for AI-generated formula explanations';
COMMENT ON COLUMN explanation_cache.formula_hash IS 'SHA-256 hash of the formula text';
COMMENT ON COLUMN explanation_cache.expires_at IS 'TTL is typically 7 days';

-- Function to clean up expired entries (can be run periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_explanations()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM explanation_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
