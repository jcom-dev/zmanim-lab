-- Master Zmanim Registry SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- ============================================
-- MASTER REGISTRY QUERIES
-- ============================================

-- name: GetAllMasterZmanim :many
SELECT
    id, zman_key, canonical_hebrew_name, canonical_english_name,
    transliteration, description, halachic_notes, halachic_source,
    time_category, default_formula_dsl, is_fundamental, sort_order,
    created_at, updated_at
FROM master_zmanim_registry
ORDER BY time_category, sort_order, canonical_hebrew_name;

-- name: GetMasterZmanimByCategory :many
SELECT
    id, zman_key, canonical_hebrew_name, canonical_english_name,
    transliteration, description, halachic_notes, halachic_source,
    time_category, default_formula_dsl, is_fundamental, sort_order,
    created_at, updated_at
FROM master_zmanim_registry
WHERE time_category = $1
ORDER BY sort_order, canonical_hebrew_name;

-- name: GetMasterZmanByKey :one
SELECT
    id, zman_key, canonical_hebrew_name, canonical_english_name,
    transliteration, description, halachic_notes, halachic_source,
    time_category, default_formula_dsl, is_fundamental, sort_order,
    created_at, updated_at
FROM master_zmanim_registry
WHERE zman_key = $1;

-- name: GetMasterZmanByID :one
SELECT
    id, zman_key, canonical_hebrew_name, canonical_english_name,
    transliteration, description, halachic_notes, halachic_source,
    time_category, default_formula_dsl, is_fundamental, sort_order,
    created_at, updated_at
FROM master_zmanim_registry
WHERE id = $1;

-- name: SearchMasterZmanim :many
SELECT
    id, zman_key, canonical_hebrew_name, canonical_english_name,
    transliteration, description, halachic_notes, halachic_source,
    time_category, default_formula_dsl, is_fundamental, sort_order,
    created_at, updated_at
FROM master_zmanim_registry
WHERE
    canonical_hebrew_name ILIKE '%' || $1 || '%'
    OR canonical_english_name ILIKE '%' || $1 || '%'
    OR transliteration ILIKE '%' || $1 || '%'
    OR zman_key ILIKE '%' || $1 || '%'
ORDER BY
    CASE
        WHEN canonical_english_name ILIKE $1 || '%' THEN 1
        WHEN canonical_hebrew_name ILIKE $1 || '%' THEN 2
        ELSE 3
    END,
    sort_order
LIMIT 50;

-- name: GetMasterZmanimGroupedByCategory :many
SELECT
    time_category,
    json_agg(
        json_build_object(
            'id', id,
            'zman_key', zman_key,
            'canonical_hebrew_name', canonical_hebrew_name,
            'canonical_english_name', canonical_english_name,
            'transliteration', transliteration,
            'default_formula_dsl', default_formula_dsl,
            'is_fundamental', is_fundamental,
            'sort_order', sort_order
        ) ORDER BY sort_order, canonical_hebrew_name
    ) as zmanim
FROM master_zmanim_registry
GROUP BY time_category
ORDER BY
    CASE time_category
        WHEN 'dawn' THEN 1
        WHEN 'sunrise' THEN 2
        WHEN 'morning' THEN 3
        WHEN 'midday' THEN 4
        WHEN 'afternoon' THEN 5
        WHEN 'sunset' THEN 6
        WHEN 'nightfall' THEN 7
        WHEN 'midnight' THEN 8
    END;

-- ============================================
-- TAG QUERIES
-- ============================================

-- name: GetAllTags :many
SELECT
    id, name, display_name_hebrew, display_name_english,
    tag_type, description, color, sort_order, created_at
FROM zman_tags
ORDER BY tag_type, sort_order, name;

-- name: GetTagsByType :many
SELECT
    id, name, display_name_hebrew, display_name_english,
    tag_type, description, color, sort_order, created_at
FROM zman_tags
WHERE tag_type = $1
ORDER BY sort_order, name;

-- name: GetTagByName :one
SELECT
    id, name, display_name_hebrew, display_name_english,
    tag_type, description, color, sort_order, created_at
FROM zman_tags
WHERE name = $1;

-- name: GetTagsForMasterZman :many
SELECT
    t.id, t.name, t.display_name_hebrew, t.display_name_english,
    t.tag_type, t.description, t.color, t.sort_order, t.created_at
FROM zman_tags t
JOIN master_zman_tags mzt ON t.id = mzt.tag_id
WHERE mzt.master_zman_id = $1
ORDER BY t.tag_type, t.sort_order;

-- name: GetMasterZmanimByTag :many
SELECT
    mr.id, mr.zman_key, mr.canonical_hebrew_name, mr.canonical_english_name,
    mr.transliteration, mr.description, mr.halachic_notes, mr.halachic_source,
    mr.time_category, mr.default_formula_dsl, mr.is_fundamental, mr.sort_order,
    mr.created_at, mr.updated_at
FROM master_zmanim_registry mr
JOIN master_zman_tags mzt ON mr.id = mzt.master_zman_id
JOIN zman_tags t ON t.id = mzt.tag_id
WHERE t.name = $1
ORDER BY mr.time_category, mr.sort_order;

-- ============================================
-- PUBLISHER ZMANIM WITH REGISTRY (new model)
-- ============================================

-- name: GetPublisherZmanimWithRegistry :many
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
    pz.is_published,
    COALESCE(pz.is_custom, false) AS is_custom,
    COALESCE(mr.time_category, pz.category) AS time_category,
    pz.category,
    pz.dependencies,
    pz.sort_order,
    pz.current_version,
    pz.created_at,
    pz.updated_at,
    pz.master_zman_id,
    mr.description AS zman_description,
    mr.halachic_notes,
    mr.is_fundamental
FROM publisher_zmanim pz
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
WHERE pz.publisher_id = $1
  AND pz.deleted_at IS NULL
ORDER BY
    CASE COALESCE(mr.time_category, pz.category)
        WHEN 'dawn' THEN 1
        WHEN 'sunrise' THEN 2
        WHEN 'morning' THEN 3
        WHEN 'midday' THEN 4
        WHEN 'afternoon' THEN 5
        WHEN 'sunset' THEN 6
        WHEN 'nightfall' THEN 7
        WHEN 'midnight' THEN 8
        ELSE 9
    END,
    pz.sort_order,
    pz.hebrew_name;

-- name: GetPublisherZmanWithRegistry :one
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
    pz.is_published,
    COALESCE(pz.is_custom, false) AS is_custom,
    COALESCE(mr.time_category, pz.category) AS time_category,
    pz.category,
    pz.dependencies,
    pz.sort_order,
    pz.current_version,
    pz.created_at,
    pz.updated_at,
    pz.master_zman_id,
    mr.description AS zman_description,
    mr.halachic_notes,
    mr.is_fundamental
FROM publisher_zmanim pz
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
WHERE pz.publisher_id = $1
  AND pz.zman_key = $2
  AND pz.deleted_at IS NULL;

-- name: CreatePublisherZmanFromRegistry :one
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, master_zman_id, current_version
)
SELECT
    gen_random_uuid() AS id,
    $1 AS publisher_id,
    mr.zman_key AS zman_key,
    mr.canonical_hebrew_name AS hebrew_name,
    mr.canonical_english_name AS english_name,
    COALESCE(sqlc.narg('formula_dsl'), mr.default_formula_dsl) AS formula_dsl,
    NULL AS ai_explanation,
    NULL AS publisher_comment,
    true AS is_enabled,
    true AS is_visible,
    false AS is_published,
    false AS is_custom,
    mr.time_category AS category,
    '{}'::text[] AS dependencies,
    mr.sort_order AS sort_order,
    mr.id AS master_zman_id,
    1 AS current_version
FROM master_zmanim_registry mr
WHERE mr.id = $2
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at, master_zman_id, current_version;

-- name: ImportZmanimFromRegistryByKeys :many
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, master_zman_id, current_version
)
SELECT
    gen_random_uuid(),
    $1,
    mr.zman_key,
    mr.canonical_hebrew_name,
    mr.canonical_english_name,
    mr.default_formula_dsl,
    NULL,
    NULL,
    true,
    true,
    false,
    false,
    mr.time_category,
    '{}',
    mr.sort_order,
    mr.id,
    1
FROM master_zmanim_registry mr
WHERE mr.zman_key = ANY($2::text[])
ON CONFLICT (publisher_id, zman_key) DO NOTHING
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at, master_zman_id, current_version;

-- ============================================
-- SOFT DELETE QUERIES
-- ============================================

-- name: SoftDeletePublisherZman :one
UPDATE publisher_zmanim
SET deleted_at = NOW(), deleted_by = $3, updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NULL
RETURNING id, publisher_id, zman_key, deleted_at, deleted_by;

-- name: RestorePublisherZman :one
UPDATE publisher_zmanim
SET deleted_at = NULL, deleted_by = NULL, updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NOT NULL
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at, master_zman_id, current_version;

-- name: GetDeletedPublisherZmanim :many
SELECT
    pz.id,
    pz.publisher_id,
    pz.zman_key,
    COALESCE(mr.canonical_hebrew_name, pz.hebrew_name) AS hebrew_name,
    COALESCE(mr.canonical_english_name, pz.english_name) AS english_name,
    pz.formula_dsl,
    pz.deleted_at,
    pz.deleted_by,
    COALESCE(mr.time_category, pz.category) AS time_category,
    pz.master_zman_id
FROM publisher_zmanim pz
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
WHERE pz.publisher_id = $1
  AND pz.deleted_at IS NOT NULL
ORDER BY pz.deleted_at DESC;

-- name: PermanentDeletePublisherZman :exec
DELETE FROM publisher_zmanim
WHERE publisher_id = $1 AND zman_key = $2 AND deleted_at IS NOT NULL;

-- ============================================
-- VERSION HISTORY QUERIES
-- ============================================

-- name: GetZmanVersionHistory :many
SELECT
    pzv.id,
    pzv.publisher_zman_id,
    pzv.version_number,
    pzv.formula_dsl,
    pzv.created_by,
    pzv.created_at
FROM publisher_zman_versions pzv
JOIN publisher_zmanim pz ON pz.id = pzv.publisher_zman_id
WHERE pz.publisher_id = $1 AND pz.zman_key = $2
ORDER BY pzv.version_number DESC
LIMIT 7;

-- name: GetZmanVersion :one
SELECT
    pzv.id,
    pzv.publisher_zman_id,
    pzv.version_number,
    pzv.formula_dsl,
    pzv.created_by,
    pzv.created_at
FROM publisher_zman_versions pzv
JOIN publisher_zmanim pz ON pz.id = pzv.publisher_zman_id
WHERE pz.publisher_id = $1 AND pz.zman_key = $2 AND pzv.version_number = $3;

-- name: CreateZmanVersion :one
INSERT INTO publisher_zman_versions (
    publisher_zman_id,
    version_number,
    formula_dsl,
    created_by
)
SELECT
    pz.id,
    COALESCE((SELECT MAX(version_number) FROM publisher_zman_versions WHERE publisher_zman_id = pz.id), 0) + 1,
    $3,
    $4
FROM publisher_zmanim pz
WHERE pz.publisher_id = $1 AND pz.zman_key = $2
RETURNING id, publisher_zman_id, version_number, formula_dsl, created_by, created_at;

-- name: UpdateZmanCurrentVersion :exec
UPDATE publisher_zmanim
SET current_version = $3, updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = $2;

-- name: RollbackZmanToVersion :one
UPDATE publisher_zmanim pz
SET
    formula_dsl = pzv.formula_dsl,
    current_version = (SELECT COALESCE(MAX(version_number), 0) + 1 FROM publisher_zman_versions WHERE publisher_zman_id = pz.id),
    updated_at = NOW()
FROM publisher_zman_versions pzv
WHERE pz.publisher_id = $1
  AND pz.zman_key = $2
  AND pzv.publisher_zman_id = pz.id
  AND pzv.version_number = $3
RETURNING pz.id, pz.publisher_id, pz.zman_key, pz.formula_dsl, pz.current_version;

-- ============================================
-- ZMAN REGISTRY REQUESTS
-- ============================================

-- name: CreateZmanRegistryRequest :one
INSERT INTO zman_registry_requests (
    publisher_id,
    requested_key,
    requested_hebrew_name,
    requested_english_name,
    requested_formula_dsl,
    time_category,
    justification
) VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
    requested_formula_dsl, time_category, justification, status, created_at;

-- name: GetZmanRegistryRequests :many
SELECT
    id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
    requested_formula_dsl, time_category, justification, status,
    reviewed_by, reviewed_at, reviewer_notes, created_at
FROM zman_registry_requests
WHERE status = COALESCE(sqlc.narg('status'), status)
ORDER BY created_at DESC;

-- name: GetZmanRegistryRequestByID :one
SELECT
    id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
    requested_formula_dsl, time_category, justification, status,
    reviewed_by, reviewed_at, reviewer_notes, created_at
FROM zman_registry_requests
WHERE id = $1;

-- name: UpdateZmanRegistryRequestStatus :one
UPDATE zman_registry_requests
SET
    status = $2,
    reviewed_by = $3,
    reviewed_at = NOW(),
    reviewer_notes = $4
WHERE id = $1
RETURNING id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
    requested_formula_dsl, time_category, justification, status,
    reviewed_by, reviewed_at, reviewer_notes, created_at;

-- name: AddMasterZmanFromRequest :one
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
SELECT
    requested_key,
    requested_hebrew_name,
    requested_english_name,
    time_category,
    requested_formula_dsl,
    false,
    999,
    'Added from publisher request'
FROM zman_registry_requests zrr
WHERE zrr.id = $1
RETURNING id, zman_key, canonical_hebrew_name, canonical_english_name, time_category,
    default_formula_dsl, is_fundamental, sort_order, created_at, updated_at;
