-- Cities SQL Queries (Normalized Schema)
-- SQLc will generate type-safe Go code from these queries
-- Uses JOINs to geo_continents, geo_countries, and geo_regions lookup tables

-- name: SearchCities :many
SELECT
    c.id, c.name, c.hebrew_name, c.name_ascii,
    co.code as country_code, co.name as country,
    r.name as region, r.code as region_code,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation, c.geonameid
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE 1=1
  AND ($1::text IS NULL OR ct.name = $1)
  AND ($2::text IS NULL OR co.code = $2)
  AND ($3::text IS NULL OR r.name = $3)
  AND ($4::text IS NULL OR c.name ILIKE '%' || $4 || '%')
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $5 OFFSET $6;

-- name: CountCities :one
SELECT COUNT(*)
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE 1=1
  AND ($1::text IS NULL OR ct.name = $1)
  AND ($2::text IS NULL OR co.code = $2)
  AND ($3::text IS NULL OR r.name = $3)
  AND ($4::text IS NULL OR c.name ILIKE '%' || $4 || '%');

-- name: GetCityByID :one
SELECT
    c.id, c.name, c.hebrew_name,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation, c.geonameid
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE c.id = $1;

-- name: GetCityByName :one
SELECT
    c.id, c.name, c.hebrew_name,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation, c.geonameid
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE c.name = $1
LIMIT 1;

-- name: ListCitiesByCountry :many
SELECT
    c.id, c.name, c.hebrew_name,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation, c.geonameid
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE co.code = $1
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $2;

-- name: ListCitiesByRegion :many
SELECT
    c.id, c.name, c.hebrew_name,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation, c.geonameid
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
JOIN geo_regions r ON c.region_id = r.id
WHERE co.code = $1 AND r.name = $2
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $3;

-- name: ListCitiesByContinent :many
SELECT
    c.id, c.name, c.hebrew_name,
    co.code as country_code, co.name as country,
    r.name as region,
    ct.name as continent,
    c.latitude, c.longitude, c.timezone,
    c.population, c.elevation, c.geonameid
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE ct.name = $1
ORDER BY c.population DESC NULLS LAST, c.name
LIMIT $2 OFFSET $3;

-- name: GetContinents :many
SELECT ct.id, ct.code, ct.name, COUNT(c.id) as city_count
FROM geo_continents ct
LEFT JOIN geo_countries co ON co.continent_id = ct.id
LEFT JOIN cities c ON c.country_id = co.id
GROUP BY ct.id, ct.code, ct.name
ORDER BY ct.name;

-- name: GetCountries :many
SELECT co.id, co.code as country_code, co.name as country
FROM geo_countries co
ORDER BY co.name;

-- name: GetCountriesByContinent :many
SELECT co.id, co.code as country_code, co.name as country, COUNT(c.id) as city_count
FROM geo_countries co
JOIN geo_continents ct ON co.continent_id = ct.id
LEFT JOIN cities c ON c.country_id = co.id
WHERE ct.name = $1
GROUP BY co.id, co.code, co.name
ORDER BY co.name;

-- name: GetRegionsByCountry :many
SELECT r.id, r.code, r.name
FROM geo_regions r
JOIN geo_countries co ON r.country_id = co.id
WHERE co.code = $1
ORDER BY r.name;

-- name: GetCitiesForCoverage :many
SELECT
    c.id, c.name,
    co.code as country_code, co.name as country,
    r.name as region,
    c.latitude, c.longitude, c.timezone, c.elevation
FROM cities c
JOIN geo_countries co ON c.country_id = co.id
LEFT JOIN geo_regions r ON c.region_id = r.id
WHERE co.code = $1
  AND ($2::text IS NULL OR r.name = $2)
ORDER BY c.name;

-- name: DeleteAllCities :exec
DELETE FROM cities;

-- Lookup table queries for seeding

-- name: GetCountryByCode :one
SELECT id, code, name, continent_id
FROM geo_countries
WHERE code = $1;

-- name: GetRegionByCountryAndCode :one
SELECT r.id, r.country_id, r.code, r.name
FROM geo_regions r
JOIN geo_countries co ON r.country_id = co.id
WHERE co.code = $1 AND r.code = $2;

-- name: InsertCountry :one
INSERT INTO geo_countries (code, name, continent_id)
VALUES ($1, $2, $3)
RETURNING id;

-- name: InsertRegion :one
INSERT INTO geo_regions (country_id, code, name)
VALUES ($1, $2, $3)
RETURNING id;

-- name: UpdateCityFKs :exec
UPDATE cities
SET country_id = $2, region_id = $3
WHERE id = $1;
