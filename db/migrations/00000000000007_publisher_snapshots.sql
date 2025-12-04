-- Publisher snapshots for version control
-- Stores full publisher state (profile, coverage, zmanim) as JSONB

CREATE TABLE IF NOT EXISTS publisher_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    snapshot_data JSONB NOT NULL,
    created_by TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_publisher_snapshots_publisher_created
    ON publisher_snapshots(publisher_id, created_at DESC);

-- Auto-prune trigger to keep max 20 snapshots per publisher
CREATE OR REPLACE FUNCTION prune_publisher_snapshots()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM publisher_snapshots
    WHERE id IN (
        SELECT id FROM publisher_snapshots
        WHERE publisher_id = NEW.publisher_id
        ORDER BY created_at DESC
        OFFSET 20
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_prune_publisher_snapshots ON publisher_snapshots;
CREATE TRIGGER trigger_prune_publisher_snapshots
    AFTER INSERT ON publisher_snapshots
    FOR EACH ROW EXECUTE FUNCTION prune_publisher_snapshots();
