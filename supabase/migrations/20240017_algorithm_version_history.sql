-- Migration: Algorithm Version History for Story 4-13
-- Adds proper version tracking with snapshots, diff capability, and rollback support

-- Algorithm versions table - stores snapshots of algorithm configuration
CREATE TABLE IF NOT EXISTS algorithm_version_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    algorithm_id UUID NOT NULL REFERENCES algorithms(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'draft', -- draft, published
    config_snapshot JSONB NOT NULL,
    description TEXT,
    created_by VARCHAR(255), -- Clerk user ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(algorithm_id, version_number)
);

-- Index for efficient version queries
CREATE INDEX IF NOT EXISTS idx_algorithm_versions_alg ON algorithm_version_history(algorithm_id);
CREATE INDEX IF NOT EXISTS idx_algorithm_versions_number ON algorithm_version_history(algorithm_id, version_number DESC);
CREATE INDEX IF NOT EXISTS idx_algorithm_versions_status ON algorithm_version_history(status);

-- Rollback audit table - tracks who rolled back and when
CREATE TABLE IF NOT EXISTS algorithm_rollback_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    algorithm_id UUID NOT NULL REFERENCES algorithms(id) ON DELETE CASCADE,
    source_version INT NOT NULL,
    target_version INT NOT NULL,
    new_version INT NOT NULL,
    reason TEXT,
    rolled_back_by VARCHAR(255) NOT NULL, -- Clerk user ID
    rolled_back_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rollback_audit_alg ON algorithm_rollback_audit(algorithm_id);
CREATE INDEX IF NOT EXISTS idx_rollback_audit_date ON algorithm_rollback_audit(rolled_back_at);

-- Function to get next version number for an algorithm
CREATE OR REPLACE FUNCTION get_next_algorithm_version(p_algorithm_id UUID)
RETURNS INT AS $$
DECLARE
    max_version INT;
BEGIN
    SELECT COALESCE(MAX(version_number), 0) INTO max_version
    FROM algorithm_version_history
    WHERE algorithm_id = p_algorithm_id;

    RETURN max_version + 1;
END;
$$ LANGUAGE plpgsql;

-- Comments
COMMENT ON TABLE algorithm_version_history IS 'Stores snapshots of algorithm configuration for version history';
COMMENT ON COLUMN algorithm_version_history.config_snapshot IS 'Full JSONB snapshot of the algorithm configuration at this version';
COMMENT ON COLUMN algorithm_version_history.version_number IS 'Incrementing version number per algorithm (v1, v2, v3...)';
COMMENT ON TABLE algorithm_rollback_audit IS 'Audit log of algorithm rollback operations';
