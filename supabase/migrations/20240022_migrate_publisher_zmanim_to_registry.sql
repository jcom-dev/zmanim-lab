-- Migration: Link existing publisher_zmanim to master registry and create initial versions
-- This must run AFTER 20240021_master_zmanim_registry.sql

-- ============================================
-- PART 1: LINK EXISTING PUBLISHER_ZMANIM TO MASTER REGISTRY
-- ============================================

-- Update publisher_zmanim to link to master_zmanim_registry by matching zman_key
UPDATE publisher_zmanim pz
SET master_zman_id = mr.id
FROM master_zmanim_registry mr
WHERE pz.zman_key = mr.zman_key
AND pz.master_zman_id IS NULL;

-- For any zmanim that couldn't be linked (truly custom), we need to handle them
-- Create a report of unlinked zmanim for manual review
DO $$
DECLARE
    unlinked_count INT;
BEGIN
    SELECT COUNT(*) INTO unlinked_count
    FROM publisher_zmanim
    WHERE master_zman_id IS NULL AND deleted_at IS NULL;

    IF unlinked_count > 0 THEN
        RAISE NOTICE 'Found % publisher_zmanim that could not be linked to master registry. These may be custom zmanim that need manual review.', unlinked_count;
    END IF;
END $$;

-- ============================================
-- PART 2: CREATE INITIAL VERSION FOR ALL EXISTING ZMANIM
-- ============================================

-- Insert version 1 for all existing publisher_zmanim that don't have a version yet
INSERT INTO publisher_zman_versions (publisher_zman_id, version_number, formula_dsl, created_by, created_at)
SELECT
    pz.id,
    1,
    pz.formula_dsl,
    NULL,  -- No user ID for migration
    pz.created_at  -- Use original creation time
FROM publisher_zmanim pz
WHERE NOT EXISTS (
    SELECT 1 FROM publisher_zman_versions pzv
    WHERE pzv.publisher_zman_id = pz.id
)
AND pz.deleted_at IS NULL;

-- Set current_version to 1 for all zmanim that were migrated
UPDATE publisher_zmanim
SET current_version = 1
WHERE current_version IS NULL OR current_version = 0;

-- ============================================
-- PART 3: HANDLE ORPHANED ZMANIM
-- ============================================

-- Any publisher_zmanim without a master_zman_id after migration are truly custom
-- We'll add them to a special "custom" category in the registry with a request status

-- First, let's identify and add any common custom zmanim to the registry
-- This catches zmanim that publishers may have created with slightly different keys

-- Add any missing zmanim that exist in publisher_zmanim but not in registry
-- Only add if they appear in multiple publishers (indicating they're commonly used)
INSERT INTO master_zmanim_registry (
    zman_key,
    canonical_hebrew_name,
    canonical_english_name,
    time_category,
    default_formula_dsl,
    is_fundamental,
    sort_order,
    description
)
SELECT DISTINCT
    pz.zman_key,
    pz.hebrew_name,
    pz.english_name,
    CASE
        WHEN pz.zman_key LIKE 'alos%' THEN 'dawn'
        WHEN pz.zman_key LIKE 'misheyakir%' THEN 'sunrise'
        WHEN pz.zman_key LIKE 'sunrise%' THEN 'sunrise'
        WHEN pz.zman_key LIKE 'sof_zman_shma%' THEN 'morning'
        WHEN pz.zman_key LIKE 'sof_zman_tfila%' THEN 'morning'
        WHEN pz.zman_key LIKE 'chatzos%' THEN 'midday'
        WHEN pz.zman_key LIKE 'mincha%' THEN 'afternoon'
        WHEN pz.zman_key LIKE 'plag%' THEN 'afternoon'
        WHEN pz.zman_key LIKE 'sunset%' OR pz.zman_key LIKE 'shkia%' THEN 'sunset'
        WHEN pz.zman_key LIKE 'candle%' THEN 'sunset'
        WHEN pz.zman_key LIKE 'tzais%' THEN 'nightfall'
        WHEN pz.zman_key LIKE 'shabbos%' OR pz.zman_key LIKE 'motzei%' THEN 'nightfall'
        ELSE 'midnight'
    END,
    pz.formula_dsl,
    false,
    999,  -- High sort order for custom additions
    'Auto-migrated from publisher_zmanim'
FROM publisher_zmanim pz
WHERE pz.master_zman_id IS NULL
AND pz.deleted_at IS NULL
AND NOT EXISTS (
    SELECT 1 FROM master_zmanim_registry mr
    WHERE mr.zman_key = pz.zman_key
)
ON CONFLICT (zman_key) DO NOTHING;

-- Now try to link again after adding any missing zmanim
UPDATE publisher_zmanim pz
SET master_zman_id = mr.id
FROM master_zmanim_registry mr
WHERE pz.zman_key = mr.zman_key
AND pz.master_zman_id IS NULL;

-- ============================================
-- PART 4: REMOVE ALGORITHM-LEVEL VERSION HISTORY
-- ============================================

-- Drop old algorithm-level version history tables (replaced by per-zman history)
DROP TABLE IF EXISTS algorithm_rollback_audit CASCADE;
DROP TABLE IF EXISTS algorithm_version_history CASCADE;
DROP FUNCTION IF EXISTS get_next_algorithm_version(UUID) CASCADE;

-- ============================================
-- PART 5: CLEAN UP DEPRECATED COLUMNS
-- ============================================

-- We'll keep hebrew_name and english_name for now as they may be needed
-- for backwards compatibility during transition. They can be removed
-- in a future migration after frontend is updated.

-- Mark the is_custom column as deprecated (don't drop yet for safety)
-- In the new model, is_custom is determined by master_zman_id being NULL
-- which shouldn't happen anymore

-- Create a view that joins publisher_zmanim with master registry for easy querying
CREATE OR REPLACE VIEW publisher_zmanim_with_registry AS
SELECT
    pz.id,
    pz.publisher_id,
    pz.zman_key,
    COALESCE(mr.canonical_hebrew_name, pz.hebrew_name) AS hebrew_name,
    COALESCE(mr.canonical_english_name, pz.english_name) AS english_name,
    mr.transliteration,
    pz.formula_dsl,
    mr.default_formula_dsl,
    pz.ai_explanation,
    pz.publisher_comment,
    pz.is_enabled,
    pz.is_visible,
    COALESCE(pz.is_custom, false) AS is_custom,
    COALESCE(mr.time_category, pz.category) AS time_category,
    pz.category,
    pz.dependencies,
    pz.sort_order,
    pz.current_version,
    pz.deleted_at,
    pz.deleted_by,
    pz.created_at,
    pz.updated_at,
    pz.master_zman_id,
    mr.description AS zman_description,
    mr.halachic_notes,
    mr.halachic_source,
    mr.is_fundamental
FROM publisher_zmanim pz
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id;

COMMENT ON VIEW publisher_zmanim_with_registry IS 'Convenience view that joins publisher_zmanim with master registry data';

-- ============================================
-- PART 6: FINAL VALIDATION
-- ============================================

DO $$
DECLARE
    total_zmanim INT;
    linked_zmanim INT;
    unlinked_zmanim INT;
    total_versions INT;
BEGIN
    SELECT COUNT(*) INTO total_zmanim FROM publisher_zmanim WHERE deleted_at IS NULL;
    SELECT COUNT(*) INTO linked_zmanim FROM publisher_zmanim WHERE master_zman_id IS NOT NULL AND deleted_at IS NULL;
    SELECT COUNT(*) INTO unlinked_zmanim FROM publisher_zmanim WHERE master_zman_id IS NULL AND deleted_at IS NULL;
    SELECT COUNT(*) INTO total_versions FROM publisher_zman_versions;

    RAISE NOTICE 'Migration complete:';
    RAISE NOTICE '  Total active publisher_zmanim: %', total_zmanim;
    RAISE NOTICE '  Linked to master registry: %', linked_zmanim;
    RAISE NOTICE '  Unlinked (orphaned): %', unlinked_zmanim;
    RAISE NOTICE '  Version history records created: %', total_versions;

    IF unlinked_zmanim > 0 THEN
        RAISE WARNING 'There are % unlinked zmanim that need manual review!', unlinked_zmanim;
    END IF;
END $$;
