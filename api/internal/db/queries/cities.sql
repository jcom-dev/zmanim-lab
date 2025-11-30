-- Cities SQL Queries
-- SQLc will generate type-safe Go code from these queries

-- name: SearchCities :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent, geonameid
FROM cities
WHERE 1=1
  AND ($1::text IS NULL OR continent = $1)
  AND ($2::text IS NULL OR country_code = $2)
  AND ($3::text IS NULL OR region = $3)
  AND ($4::text IS NULL OR name ILIKE '%' || $4 || '%')
ORDER BY population DESC NULLS LAST, name
LIMIT $5 OFFSET $6;

-- name: CountCities :one
SELECT COUNT(*)
FROM cities
WHERE 1=1
  AND ($1::text IS NULL OR continent = $1)
  AND ($2::text IS NULL OR country_code = $2)
  AND ($3::text IS NULL OR region = $3)
  AND ($4::text IS NULL OR name ILIKE '%' || $4 || '%');

-- name: GetCityByID :one
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent, geonameid
FROM cities
WHERE id = $1;

-- name: GetCityByName :one
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent, geonameid
FROM cities
WHERE name = $1
LIMIT 1;

-- name: ListCitiesByCountry :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent, geonameid
FROM cities
WHERE country_code = $1
ORDER BY population DESC NULLS LAST, name
LIMIT $2;

-- name: ListCitiesByRegion :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent, geonameid
FROM cities
WHERE country_code = $1 AND region = $2
ORDER BY population DESC NULLS LAST, name
LIMIT $3;

-- name: ListCitiesByContinent :many
SELECT id, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent, geonameid
FROM cities
WHERE continent = $1
ORDER BY population DESC NULLS LAST, name
LIMIT $2 OFFSET $3;

-- name: GetContinents :many
SELECT DISTINCT continent, COUNT(*) as city_count
FROM cities
WHERE continent IS NOT NULL AND continent != ''
GROUP BY continent
ORDER BY continent;

-- name: GetCountries :many
SELECT DISTINCT country_code, country
FROM cities
ORDER BY country;

-- name: GetCountriesByContinent :many
SELECT DISTINCT country_code, country, COUNT(*) as city_count
FROM cities
WHERE continent = $1
GROUP BY country_code, country
ORDER BY country;

-- name: GetRegionsByCountry :many
SELECT DISTINCT region
FROM cities
WHERE country_code = $1 AND region IS NOT NULL AND region != ''
ORDER BY region;

-- name: GetCitiesForCoverage :many
SELECT DISTINCT c.id, c.name, c.country, c.country_code, c.region, c.latitude, c.longitude, c.timezone, c.elevation
FROM cities c
WHERE c.country_code = $1
  AND ($2::text IS NULL OR c.region = $2)
ORDER BY c.name;

-- name: UpsertCityByGeonameid :exec
INSERT INTO cities (geonameid, name, country, country_code, region, latitude, longitude, timezone, population, elevation, continent)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
ON CONFLICT (geonameid) WHERE geonameid IS NOT NULL
DO UPDATE SET
  name = EXCLUDED.name,
  country = EXCLUDED.country,
  country_code = EXCLUDED.country_code,
  region = EXCLUDED.region,
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  timezone = EXCLUDED.timezone,
  population = EXCLUDED.population,
  elevation = EXCLUDED.elevation,
  continent = EXCLUDED.continent;

-- name: DeleteAllCities :exec
DELETE FROM cities;
