-- Cities SQL Queries (5-Level Hierarchy)
-- Continent -> Country -> Region (ADM1) -> District (ADM2) -> City

-- name: SearchCities :many
-- Note: country derived via region (city.region_id → region.country_id)
SELECT
    c.id, c.name, c.name_local, c.name_ascii,
    co.code as country_code, co.name as country,
    r.name as region, r.code as region_code,
    d.name as district, d.code as district_code,
    ct.code as continent_code, ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_districts d ON c.district_id = d.id
WHERE 1=1
  AND ($1::text IS NULL OR ct.code = $1)
  AND ($2::text IS NULL OR co.code = $2)
  AND ($3::text IS NULL OR r.code = $3)
  AND ($4::text IS NULL OR c.name ILIKE '%' || $4 || '%')
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $5 OFFSET $6;

-- name: CountCities :one
SELECT COUNT(*)
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
WHERE 1=1
  AND ($1::text IS NULL OR ct.code = $1)
  AND ($2::text IS NULL OR co.code = $2)
  AND ($3::text IS NULL OR r.code = $3)
  AND ($4::text IS NULL OR c.name ILIKE '%' || $4 || '%');

-- name: GetCityByID :one
SELECT
    c.id, c.name, c.name_local, c.name_ascii,
    co.id as country_id, c.region_id, c.district_id,
    co.code as country_code, co.name as country,
    r.name as region, r.code as region_code,
    d.name as district, d.code as district_code,
    ct.code as continent_code, ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_districts d ON c.district_id = d.id
WHERE c.id = $1;

-- name: GetCityByName :one
SELECT
    c.id, c.name, c.name_local,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
WHERE c.name = $1
LIMIT 1;

-- name: ListCitiesByCountry :many
SELECT
    c.id, c.name, c.name_local,
    co.code as country_code, co.name as country,
    r.name as region,
    d.name as district,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_districts d ON c.district_id = d.id
WHERE co.code = $1
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $2;

-- name: ListCitiesByRegion :many
SELECT
    c.id, c.name, c.name_local,
    co.code as country_code, co.name as country,
    r.name as region, r.code as region_code,
    d.name as district,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_districts d ON c.district_id = d.id
WHERE r.id = $1
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $2;

-- name: ListCitiesByDistrict :many
SELECT
    c.id, c.name, c.name_local,
    co.code as country_code, co.name as country,
    r.name as region,
    d.name as district, d.code as district_code,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
JOIN geo_districts d ON c.district_id = d.id
WHERE d.id = $1
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $2;

-- name: ListCitiesByContinent :many
SELECT
    c.id, c.name, c.name_local,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation_m, c.geonameid
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
WHERE ct.code = $1
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $2 OFFSET $3;

-- ============================================================================
-- Continents
-- ============================================================================

-- name: GetContinents :many
SELECT ct.id, ct.code, ct.name, COUNT(c.id) as city_count
FROM geo_continents ct
LEFT JOIN geo_countries co ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON r.country_id = co.id
LEFT JOIN cities c ON c.region_id = r.id
GROUP BY ct.id, ct.code, ct.name
ORDER BY ct.name;

-- ============================================================================
-- Countries
-- ============================================================================

-- name: GetCountries :many
SELECT
    co.id, co.code as country_code, co.code_iso3, co.name as country, co.name_local,
    co.adm1_label, co.adm2_label, co.has_adm1, co.has_adm2, co.is_city_state,
    ct.code as continent_code, ct.name as continent
FROM geo_countries co
JOIN geo_continents ct ON co.continent_id = ct.id
ORDER BY co.name;

-- name: GetCountriesByContinent :many
SELECT
    co.id, co.code as country_code, co.name as country,
    co.adm1_label, co.adm2_label, co.has_adm1, co.has_adm2,
    COUNT(c.id) as city_count
FROM geo_countries co
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON r.country_id = co.id
LEFT JOIN cities c ON c.region_id = r.id
WHERE ct.code = $1
GROUP BY co.id, co.code, co.name, co.adm1_label, co.adm2_label, co.has_adm1, co.has_adm2
ORDER BY co.name;

-- name: GetCountryByCode :one
SELECT
    co.id, co.code, co.code_iso3, co.name, co.name_local,
    co.adm1_label, co.adm2_label, co.has_adm1, co.has_adm2, co.is_city_state,
    co.population, co.area_km2,
    ct.id as continent_id, ct.code as continent_code, ct.name as continent
FROM geo_countries co
JOIN geo_continents ct ON co.continent_id = ct.id
WHERE co.code = $1;

-- name: GetCountryByID :one
SELECT
    co.id, co.code, co.code_iso3, co.name, co.name_local,
    co.adm1_label, co.adm2_label, co.has_adm1, co.has_adm2, co.is_city_state,
    co.population, co.area_km2,
    ct.id as continent_id, ct.code as continent_code, ct.name as continent
FROM geo_countries co
JOIN geo_continents ct ON co.continent_id = ct.id
WHERE co.id = $1;

-- ============================================================================
-- Regions (ADM1)
-- ============================================================================

-- name: GetRegionsByCountry :many
SELECT r.id, r.code, r.name, r.name_local, r.population, r.area_km2
FROM geo_regions r
JOIN geo_countries co ON r.country_id = co.id
WHERE co.code = $1
ORDER BY r.name;

-- name: GetRegionsByCountryID :many
SELECT r.id, r.code, r.name, r.name_local, r.population, r.area_km2
FROM geo_regions r
WHERE r.country_id = $1
ORDER BY r.name;

-- name: GetRegionByID :one
SELECT
    r.id, r.code, r.name, r.name_local, r.population, r.area_km2,
    co.id as country_id, co.code as country_code, co.name as country
FROM geo_regions r
JOIN geo_countries co ON r.country_id = co.id
WHERE r.id = $1;

-- name: GetRegionByCountryAndCode :one
SELECT r.id, r.country_id, r.code, r.name, r.name_local
FROM geo_regions r
JOIN geo_countries co ON r.country_id = co.id
WHERE co.code = $1 AND r.code = $2;

-- ============================================================================
-- Districts (ADM2)
-- ============================================================================

-- name: GetDistrictsByRegion :many
SELECT d.id, d.code, d.name, d.name_local, d.population, d.area_km2
FROM geo_districts d
WHERE d.region_id = $1
ORDER BY d.name;

-- name: GetDistrictsByCountry :many
SELECT
    d.id, d.code, d.name, d.name_local, d.population, d.area_km2,
    r.id as region_id, r.code as region_code, r.name as region
FROM geo_districts d
JOIN geo_regions r ON d.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
WHERE co.code = $1
ORDER BY r.name, d.name;

-- name: GetDistrictByID :one
SELECT
    d.id, d.code, d.name, d.name_local, d.population, d.area_km2,
    r.id as region_id, r.code as region_code, r.name as region,
    co.id as country_id, co.code as country_code, co.name as country
FROM geo_districts d
JOIN geo_regions r ON d.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
WHERE d.id = $1;

-- name: GetDistrictByRegionAndCode :one
SELECT d.id, d.region_id, d.code, d.name, d.name_local
FROM geo_districts d
WHERE d.region_id = $1 AND d.code = $2;

-- ============================================================================
-- Insert/Update Operations
-- ============================================================================

-- name: InsertCountry :one
INSERT INTO geo_countries (code, code_iso3, name, name_local, continent_id, adm1_label, adm2_label, has_adm1, has_adm2, is_city_state)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING id;

-- name: InsertRegion :one
INSERT INTO geo_regions (country_id, code, name, name_local)
VALUES ($1, $2, $3, $4)
RETURNING id;

-- name: InsertDistrict :one
INSERT INTO geo_districts (region_id, code, name, name_local)
VALUES ($1, $2, $3, $4)
RETURNING id;

-- name: InsertCity :one
-- Note: country derived via region.country_id (not stored on city)
INSERT INTO cities (region_id, district_id, name, name_ascii, name_local, latitude, longitude, timezone, elevation_m, population, geonameid)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
RETURNING id;

-- name: UpsertCity :one
-- Note: country derived via region.country_id (not stored on city)
INSERT INTO cities (region_id, district_id, name, name_ascii, name_local, latitude, longitude, timezone, elevation_m, population, geonameid)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
ON CONFLICT (geonameid) DO UPDATE SET
    region_id = EXCLUDED.region_id,
    district_id = EXCLUDED.district_id,
    name = EXCLUDED.name,
    name_ascii = EXCLUDED.name_ascii,
    name_local = EXCLUDED.name_local,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    timezone = EXCLUDED.timezone,
    elevation_m = EXCLUDED.elevation_m,
    population = EXCLUDED.population,
    updated_at = now()
RETURNING id;

-- name: UpdateCityHierarchy :exec
-- Note: country derived via region.country_id (not stored on city)
UPDATE cities
SET region_id = $2, district_id = $3, updated_at = now()
WHERE id = $1;

-- name: DeleteAllCities :exec
DELETE FROM cities;

-- name: DeleteAllDistricts :exec
DELETE FROM geo_districts;

-- name: DeleteAllRegions :exec
DELETE FROM geo_regions;

-- name: DeleteAllCountries :exec
DELETE FROM geo_countries;

-- ============================================================================
-- Coverage Helpers
-- ============================================================================

-- name: GetCitiesForCoverage :many
SELECT
    c.id, c.name,
    co.code as country_code, co.name as country,
    r.name as region,
    d.name as district,
    c.latitude, c.longitude, c.timezone, c.elevation_m
FROM cities c
JOIN geo_regions r ON c.region_id = r.id
JOIN geo_countries co ON r.country_id = co.id
LEFT JOIN geo_districts d ON c.district_id = d.id
WHERE co.code = $1
  AND ($2::integer IS NULL OR r.id = $2)
  AND ($3::integer IS NULL OR d.id = $3)
ORDER BY c.name;
