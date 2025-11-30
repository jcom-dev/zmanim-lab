-- Migration: Fix publisher_zmanim_with_registry view to use is_core column
-- The column was renamed from is_fundamental to is_core in migration 20240028,
-- but the view still referenced the old column name

-- First, drop the view
DROP VIEW IF EXISTS publisher_zmanim_with_registry;

-- Recreate the view with the correct column name
CREATE VIEW publisher_zmanim_with_registry AS
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
    mr.is_core
FROM publisher_zmanim pz
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id;

COMMENT ON VIEW publisher_zmanim_with_registry IS 'Convenience view that joins publisher_zmanim with master registry data';
