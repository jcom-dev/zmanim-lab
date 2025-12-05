-- Admin SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- Admin Publisher Management --

-- name: AdminListPublishers :many
SELECT id, clerk_user_id, name, email, status, created_at, updated_at
FROM publishers
WHERE ($1::text IS NULL OR status = $1)
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: AdminCountPublishers :one
SELECT COUNT(*)
FROM publishers
WHERE ($1::text IS NULL OR status = $1);

-- name: AdminGetPublisher :one
SELECT id, clerk_user_id, name, email, description, bio,
       website, logo_url, status, created_at, updated_at
FROM publishers
WHERE id = $1;

-- name: AdminUpdatePublisherStatus :one
UPDATE publishers
SET status = $2, updated_at = NOW()
WHERE id = $1
RETURNING id, status;

-- name: AdminDeletePublisher :exec
DELETE FROM publishers WHERE id = $1;

-- Admin Statistics --

-- name: AdminGetStatistics :one
SELECT
    (SELECT COUNT(*) FROM publishers) as total_publishers,
    (SELECT COUNT(*) FROM publishers WHERE status = 'active') as active_publishers,
    (SELECT COUNT(*) FROM publishers WHERE status = 'pending') as pending_publishers,
    (SELECT COUNT(*) FROM algorithms WHERE status = 'published') as published_algorithms,
    (SELECT COUNT(*) FROM geo_cities) as total_cities,
    (SELECT COUNT(*) FROM publisher_coverage WHERE is_active = true) as active_coverage_areas;

-- Admin Algorithm Management --

-- name: AdminListAlgorithms :many
SELECT
    a.id, a.publisher_id, a.name, a.status, a.is_public,
    a.created_at, a.updated_at,
    p.name as publisher_name
FROM algorithms a
JOIN publishers p ON a.publisher_id = p.id
WHERE ($1::text IS NULL OR a.status = $1)
ORDER BY a.updated_at DESC
LIMIT $2 OFFSET $3;

-- name: AdminCountAlgorithms :one
SELECT COUNT(*)
FROM algorithms
WHERE ($1::text IS NULL OR status = $1);

-- Publisher Invitations --
-- Schema: id, publisher_id, email, role, token, expires_at, created_at

-- name: GetPendingInvitations :many
SELECT id, email, role, expires_at, created_at
FROM publisher_invitations
WHERE publisher_id = $1 AND expires_at > NOW()
ORDER BY created_at DESC;

-- name: GetExpiredInvitations :many
SELECT id, email, role, expires_at, created_at
FROM publisher_invitations
WHERE publisher_id = $1 AND expires_at <= NOW()
ORDER BY created_at DESC;

-- name: GetInvitationByToken :one
SELECT pi.id, pi.publisher_id, pi.email, pi.role, pi.expires_at, p.name as publisher_name
FROM publisher_invitations pi
JOIN publishers p ON pi.publisher_id = p.id
WHERE pi.token = $1 AND pi.expires_at > NOW();

-- name: CreateInvitation :one
INSERT INTO publisher_invitations (publisher_id, email, role, token, expires_at)
VALUES ($1, $2, $3, $4, $5)
RETURNING id;

-- name: UpdateInvitationToken :exec
UPDATE publisher_invitations
SET token = $1, expires_at = $2
WHERE id = $3;

-- name: DeleteInvitation :exec
DELETE FROM publisher_invitations
WHERE id = $1;

-- name: DeleteExpiredInvitations :exec
DELETE FROM publisher_invitations
WHERE publisher_id = $1 AND expires_at <= NOW();

-- name: CountPendingInvitationsForEmail :one
SELECT COUNT(*)
FROM publisher_invitations
WHERE publisher_id = $1 AND LOWER(email) = LOWER($2) AND expires_at > NOW();

-- Team Management --

-- name: GetPublisherOwner :one
SELECT clerk_user_id FROM publishers WHERE id = $1;
