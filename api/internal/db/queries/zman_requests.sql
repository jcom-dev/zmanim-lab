-- Zman Request Queries
-- Epic 5, Story 5.0: Enhanced Zman Registry Requests

-- name: CreateZmanRequest :one
-- Create a new zman request from a publisher
INSERT INTO zman_registry_requests (
    publisher_id,
    requested_key,
    requested_hebrew_name,
    requested_english_name,
    transliteration,
    requested_formula_dsl,
    time_category,
    description,
    halachic_notes,
    halachic_source,
    publisher_email,
    publisher_name,
    auto_add_on_approval
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
)
RETURNING id, publisher_id, requested_key, requested_hebrew_name, requested_english_name,
    transliteration, requested_formula_dsl, time_category, description,
    halachic_notes, halachic_source, publisher_email, publisher_name, auto_add_on_approval,
    status, created_at;

-- name: GetZmanRequest :one
-- Get a specific zman request by ID
SELECT
    zrr.id,
    zrr.publisher_id,
    zrr.requested_key,
    zrr.requested_hebrew_name,
    zrr.requested_english_name,
    zrr.transliteration,
    zrr.requested_formula_dsl,
    zrr.time_category,
    zrr.description,
    zrr.halachic_notes,
    zrr.halachic_source,
    zrr.publisher_email,
    zrr.publisher_name,
    zrr.auto_add_on_approval,
    zrr.status,
    zrr.reviewed_by,
    zrr.reviewed_at,
    zrr.reviewer_notes,
    zrr.created_at,
    p.name as submitter_name
FROM zman_registry_requests zrr
JOIN publishers p ON zrr.publisher_id = p.id
WHERE zrr.id = $1;

-- name: GetPublisherZmanRequests :many
-- Get all zman requests for a specific publisher
SELECT
    id,
    publisher_id,
    requested_key,
    requested_hebrew_name,
    requested_english_name,
    transliteration,
    time_category,
    status,
    reviewed_at,
    reviewer_notes,
    created_at
FROM zman_registry_requests
WHERE publisher_id = $1
ORDER BY created_at DESC;

-- name: GetAllZmanRequests :many
-- Get all zman requests (for admin) with optional status filter
SELECT
    zrr.id,
    zrr.publisher_id,
    zrr.requested_key,
    zrr.requested_hebrew_name,
    zrr.requested_english_name,
    zrr.transliteration,
    zrr.time_category,
    zrr.status,
    zrr.reviewed_by,
    zrr.reviewed_at,
    zrr.created_at,
    p.name as publisher_name
FROM zman_registry_requests zrr
JOIN publishers p ON zrr.publisher_id = p.id
WHERE ($1::text IS NULL OR zrr.status = $1)
ORDER BY
    CASE WHEN zrr.status = 'pending' THEN 0 ELSE 1 END,
    zrr.created_at DESC;

-- name: ApproveZmanRequest :one
-- Approve a zman request
UPDATE zman_registry_requests
SET
    status = 'approved',
    reviewed_by = $2,
    reviewed_at = NOW(),
    reviewer_notes = $3
WHERE id = $1
RETURNING id, status, reviewed_by, reviewed_at, reviewer_notes, auto_add_on_approval, publisher_id;

-- name: RejectZmanRequest :one
-- Reject a zman request
UPDATE zman_registry_requests
SET
    status = 'rejected',
    reviewed_by = $2,
    reviewed_at = NOW(),
    reviewer_notes = $3
WHERE id = $1
RETURNING id, status, reviewed_by, reviewed_at, reviewer_notes;

-- name: AddZmanRequestTag :one
-- Add an existing tag to a zman request
INSERT INTO zman_request_tags (
    request_id,
    tag_id,
    is_new_tag_request
) VALUES ($1, $2, false)
RETURNING id, request_id, tag_id, is_new_tag_request, created_at;

-- name: AddZmanRequestNewTag :one
-- Request a new tag for a zman request
INSERT INTO zman_request_tags (
    request_id,
    requested_tag_name,
    requested_tag_type,
    is_new_tag_request
) VALUES ($1, $2, $3, true)
RETURNING id, request_id, requested_tag_name, requested_tag_type, is_new_tag_request, created_at;

-- name: GetZmanRequestTags :many
-- Get all tags (existing and requested) for a zman request
SELECT
    zrt.id,
    zrt.request_id,
    zrt.tag_id,
    zrt.requested_tag_name,
    zrt.requested_tag_type,
    zrt.is_new_tag_request,
    zrt.created_at,
    zt.tag_key as existing_tag_key,
    zt.name as existing_tag_name,
    zt.tag_type as existing_tag_type
FROM zman_request_tags zrt
LEFT JOIN zman_tags zt ON zrt.tag_id = zt.id
WHERE zrt.request_id = $1;

-- name: DeleteZmanRequestTags :exec
-- Delete all tags for a zman request (used when updating request)
DELETE FROM zman_request_tags WHERE request_id = $1;

-- name: GetPendingZmanRequestCount :one
-- Get count of pending zman requests (for admin dashboard)
SELECT COUNT(*) as count
FROM zman_registry_requests
WHERE status = 'pending';

-- name: GetZmanRequestTag :one
-- Get a specific tag request by ID
SELECT
    zrt.id,
    zrt.request_id,
    zrt.tag_id,
    zrt.requested_tag_name,
    zrt.requested_tag_type,
    zrt.is_new_tag_request,
    zrt.created_at
FROM zman_request_tags zrt
WHERE zrt.id = $1;

-- name: ApproveTagRequest :one
-- Approve a new tag request - creates the tag and updates the request
-- Step 1: Create the new tag in zman_tags table
-- This query only creates the tag, the caller must update the request separately
INSERT INTO zman_tags (
    tag_key,
    name,
    display_name_hebrew,
    display_name_english,
    tag_type
) VALUES (
    $1, -- tag_key (generated from requested_tag_name)
    $2, -- name (requested_tag_name)
    $3, -- display_name_hebrew (same as name for now)
    $4, -- display_name_english (same as name)
    $5  -- tag_type (from requested_tag_type)
)
RETURNING id, tag_key, name, display_name_hebrew, display_name_english, tag_type, created_at;

-- name: LinkTagToRequest :exec
-- Update the tag request to link the newly created tag
-- Must also clear requested_tag_name to satisfy tag_reference_check constraint
UPDATE zman_request_tags
SET
    tag_id = $2,
    is_new_tag_request = false,
    requested_tag_name = NULL,
    requested_tag_type = NULL
WHERE id = $1;

-- name: FindTagByName :one
-- Find an existing tag by name (case-insensitive match)
SELECT id, tag_key, name, display_name_hebrew, display_name_english, tag_type, created_at
FROM zman_tags
WHERE LOWER(name) = LOWER($1)
LIMIT 1;

-- name: RejectTagRequest :exec
-- Reject a new tag request by deleting it from zman_request_tags
DELETE FROM zman_request_tags
WHERE id = $1 AND is_new_tag_request = true;

-- name: CreatePublisherZmanFromRequest :one
-- Create a publisher_zman entry from an approved zman request
-- This is used when auto_add_on_approval is true
INSERT INTO publisher_zmanim (
    id, publisher_id, zman_key, hebrew_name, english_name,
    transliteration, description,
    formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, current_version
)
SELECT
    gen_random_uuid() AS id,
    zrr.publisher_id AS publisher_id,
    zrr.requested_key AS zman_key,
    zrr.requested_hebrew_name AS hebrew_name,
    zrr.requested_english_name AS english_name,
    zrr.transliteration AS transliteration,
    zrr.description AS description,
    zrr.requested_formula_dsl AS formula_dsl,
    NULL AS ai_explanation,
    NULL AS publisher_comment,
    true AS is_enabled,
    true AS is_visible,
    false AS is_published,
    true AS is_custom,
    zrr.time_category AS category,
    '{}'::text[] AS dependencies,
    999 AS sort_order,
    1 AS current_version
FROM zman_registry_requests zrr
WHERE zrr.id = $1
ON CONFLICT (publisher_id, zman_key) DO NOTHING
RETURNING id, publisher_id, zman_key, hebrew_name, english_name,
    transliteration, description, formula_dsl, ai_explanation, publisher_comment,
    is_enabled, is_visible, is_published, is_custom, category,
    dependencies, sort_order, created_at, updated_at, current_version;
