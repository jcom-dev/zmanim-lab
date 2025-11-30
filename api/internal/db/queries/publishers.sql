-- Publishers SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- name: GetPublisherByID :one
SELECT id, clerk_user_id, name, organization, email, description, bio,
       website, logo_url, status, created_at, updated_at
FROM publishers
WHERE id = $1;

-- name: GetPublisherByClerkUserID :one
SELECT id
FROM publishers
WHERE clerk_user_id = $1;

-- name: GetPublisherFullByClerkUserID :one
SELECT id, clerk_user_id, name, organization, email, description, bio,
       website, logo_url, status, created_at, updated_at
FROM publishers
WHERE clerk_user_id = $1;

-- name: ListPublishers :many
SELECT id, name, organization, status, created_at
FROM publishers
WHERE ($1::text IS NULL OR region_id = $1)
ORDER BY name
LIMIT $2 OFFSET $3;

-- name: CountPublishers :one
SELECT COUNT(*)
FROM publishers
WHERE ($1::text IS NULL OR region_id = $1);

-- name: ListPublishersByIDs :many
SELECT id, name, organization, status
FROM publishers
WHERE id = ANY($1::text[])
ORDER BY name;

-- name: GetPublisherBasic :one
SELECT id, name, organization, status
FROM publishers
WHERE id = $1;

-- name: GetPublisherBasicByClerkUserID :one
SELECT id, name, organization, status
FROM publishers
WHERE clerk_user_id = $1;

-- name: UpdatePublisherProfile :one
UPDATE publishers
SET name = COALESCE(sqlc.narg('name'), name),
    organization = COALESCE(sqlc.narg('organization'), organization),
    email = COALESCE(sqlc.narg('email'), email),
    website = COALESCE(sqlc.narg('website'), website),
    bio = COALESCE(sqlc.narg('bio'), bio),
    updated_at = NOW()
WHERE id = $1
RETURNING id, clerk_user_id, name, organization, email, description, bio,
          website, logo_url, status, created_at, updated_at;

-- name: UpdatePublisherProfileByClerkUserID :one
UPDATE publishers
SET name = COALESCE(sqlc.narg('name'), name),
    organization = COALESCE(sqlc.narg('organization'), organization),
    email = COALESCE(sqlc.narg('email'), email),
    website = COALESCE(sqlc.narg('website'), website),
    bio = COALESCE(sqlc.narg('bio'), bio),
    updated_at = NOW()
WHERE clerk_user_id = $1
RETURNING id, clerk_user_id, name, organization, email, description, bio,
          website, logo_url, status, created_at, updated_at;

-- name: CreatePublisher :one
INSERT INTO publishers (name, organization, email, status, clerk_user_id)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, clerk_user_id, name, organization, email, description, bio,
          website, logo_url, status, created_at, updated_at;

-- name: UpdatePublisherStatus :one
UPDATE publishers
SET status = $2, updated_at = NOW()
WHERE id = $1
RETURNING id, clerk_user_id, name, organization, email, description, bio,
          website, logo_url, status, created_at, updated_at;

-- name: UpdatePublisherLogo :one
UPDATE publishers
SET logo_url = $2, updated_at = NOW()
WHERE id = $1
RETURNING id, logo_url;

-- name: DeletePublisher :exec
DELETE FROM publishers
WHERE id = $1;

-- name: GetPublisherDashboardSummary :one
SELECT
    p.name,
    p.organization,
    p.status = 'verified' as is_verified,
    p.status
FROM publishers p
WHERE p.id = $1;

-- name: GetPublisherAlgorithmSummary :one
SELECT
    CASE WHEN is_active THEN 'published' ELSE 'draft' END as status,
    name,
    TO_CHAR(updated_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') as updated_at
FROM algorithms
WHERE publisher_id = $1
ORDER BY updated_at DESC
LIMIT 1;

-- name: GetPublisherCoverageCount :one
SELECT COUNT(*)
FROM publisher_coverage
WHERE publisher_id = $1 AND is_active = true;
