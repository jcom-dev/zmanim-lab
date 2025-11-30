-- Cities SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- name: SearchCities :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population
FROM cities
WHERE 1=1
  AND ($1::text IS NULL OR country_code = $1)
  AND ($2::text IS NULL OR region = $2)
  AND ($3::text IS NULL OR name ILIKE '%' || $3 || '%')
ORDER BY population DESC NULLS LAST, name
LIMIT $4 OFFSET $5;

-- name: CountCities :one
SELECT COUNT(*)
FROM cities
WHERE 1=1
  AND ($1::text IS NULL OR country_code = $1)
  AND ($2::text IS NULL OR region = $2)
  AND ($3::text IS NULL OR name ILIKE '%' || $3 || '%');

-- name: GetCityByID :one
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population
FROM cities
WHERE id = $1;

-- name: GetCityByName :one
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population
FROM cities
WHERE name = $1
LIMIT 1;

-- name: ListCitiesByCountry :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population
FROM cities
WHERE country_code = $1
ORDER BY population DESC NULLS LAST, name
LIMIT $2;

-- name: ListCitiesByRegion :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population
FROM cities
WHERE country_code = $1 AND region = $2
ORDER BY population DESC NULLS LAST, name
LIMIT $3;

-- name: GetCountries :many
SELECT DISTINCT country_code, country
FROM cities
ORDER BY country;

-- name: GetRegionsByCountry :many
SELECT DISTINCT region
FROM cities
WHERE country_code = $1 AND region IS NOT NULL AND region != ''
ORDER BY region;

-- name: GetCitiesForCoverage :many
SELECT DISTINCT c.id, c.name, c.country, c.country_code, c.region, c.latitude, c.longitude, c.timezone
FROM cities c
WHERE c.country_code = $1
  AND ($2::text IS NULL OR c.region = $2)
ORDER BY c.name;
