-- Tag Events SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- ============================================================================
-- Tag Event Mappings
-- ============================================================================

-- name: GetTagEventMappings :many
-- Get all HebCal event mappings for tag matching
SELECT
    t.tag_key,
    m.hebcal_event_pattern AS pattern,
    m.priority
FROM tag_event_mappings m
JOIN zman_tags t ON t.id = m.tag_id
WHERE m.hebcal_event_pattern IS NOT NULL
ORDER BY m.priority DESC;

-- name: GetTagsForHebCalEvent :many
-- Get tags that match a specific HebCal event name using pattern matching
-- The pattern supports SQL LIKE wildcards (%)
SELECT DISTINCT
    t.id,
    t.tag_key,
    t.name,
    t.display_name_hebrew,
    t.display_name_english,
    t.tag_type,
    t.description,
    t.sort_order
FROM zman_tags t
JOIN tag_event_mappings m ON m.tag_id = t.id
WHERE m.hebcal_event_pattern IS NOT NULL
  AND (
    $1 LIKE m.hebcal_event_pattern OR
    m.hebcal_event_pattern LIKE $1 OR
    -- Handle wildcards: convert % to pattern matching
    $1 LIKE REPLACE(m.hebcal_event_pattern, '%', '')::text || '%' OR
    $1 LIKE '%' || REPLACE(m.hebcal_event_pattern, '%', '')::text
  )
ORDER BY m.priority DESC, t.sort_order;

-- name: GetTagsForHebrewDate :many
-- Get tags that match a specific Hebrew date (month and day)
SELECT DISTINCT
    t.id,
    t.tag_key,
    t.name,
    t.display_name_hebrew,
    t.display_name_english,
    t.tag_type,
    t.description,
    t.sort_order
FROM zman_tags t
JOIN tag_event_mappings m ON m.tag_id = t.id
WHERE m.hebrew_month = $1
  AND $2 BETWEEN m.hebrew_day_start AND COALESCE(m.hebrew_day_end, m.hebrew_day_start)
ORDER BY m.priority DESC, t.sort_order;

-- ============================================================================
-- All Tags Queries (with tag_key - extends master_registry.sql queries)
-- ============================================================================

-- name: GetAllTagsWithKey :many
-- Get all tags ordered by type and sort order (includes tag_key)
SELECT
    id,
    tag_key,
    name,
    display_name_hebrew,
    display_name_english,
    tag_type,
    description,
    color,
    sort_order
FROM zman_tags
ORDER BY
    CASE tag_type
        WHEN 'behavior' THEN 1
        WHEN 'event' THEN 2
        WHEN 'jewish_day' THEN 3
        WHEN 'timing' THEN 4
        WHEN 'shita' THEN 5
        WHEN 'calculation' THEN 6
        WHEN 'category' THEN 7
        ELSE 8
    END,
    sort_order,
    display_name_english;

-- name: GetJewishDayTags :many
-- Get all jewish_day type tags (for calendar filtering)
SELECT
    id,
    tag_key,
    name,
    display_name_hebrew,
    display_name_english,
    tag_type,
    description,
    color,
    sort_order
FROM zman_tags
WHERE tag_type = 'jewish_day'
ORDER BY sort_order, display_name_english;

-- name: GetTagByKey :one
-- Get a single tag by its key
SELECT
    id,
    tag_key,
    name,
    display_name_hebrew,
    display_name_english,
    tag_type,
    description,
    color,
    sort_order
FROM zman_tags
WHERE tag_key = $1;

-- name: GetTagsByKeys :many
-- Get multiple tags by their keys
SELECT
    id,
    tag_key,
    name,
    display_name_hebrew,
    display_name_english,
    tag_type,
    description,
    color,
    sort_order
FROM zman_tags
WHERE tag_key = ANY($1::text[])
ORDER BY sort_order, display_name_english;

-- ============================================================================
-- Tag Types Metadata
-- ============================================================================

-- name: GetTagTypes :many
-- Get all tag types with their styling
SELECT
    id,
    key,
    display_name_hebrew,
    display_name_english,
    color,
    sort_order
FROM tag_types
ORDER BY sort_order;

-- ============================================================================
-- Publisher Zmanim by Active Tags
-- ============================================================================

-- name: GetZmanimByActiveTags :many
-- Get publisher zmanim that have any of the specified tags (for calendar day filtering)
SELECT DISTINCT
    pz.id,
    pz.publisher_id,
    pz.zman_key,
    pz.hebrew_name,
    pz.english_name,
    pz.formula_dsl,
    pz.is_enabled,
    pz.is_published,
    pz.category
FROM publisher_zmanim pz
JOIN publisher_zman_tags pzt ON pzt.publisher_zman_id = pz.id
JOIN zman_tags t ON t.id = pzt.tag_id
WHERE pz.publisher_id = $1
  AND t.tag_key = ANY($2::text[])
  AND pz.deleted_at IS NULL
  AND pz.is_enabled = true
ORDER BY pz.hebrew_name;

-- name: GetMasterZmanimByTags :many
-- Get master registry zmanim that have any of the specified tags
SELECT DISTINCT
    mr.id,
    mr.zman_key,
    mr.canonical_hebrew_name,
    mr.canonical_english_name,
    mr.default_formula_dsl,
    mr.time_category,
    mr.is_core
FROM master_zmanim_registry mr
JOIN master_zman_tags mzt ON mzt.master_zman_id = mr.id
JOIN zman_tags t ON t.id = mzt.tag_id
WHERE t.tag_key = ANY($1::text[])
  AND mr.is_hidden = false
ORDER BY mr.canonical_hebrew_name;

-- name: CountTagsByType :many
-- Get count of tags per type (for UI display)
SELECT
    tag_type,
    COUNT(*) AS count
FROM zman_tags
GROUP BY tag_type
ORDER BY
    CASE tag_type
        WHEN 'behavior' THEN 1
        WHEN 'event' THEN 2
        WHEN 'jewish_day' THEN 3
        WHEN 'timing' THEN 4
        WHEN 'shita' THEN 5
        WHEN 'calculation' THEN 6
        WHEN 'category' THEN 7
        ELSE 8
    END;
