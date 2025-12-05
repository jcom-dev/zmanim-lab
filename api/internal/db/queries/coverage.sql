-- Coverage SQL Queries (5-Level Hierarchy)
-- Supports: continent, country, region, district, city

-- name: GetPublisherCoverage :many
SELECT
    pc.id, pc.publisher_id, pc.coverage_level,
    pc.continent_code, pc.country_id, pc.region_id, pc.district_id, pc.city_id,
    pc.priority, pc.is_active, pc.created_at, pc.updated_at,
    -- Resolved names
    ct.name as continent_name,
    co.code as country_code, co.name as country_name,
    r.code as region_code, r.name as region_name,
    d.code as district_code, d.name as district_name,
    c.name as city_name
FROM publisher_coverage pc
LEFT JOIN geo_continents ct ON pc.continent_code = ct.code
LEFT JOIN geo_countries co ON pc.country_id = co.id
LEFT JOIN geo_regions r ON pc.region_id = r.id
LEFT JOIN geo_districts d ON pc.district_id = d.id
LEFT JOIN cities c ON pc.city_id = c.id
WHERE pc.publisher_id = $1 AND pc.is_active = true
ORDER BY
    CASE pc.coverage_level
        WHEN 'continent' THEN 1
        WHEN 'country' THEN 2
        WHEN 'region' THEN 3
        WHEN 'district' THEN 4
        WHEN 'city' THEN 5
    END,
    pc.priority DESC, pc.created_at DESC;

-- name: GetPublisherCoverageByID :one
SELECT
    pc.id, pc.publisher_id, pc.coverage_level,
    pc.continent_code, pc.country_id, pc.region_id, pc.district_id, pc.city_id,
    pc.priority, pc.is_active, pc.created_at, pc.updated_at
FROM publisher_coverage pc
WHERE pc.id = $1;

-- name: CreateCoverageContinent :one
INSERT INTO publisher_coverage (publisher_id, coverage_level, continent_code, priority, is_active)
VALUES ($1, 'continent', $2, $3, $4)
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

-- name: CreateCoverageCountry :one
INSERT INTO publisher_coverage (publisher_id, coverage_level, country_id, priority, is_active)
VALUES ($1, 'country', $2, $3, $4)
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

-- name: CreateCoverageRegion :one
INSERT INTO publisher_coverage (publisher_id, coverage_level, region_id, priority, is_active)
VALUES ($1, 'region', $2, $3, $4)
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

-- name: CreateCoverageDistrict :one
INSERT INTO publisher_coverage (publisher_id, coverage_level, district_id, priority, is_active)
VALUES ($1, 'district', $2, $3, $4)
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

-- name: CreateCoverageCity :one
INSERT INTO publisher_coverage (publisher_id, coverage_level, city_id, priority, is_active)
VALUES ($1, 'city', $2, $3, $4)
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

-- name: UpdateCoveragePriority :one
UPDATE publisher_coverage
SET priority = $2, updated_at = NOW()
WHERE id = $1
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

-- name: UpdateCoverageActive :one
UPDATE publisher_coverage
SET is_active = $2, updated_at = NOW()
WHERE id = $1
RETURNING id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at;

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
-- Estimates the number of cities covered by a publisher's coverage areas
-- Note: country derived via city.region_id → region.country_id
SELECT COALESCE(SUM(
    CASE pc.coverage_level
        WHEN 'city' THEN 1
        WHEN 'district' THEN (
            SELECT COUNT(*) FROM cities c WHERE c.district_id = pc.district_id
        )
        WHEN 'region' THEN (
            SELECT COUNT(*) FROM cities c WHERE c.region_id = pc.region_id
        )
        WHEN 'country' THEN (
            SELECT COUNT(*) FROM cities c
            JOIN geo_regions r ON c.region_id = r.id
            WHERE r.country_id = pc.country_id
        )
        WHEN 'continent' THEN (
            SELECT COUNT(*) FROM cities c
            JOIN geo_regions r ON c.region_id = r.id
            JOIN geo_countries co ON r.country_id = co.id
            JOIN geo_continents ct ON co.continent_id = ct.id
            WHERE ct.code = pc.continent_code
        )
        ELSE 0
    END
), 0)::int
FROM publisher_coverage pc
WHERE pc.publisher_id = $1 AND pc.is_active = true;

-- ============================================================================
-- Publisher Lookup by Location
-- ============================================================================

-- name: GetPublishersForCity :many
-- Find publishers that cover a specific city (using the get_publishers_for_city function)
SELECT * FROM get_publishers_for_city($1);

-- name: GetPublishersByCountry :many
-- Find publishers with coverage in a specific country
-- Note: city country derived via city.region_id → region.country_id
SELECT DISTINCT
    p.id, p.name, p.slug, p.is_verified,
    pc.coverage_level, pc.priority
FROM publishers p
JOIN publisher_coverage pc ON p.id = pc.publisher_id
LEFT JOIN geo_countries co ON pc.country_id = co.id
LEFT JOIN geo_regions r ON pc.region_id = r.id
LEFT JOIN geo_districts d ON pc.district_id = d.id
LEFT JOIN cities c ON pc.city_id = c.id
LEFT JOIN geo_regions cr ON c.region_id = cr.id
WHERE p.status = 'active'
  AND pc.is_active = true
  AND (
    pc.country_id = $1
    OR r.country_id = $1
    OR (d.region_id IN (SELECT id FROM geo_regions WHERE country_id = $1))
    OR (cr.country_id = $1)
  )
ORDER BY pc.priority DESC, p.name;

-- name: GetPublishersByRegion :many
-- Find publishers with coverage in a specific region
SELECT DISTINCT
    p.id, p.name, p.slug, p.is_verified,
    pc.coverage_level, pc.priority
FROM publishers p
JOIN publisher_coverage pc ON p.id = pc.publisher_id
LEFT JOIN geo_districts d ON pc.district_id = d.id
LEFT JOIN cities c ON pc.city_id = c.id
WHERE p.status = 'active'
  AND pc.is_active = true
  AND (
    pc.region_id = $1
    OR d.region_id = $1
    OR c.region_id = $1
  )
ORDER BY pc.priority DESC, p.name;

-- ============================================================================
-- Coverage Validation
-- ============================================================================

-- name: CheckDuplicateCoverageContinent :one
SELECT EXISTS(
    SELECT 1 FROM publisher_coverage
    WHERE publisher_id = $1 AND coverage_level = 'continent' AND continent_code = $2
) as exists;

-- name: CheckDuplicateCoverageCountry :one
SELECT EXISTS(
    SELECT 1 FROM publisher_coverage
    WHERE publisher_id = $1 AND coverage_level = 'country' AND country_id = $2
) as exists;

-- name: CheckDuplicateCoverageRegion :one
SELECT EXISTS(
    SELECT 1 FROM publisher_coverage
    WHERE publisher_id = $1 AND coverage_level = 'region' AND region_id = $2
) as exists;

-- name: CheckDuplicateCoverageDistrict :one
SELECT EXISTS(
    SELECT 1 FROM publisher_coverage
    WHERE publisher_id = $1 AND coverage_level = 'district' AND district_id = $2
) as exists;

-- name: CheckDuplicateCoverageCity :one
SELECT EXISTS(
    SELECT 1 FROM publisher_coverage
    WHERE publisher_id = $1 AND coverage_level = 'city' AND city_id = $2
) as exists;
