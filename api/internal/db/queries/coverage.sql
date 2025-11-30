-- Coverage SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- name: GetPublisherCoverage :many
SELECT id, publisher_id, coverage_level, country_code, region, city_id,
       priority, is_active, created_at, updated_at
FROM publisher_coverage
WHERE publisher_id = $1 AND is_active = true
ORDER BY priority DESC, created_at DESC;

-- name: GetPublisherCoverageByID :one
SELECT id, publisher_id, coverage_level, country_code, region, city_id,
       priority, is_active, created_at, updated_at
FROM publisher_coverage
WHERE id = $1;

-- name: CreateCoverage :one
INSERT INTO publisher_coverage (publisher_id, coverage_level, country_code, region, city_id, priority, is_active)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, publisher_id, coverage_level, country_code, region, city_id,
          priority, is_active, created_at, updated_at;

-- name: UpdateCoverage :one
UPDATE publisher_coverage
SET coverage_level = COALESCE(sqlc.narg('coverage_level'), coverage_level),
    country_code = COALESCE(sqlc.narg('country_code'), country_code),
    region = COALESCE(sqlc.narg('region'), region),
    city_id = COALESCE(sqlc.narg('city_id'), city_id),
    priority = COALESCE(sqlc.narg('priority'), priority),
    is_active = COALESCE(sqlc.narg('is_active'), is_active),
    updated_at = NOW()
WHERE id = $1
RETURNING id, publisher_id, coverage_level, country_code, region, city_id,
          priority, is_active, created_at, updated_at;

-- name: DeleteCoverage :exec
DELETE FROM publisher_coverage
WHERE id = $1;

-- name: DeleteCoverageByPublisher :exec
DELETE FROM publisher_coverage
WHERE publisher_id = $1;

-- name: GetCoverageCountByPublisher :one
SELECT COUNT(*)
FROM publisher_coverage
WHERE publisher_id = $1 AND is_active = true;

-- name: GetCitiesCoveredCount :one
SELECT COALESCE(SUM(
    CASE coverage_level
        WHEN 'city' THEN 1
        WHEN 'region' THEN (SELECT COUNT(*) FROM cities c WHERE c.region = pc.region AND c.country_code = pc.country_code)
        WHEN 'country' THEN (SELECT COUNT(*) FROM cities c WHERE c.country_code = pc.country_code)
        ELSE 0
    END
), 0)::int
FROM publisher_coverage pc
WHERE publisher_id = $1 AND is_active = true;
