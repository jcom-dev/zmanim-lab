-- Migration: Add support for linked zmanim (pointers to other publishers' zmanim)
-- This enables three ways to add zmanim:
-- 1. From Registry (source_type = 'registry')
-- 2. Copy from Publisher (source_type = 'copied')
-- 3. Link to Publisher (source_type = 'linked')

-- Add is_verified flag to publishers (for linking restrictions)
-- Only verified publishers can be linked to
ALTER TABLE publishers ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT false NOT NULL;
CREATE INDEX IF NOT EXISTS idx_publishers_verified ON publishers(is_verified) WHERE is_verified = true;

-- Add linking columns to publisher_zmanim
ALTER TABLE publisher_zmanim ADD COLUMN IF NOT EXISTS
    linked_publisher_zman_id UUID REFERENCES publisher_zmanim(id) ON DELETE SET NULL;

ALTER TABLE publisher_zmanim ADD COLUMN IF NOT EXISTS
    source_type VARCHAR(20) DEFAULT 'custom'
    CHECK (source_type IN ('registry', 'copied', 'linked', 'custom'));

CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_linked ON publisher_zmanim(linked_publisher_zman_id);
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_source_type ON publisher_zmanim(source_type);

-- Prevent self-links (can't link a zman to itself)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'no_self_links'
    ) THEN
        ALTER TABLE publisher_zmanim ADD CONSTRAINT no_self_links
            CHECK (linked_publisher_zman_id IS NULL OR linked_publisher_zman_id != id);
    END IF;
END $$;

-- Backfill existing records: set source_type based on existing data
UPDATE publisher_zmanim
SET source_type = CASE
    WHEN master_zman_id IS NOT NULL THEN 'registry'
    WHEN is_custom = true THEN 'custom'
    ELSE 'custom'
END
WHERE source_type IS NULL OR source_type = 'custom';

-- Create or replace view to resolve linked zmanim at query time
CREATE OR REPLACE VIEW publisher_zmanim_resolved AS
SELECT
    pz.id,
    pz.publisher_id,
    pz.zman_key,
    pz.hebrew_name,
    pz.english_name,
    -- Resolve formula from linked source if applicable
    COALESCE(linked_pz.formula_dsl, pz.formula_dsl) AS formula_dsl,
    pz.formula_dsl AS own_formula_dsl,
    pz.ai_explanation,
    pz.publisher_comment,
    pz.is_enabled,
    pz.is_visible,
    pz.is_published,
    pz.is_custom,
    pz.category,
    pz.dependencies,
    pz.sort_order,
    pz.master_zman_id,
    pz.linked_publisher_zman_id,
    pz.source_type,
    pz.current_version,
    pz.deleted_at,
    pz.deleted_by,
    pz.created_at,
    pz.updated_at,
    -- Linked source info
    linked_pz.publisher_id AS linked_source_publisher_id,
    linked_pub.name AS linked_source_publisher_name,
    linked_pz.deleted_at AS linked_source_deleted_at,
    -- Computed fields
    CASE
        WHEN pz.linked_publisher_zman_id IS NOT NULL THEN true
        ELSE false
    END AS is_linked,
    CASE
        WHEN pz.linked_publisher_zman_id IS NOT NULL AND linked_pz.deleted_at IS NOT NULL
        THEN true
        ELSE false
    END AS linked_source_is_deleted
FROM publisher_zmanim pz
LEFT JOIN publisher_zmanim linked_pz ON pz.linked_publisher_zman_id = linked_pz.id
LEFT JOIN publishers linked_pub ON linked_pz.publisher_id = linked_pub.id;

COMMENT ON VIEW publisher_zmanim_resolved IS 'Resolves linked zmanim to their source formulas at query time';
COMMENT ON COLUMN publisher_zmanim.linked_publisher_zman_id IS 'For linked zmanim, points to the source zman from another publisher';
COMMENT ON COLUMN publisher_zmanim.source_type IS 'How this zman was created: registry, copied, linked, or custom';
COMMENT ON COLUMN publishers.is_verified IS 'Verified publishers can have their zmanim linked to by other publishers';
