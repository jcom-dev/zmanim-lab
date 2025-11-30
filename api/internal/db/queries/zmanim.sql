-- Zmanim SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- Publisher Zmanim --

-- name: GetPublisherZmanim :many
SELECT
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at
FROM publisher_zmanim
WHERE publisher_id = $1
ORDER BY sort_order, hebrew_name;

-- name: GetPublisherZmanByKey :one
SELECT
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at
FROM publisher_zmanim
WHERE publisher_id = $1 AND zman_key = $2;

-- name: CreatePublisherZman :one
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
)
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at;

-- name: UpdatePublisherZman :one
UPDATE publisher_zmanim
SET hebrew_name = COALESCE(sqlc.narg('hebrew_name'), hebrew_name),
    english_name = COALESCE(sqlc.narg('english_name'), english_name),
    formula_dsl = COALESCE(sqlc.narg('formula_dsl'), formula_dsl),
    ai_explanation = COALESCE(sqlc.narg('ai_explanation'), ai_explanation),
    publisher_comment = COALESCE(sqlc.narg('publisher_comment'), publisher_comment),
    is_enabled = COALESCE(sqlc.narg('is_enabled'), is_enabled),
    is_visible = COALESCE(sqlc.narg('is_visible'), is_visible),
    is_published = COALESCE(sqlc.narg('is_published'), is_published),
    category = COALESCE(sqlc.narg('category'), category),
    sort_order = COALESCE(sqlc.narg('sort_order'), sort_order),
    dependencies = COALESCE(sqlc.narg('dependencies'), dependencies),
    updated_at = NOW()
WHERE publisher_id = $1 AND zman_key = $2
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
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
