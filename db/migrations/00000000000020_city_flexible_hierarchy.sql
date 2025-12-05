-- +goose Up
-- +goose StatementBegin

-- WOF has localities with flexible hierarchy:
-- - All cities MUST have a continent (required) - this is the anchor point
-- - Country is optional (some territories/dependencies link directly to continent)
-- - Region is optional (some cities link directly to country or continent)
-- - District is optional (and must belong to the city's region if set)
--
-- Hierarchy validation ensures:
-- - If country_id is set, it must belong to the city's continent
-- - If region_id is set, country_id must also be set and region must belong to that country
-- - If district_id is set, region_id must also be set and district must belong to that region

-- Add continent_id to cities (required - NOT NULL)
ALTER TABLE cities ADD COLUMN IF NOT EXISTS continent_id smallint REFERENCES geo_continents(id);

-- Re-add country_id to cities (optional - nullable)
ALTER TABLE cities ADD COLUMN IF NOT EXISTS country_id integer REFERENCES geo_countries(id);

-- Make region_id nullable (some cities link directly to country or continent)
ALTER TABLE cities ALTER COLUMN region_id DROP NOT NULL;

-- Populate continent_id from existing relationships (region -> country -> continent)
UPDATE cities c
SET continent_id = gc.continent_id
FROM geo_regions r
JOIN geo_countries gc ON r.country_id = gc.id
WHERE c.region_id = r.id AND c.continent_id IS NULL;

-- Populate country_id from existing region relationships
UPDATE cities c
SET country_id = r.country_id
FROM geo_regions r
WHERE c.region_id = r.id AND c.country_id IS NULL;

-- Now make continent_id NOT NULL (all cities must have a continent)
ALTER TABLE cities ALTER COLUMN continent_id SET NOT NULL;

-- Create trigger function to validate city hierarchy integrity
CREATE OR REPLACE FUNCTION validate_city_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    country_continent_id smallint;
    region_country_id integer;
    district_region_id integer;
BEGIN
    -- If country_id is set, verify it belongs to the city's continent
    IF NEW.country_id IS NOT NULL THEN
        SELECT continent_id INTO country_continent_id
        FROM geo_countries WHERE id = NEW.country_id;

        IF country_continent_id IS NULL THEN
            RAISE EXCEPTION 'Country % does not exist', NEW.country_id;
        END IF;

        IF country_continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Country % belongs to continent %, not continent %',
                NEW.country_id, country_continent_id, NEW.continent_id;
        END IF;
    END IF;

    -- If region_id is set, verify country is also set and region belongs to that country
    IF NEW.region_id IS NOT NULL THEN
        IF NEW.country_id IS NULL THEN
            RAISE EXCEPTION 'Cannot set region_id without country_id';
        END IF;

        SELECT country_id INTO region_country_id
        FROM geo_regions WHERE id = NEW.region_id;

        IF region_country_id IS NULL THEN
            RAISE EXCEPTION 'Region % does not exist', NEW.region_id;
        END IF;

        IF region_country_id != NEW.country_id THEN
            RAISE EXCEPTION 'Region % belongs to country %, not country %',
                NEW.region_id, region_country_id, NEW.country_id;
        END IF;
    END IF;

    -- If district_id is set, verify region is also set and district belongs to that region
    IF NEW.district_id IS NOT NULL THEN
        IF NEW.region_id IS NULL THEN
            RAISE EXCEPTION 'Cannot set district_id without region_id';
        END IF;

        SELECT region_id INTO district_region_id
        FROM geo_districts WHERE id = NEW.district_id;

        IF district_region_id IS NULL THEN
            RAISE EXCEPTION 'District % does not exist', NEW.district_id;
        END IF;

        IF district_region_id != NEW.region_id THEN
            RAISE EXCEPTION 'District % belongs to region %, not region %',
                NEW.district_id, district_region_id, NEW.region_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on cities table (fires on regular INSERT/UPDATE, not COPY)
-- For bulk imports, use validate_all_city_hierarchies() after COPY
DROP TRIGGER IF EXISTS trg_validate_city_hierarchy ON cities;
CREATE TRIGGER trg_validate_city_hierarchy
    BEFORE INSERT OR UPDATE ON cities
    FOR EACH ROW
    EXECUTE FUNCTION validate_city_hierarchy();

-- Function to validate all existing city hierarchies (call after bulk import)
CREATE OR REPLACE FUNCTION validate_all_city_hierarchies()
RETURNS TABLE(city_id bigint, city_name text, error_type text, details text) AS $$
BEGIN
    -- Find cities where country doesn't belong to city's continent
    RETURN QUERY
    SELECT c.id, c.name::text, 'country_continent_mismatch'::text,
           format('Country %s belongs to continent %s, not %s', c.country_id, gc.continent_id, c.continent_id)
    FROM cities c
    JOIN geo_countries gc ON c.country_id = gc.id
    WHERE c.country_id IS NOT NULL AND gc.continent_id != c.continent_id;

    -- Find cities where region doesn't belong to city's country
    RETURN QUERY
    SELECT c.id, c.name::text, 'region_country_mismatch'::text,
           format('Region %s belongs to country %s, not %s', c.region_id, r.country_id, c.country_id)
    FROM cities c
    JOIN geo_regions r ON c.region_id = r.id
    WHERE c.region_id IS NOT NULL AND r.country_id != c.country_id;

    -- Find cities where district doesn't belong to city's region
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_region_mismatch'::text,
           format('District %s belongs to region %s, not %s', c.district_id, d.region_id, c.region_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL AND d.region_id != c.region_id;

    -- Find cities with region but no country
    RETURN QUERY
    SELECT c.id, c.name::text, 'region_without_country'::text,
           format('City has region_id %s but country_id is NULL', c.region_id)
    FROM cities c
    WHERE c.region_id IS NOT NULL AND c.country_id IS NULL;

    -- Find cities with district but no region
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_without_region'::text,
           format('City has district_id %s but region_id is NULL', c.district_id)
    FROM cities c
    WHERE c.district_id IS NOT NULL AND c.region_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Add indexes for lookups
CREATE INDEX IF NOT EXISTS idx_cities_continent_id ON cities(continent_id);
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);

COMMENT ON COLUMN cities.continent_id IS 'Continent is required - every city belongs to exactly one continent (anchor point)';
COMMENT ON COLUMN cities.country_id IS 'Country is optional - some WOF localities link directly to continent. If set, must belong to continent_id';
COMMENT ON COLUMN cities.region_id IS 'Region is optional - requires country_id. If set, must belong to country_id';
COMMENT ON COLUMN cities.district_id IS 'District is optional - requires region_id. If set, must belong to region_id';

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Remove trigger and functions
DROP TRIGGER IF EXISTS trg_validate_city_hierarchy ON cities;
DROP FUNCTION IF EXISTS validate_city_hierarchy();
DROP FUNCTION IF EXISTS validate_all_city_hierarchies();

-- Remove columns and indexes
DROP INDEX IF EXISTS idx_cities_continent_id;
DROP INDEX IF EXISTS idx_cities_country_id;
ALTER TABLE cities DROP COLUMN IF EXISTS continent_id;
ALTER TABLE cities DROP COLUMN IF EXISTS country_id;

-- Make region_id NOT NULL again
DELETE FROM cities WHERE region_id IS NULL;
ALTER TABLE cities ALTER COLUMN region_id SET NOT NULL;

-- +goose StatementEnd
