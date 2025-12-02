-- Zmanim SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- Publisher Zmanim --

-- name: GetPublisherZmanim :many
SELECT
    pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
    pz.transliteration, pz.description,
    -- Resolve formula from linked source if applicable
    COALESCE(linked_pz.formula_dsl, pz.formula_dsl) AS formula_dsl,
    pz.ai_explanation, pz.publisher_comment,
    pz.is_enabled, pz.is_visible, pz.is_published, pz.is_beta, pz.is_custom, pz.category,
    pz.dependencies, pz.sort_order, pz.created_at, pz.updated_at,
    pz.master_zman_id, pz.linked_publisher_zman_id, pz.source_type,
    -- Source/original values from registry or linked publisher (for diff/revert UI)
    COALESCE(mr.canonical_hebrew_name, linked_pz.hebrew_name) AS source_hebrew_name,
    COALESCE(mr.canonical_english_name, linked_pz.english_name) AS source_english_name,
    COALESCE(mr.transliteration, linked_pz.transliteration) AS source_transliteration,
    COALESCE(mr.description, linked_pz.description) AS source_description,
    COALESCE(mr.default_formula_dsl, linked_pz.formula_dsl) AS source_formula_dsl,
    -- Check if this zman is linked to any events (daily zmanim have no event links)
    EXISTS (
        SELECT 1 FROM master_zman_events mze
        WHERE mze.master_zman_id = pz.master_zman_id
    ) AS is_event_zman,
    -- Tags from master zman (if from registry)
    COALESCE(
        (SELECT json_agg(json_build_object(
            'id', t.id,
            'tag_key', t.tag_key,
            'name', t.name,
            'display_name_hebrew', t.display_name_hebrew,
            'display_name_english', t.display_name_english,
            'tag_type', t.tag_type
        ) ORDER BY t.sort_order)
        FROM master_zman_tags mzt
        JOIN zman_tags t ON mzt.tag_id = t.id
        WHERE mzt.master_zman_id = pz.master_zman_id),
        '[]'::json
    ) AS tags,
    -- Linked source info
    CASE WHEN pz.linked_publisher_zman_id IS NOT NULL THEN true ELSE false END AS is_linked,
    linked_pub.name AS linked_source_publisher_name,
    CASE WHEN pz.linked_publisher_zman_id IS NOT NULL AND linked_pz.deleted_at IS NOT NULL
         THEN true ELSE false END AS linked_source_is_deleted
FROM publisher_zmanim pz
LEFT JOIN publisher_zmanim linked_pz ON pz.linked_publisher_zman_id = linked_pz.id
LEFT JOIN publishers linked_pub ON linked_pz.publisher_id = linked_pub.id
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
WHERE pz.publisher_id = $1
  AND pz.deleted_at IS NULL
ORDER BY pz.sort_order, pz.hebrew_name;

-- name: GetPublisherZmanByKey :one
SELECT
    pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
    pz.transliteration, pz.description,
    COALESCE(linked_pz.formula_dsl, pz.formula_dsl) AS formula_dsl,
    pz.ai_explanation, pz.publisher_comment,
    pz.is_enabled, pz.is_visible, pz.is_published, pz.is_beta, pz.is_custom, pz.category,
    pz.dependencies, pz.sort_order, pz.created_at, pz.updated_at,
    pz.master_zman_id, pz.linked_publisher_zman_id, pz.source_type,
    -- Source/original values from registry or linked publisher (for diff/revert UI)
    COALESCE(mr.canonical_hebrew_name, linked_pz.hebrew_name) AS source_hebrew_name,
    COALESCE(mr.canonical_english_name, linked_pz.english_name) AS source_english_name,
    COALESCE(mr.transliteration, linked_pz.transliteration) AS source_transliteration,
    COALESCE(mr.description, linked_pz.description) AS source_description,
    COALESCE(mr.default_formula_dsl, linked_pz.formula_dsl) AS source_formula_dsl,
    -- Linked source info
    CASE WHEN pz.linked_publisher_zman_id IS NOT NULL THEN true ELSE false END AS is_linked,
    linked_pub.name AS linked_source_publisher_name
FROM publisher_zmanim pz
LEFT JOIN publisher_zmanim linked_pz ON pz.linked_publisher_zman_id = linked_pz.id
LEFT JOIN publishers linked_pub ON linked_pz.publisher_id = linked_pub.id
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id
WHERE pz.publisher_id = $1 AND pz.zman_key = $2 AND pz.deleted_at IS NULL;

-- name: CreatePublisherZman :one
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_beta, is_custom, category,
    dependencies, sort_order, master_zman_id, linked_publisher_zman_id, source_type
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
)
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_beta, is_custom, category,
    dependencies, sort_order, master_zman_id, linked_publisher_zman_id, source_type,
    created_at, updated_at;

-- name: UpdatePublisherZman :one
UPDATE publisher_zmanim
SET hebrew_name = COALESCE(sqlc.narg('hebrew_name'), hebrew_name),
    english_name = COALESCE(sqlc.narg('english_name'), english_name),
    transliteration = COALESCE(sqlc.narg('transliteration'), transliteration),
    description = COALESCE(sqlc.narg('description'), description),
    formula_dsl = COALESCE(sqlc.narg('formula_dsl'), formula_dsl),
    ai_explanation = COALESCE(sqlc.narg('ai_explanation'), ai_explanation),
    publisher_comment = COALESCE(sqlc.narg('publisher_comment'), publisher_comment),
    is_enabled = COALESCE(sqlc.narg('is_enabled'), is_enabled),
    is_visible = COALESCE(sqlc.narg('is_visible'), is_visible),
    is_published = COALESCE(sqlc.narg('is_published'), is_published),
    is_beta = COALESCE(sqlc.narg('is_beta'), is_beta),
    certified_at = CASE
        WHEN sqlc.narg('is_beta')::boolean = false AND is_beta = true THEN NOW()
        ELSE certified_at
    END,
    category = COALESCE(sqlc.narg('category'), category),
    sort_order = COALESCE(sqlc.narg('sort_order'), sort_order),
    dependencies = COALESCE(sqlc.narg('dependencies'), dependencies),
    updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = $2
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    transliteration, description, formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_beta, is_custom, category,
    dependencies, sort_order, created_at, updated_at;

-- name: DeletePublisherZman :one
DELETE FROM publisher_zmanim
WHERE publisher_id = $1 AND zman_key = $2 AND is_custom = true
RETURNING id;

-- name: CountPublisherZmanim :one
SELECT COUNT(*) FROM publisher_zmanim WHERE publisher_id = $1;

-- Zmanim Templates --

-- name: GetZmanimTemplates :many
SELECT
    id, zman_key, hebrew_name, english_name, formula_dsl,
    category, description, is_required, sort_order,
    created_at, updated_at
FROM zmanim_templates
ORDER BY category, sort_order, hebrew_name;

-- name: GetZmanimTemplateByKey :one
SELECT
    id, zman_key, hebrew_name, english_name, formula_dsl,
    category, description, is_required, sort_order,
    created_at, updated_at
FROM zmanim_templates
WHERE zman_key = $1;

-- name: GetZmanimTemplatesByKeys :many
SELECT
    id, zman_key, hebrew_name, english_name, formula_dsl,
    category, description, is_required, sort_order,
    created_at, updated_at
FROM zmanim_templates
WHERE zman_key = ANY($1::text[]);

-- Import from templates to publisher --

-- name: ImportZmanimFromTemplates :many
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order
)
SELECT
    gen_random_uuid(), $1, zman_key, hebrew_name, english_name,
    formula_dsl, NULL, NULL,
    true, true, false, false, category,
    '{}', sort_order
FROM zmanim_templates
ON CONFLICT (publisher_id, zman_key) DO NOTHING
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at;

-- name: ImportZmanimFromTemplatesByKeys :many
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order
)
SELECT
    gen_random_uuid(), $1, zman_key, hebrew_name, english_name,
    formula_dsl, NULL, NULL,
    true, true, false, false, category,
    '{}', sort_order
FROM zmanim_templates
WHERE zman_key = ANY($2::text[])
ON CONFLICT (publisher_id, zman_key) DO NOTHING
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at;

-- Browse public zmanim --

-- name: BrowsePublicZmanim :many
SELECT
    z.id, z.publisher_id, z.zman_key, z.hebrew_name, z.english_name,
    z.formula_dsl, z.category,
    p.name as publisher_name,
    COUNT(*) OVER (PARTITION BY z.zman_key) as usage_count
FROM publisher_zmanim z
JOIN publishers p ON p.id = z.publisher_id
WHERE z.is_visible = true
  AND z.is_published = true
  AND ($1::text IS NULL OR z.hebrew_name ILIKE '%' || $1 || '%' OR z.english_name ILIKE '%' || $1 || '%')
  AND ($2::text IS NULL OR z.category = $2)
ORDER BY usage_count DESC, z.hebrew_name
LIMIT 50;

-- Bulk publish/unpublish zmanim --

-- name: PublishAllZmanim :exec
UPDATE publisher_zmanim
SET is_published = true, updated_at = NOW()
WHERE publisher_id = $1 AND is_enabled = true;

-- name: UnpublishAllZmanim :exec
UPDATE publisher_zmanim
SET is_published = false, updated_at = NOW()
WHERE publisher_id = $1;

-- name: PublishZmanimByKeys :exec
UPDATE publisher_zmanim
SET is_published = true, updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = ANY($2::text[]);

-- name: UnpublishZmanimByKeys :exec
UPDATE publisher_zmanim
SET is_published = false, updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = ANY($2::text[]);

-- Linked Zmanim Support --

-- name: GetVerifiedPublishersForLinking :many
-- Get verified publishers that current publisher can link to (excludes self)
SELECT
    p.id, p.name, p.logo_url,
    COUNT(pz.id) AS zmanim_count
FROM publishers p
JOIN publisher_zmanim pz ON pz.publisher_id = p.id
    AND pz.is_published = true
    AND pz.is_enabled = true
    AND pz.deleted_at IS NULL
WHERE p.is_verified = true
  AND p.status = 'active'
  AND p.id != $1  -- Exclude self
GROUP BY p.id, p.name, p.logo_url
HAVING COUNT(pz.id) > 0
ORDER BY p.name;

-- name: GetPublisherZmanimForLinking :many
-- Get published zmanim from a specific publisher for copying/linking
SELECT
    pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
    pz.formula_dsl, pz.category, pz.source_type,
    p.name AS publisher_name
FROM publisher_zmanim pz
JOIN publishers p ON p.id = pz.publisher_id
WHERE pz.publisher_id = $1
  AND pz.is_published = true
  AND pz.is_enabled = true
  AND pz.deleted_at IS NULL
  AND ($2::text IS NULL OR pz.zman_key NOT IN (
      SELECT zman_key FROM publisher_zmanim WHERE publisher_id = $2 AND deleted_at IS NULL
  ))
ORDER BY pz.sort_order, pz.hebrew_name;

-- name: GetPublisherZmanByID :one
-- Get a specific zman by ID (for linking validation)
SELECT
    pz.id, pz.publisher_id, pz.zman_key, pz.hebrew_name, pz.english_name,
    pz.formula_dsl, pz.ai_explanation, pz.publisher_comment,
    pz.is_enabled, pz.is_visible, pz.is_published, pz.is_custom, pz.category,
    pz.dependencies, pz.sort_order, pz.master_zman_id, pz.linked_publisher_zman_id,
    pz.source_type, pz.deleted_at, pz.created_at, pz.updated_at,
    p.name AS publisher_name,
    p.is_verified AS publisher_is_verified
FROM publisher_zmanim pz
JOIN publishers p ON p.id = pz.publisher_id
WHERE pz.id = $1;
