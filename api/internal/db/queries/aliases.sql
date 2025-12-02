-- Alias CRUD Queries
-- Epic 5, Story 5.0: Publisher Zman Aliases

-- name: GetPublisherZmanAlias :one
-- Get a specific alias for a publisher's zman by zman_key
SELECT
    pza.id,
    pza.publisher_id,
    pza.publisher_zman_id,
    pza.custom_hebrew_name,
    pza.custom_english_name,
    pza.custom_transliteration,
    pza.is_active,
    pza.created_at,
    pza.updated_at,
    pz.zman_key,
    mzr.canonical_hebrew_name,
    mzr.canonical_english_name
FROM publisher_zman_aliases pza
JOIN publisher_zmanim pz ON pza.publisher_zman_id = pz.id
JOIN master_zmanim_registry mzr ON pz.zman_key = mzr.zman_key
WHERE pza.publisher_id = $1 AND pz.zman_key = $2 AND pza.is_active = true;

-- name: UpsertPublisherZmanAlias :one
-- Create or update an alias for a publisher's zman
INSERT INTO publisher_zman_aliases (
    publisher_id,
    publisher_zman_id,
    custom_hebrew_name,
    custom_english_name,
    custom_transliteration
)
SELECT $1, pz.id, $3, $4, $5
FROM publisher_zmanim pz
WHERE pz.publisher_id = $1 AND pz.zman_key = $2
ON CONFLICT (publisher_id, publisher_zman_id) DO UPDATE SET
    custom_hebrew_name = EXCLUDED.custom_hebrew_name,
    custom_english_name = EXCLUDED.custom_english_name,
    custom_transliteration = EXCLUDED.custom_transliteration,
    is_active = true,
    updated_at = NOW()
RETURNING id, publisher_id, publisher_zman_id, custom_hebrew_name, custom_english_name, custom_transliteration, is_active, created_at, updated_at;

-- name: DeletePublisherZmanAlias :exec
-- Delete an alias by publisher_id and zman_key
DELETE FROM publisher_zman_aliases pza
USING publisher_zmanim pz
WHERE pza.publisher_zman_id = pz.id
  AND pza.publisher_id = $1
  AND pz.zman_key = $2;

-- name: GetAllPublisherZmanAliases :many
-- Get all active aliases for a publisher with canonical names included
SELECT
    pza.id,
    pza.publisher_id,
    pza.publisher_zman_id,
    pza.custom_hebrew_name,
    pza.custom_english_name,
    pza.custom_transliteration,
    pza.is_active,
    pza.created_at,
    pza.updated_at,
    pz.zman_key,
    mzr.canonical_hebrew_name,
    mzr.canonical_english_name
FROM publisher_zman_aliases pza
JOIN publisher_zmanim pz ON pza.publisher_zman_id = pz.id
JOIN master_zmanim_registry mzr ON pz.zman_key = mzr.zman_key
WHERE pza.publisher_id = $1 AND pza.is_active = true
ORDER BY pz.sort_order;

-- name: GetZmanimWithAliases :many
-- Get all of a publisher's zmanim with their aliases (if any)
SELECT
    pz.id as publisher_zman_id,
    pz.zman_key,
    pz.formula_dsl,
    pz.is_enabled,
    pz.sort_order,
    mzr.canonical_hebrew_name,
    mzr.canonical_english_name,
    pza.id as alias_id,
    pza.custom_hebrew_name,
    pza.custom_english_name,
    pza.custom_transliteration
FROM publisher_zmanim pz
JOIN master_zmanim_registry mzr ON pz.zman_key = mzr.zman_key
LEFT JOIN publisher_zman_aliases pza ON pza.publisher_zman_id = pz.id AND pza.is_active = true
WHERE pz.publisher_id = $1 AND pz.is_enabled = true
ORDER BY pz.sort_order;
