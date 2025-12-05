-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- CONTINENT AS ANCHOR FOR ALL LEVELS
-- ============================================================================
-- WOF has entities at all levels that may not have a full hierarchy chain.
-- For example, territories may have regions/districts without a proper country.
--
-- New model: continent_id is REQUIRED at all levels, everything else is optional
-- but must maintain referential integrity when set:
--   - geo_regions: continent_id required, country_id optional (if set, must belong to continent)
--   - geo_districts: continent_id required, country_id optional, region_id optional
--   - cities: continent_id required, country_id optional, region_id optional, district_id optional

-- ============================================================================
-- GEO_REGIONS: Add continent_id, make country_id nullable
-- ============================================================================

-- Add continent_id to geo_regions
ALTER TABLE geo_regions ADD COLUMN IF NOT EXISTS continent_id smallint REFERENCES geo_continents(id);

-- Populate continent_id from existing country relationships
UPDATE geo_regions r
SET continent_id = c.continent_id
FROM geo_countries c
WHERE r.country_id = c.id AND r.continent_id IS NULL;

-- Make continent_id NOT NULL (all regions must have a continent)
-- Skip if already NOT NULL
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'geo_regions' AND column_name = 'continent_id' AND is_nullable = 'YES'
    ) THEN
        -- First ensure all rows have a value
        UPDATE geo_regions SET continent_id = 1 WHERE continent_id IS NULL;
        ALTER TABLE geo_regions ALTER COLUMN continent_id SET NOT NULL;
    END IF;
END $$;

-- Make country_id nullable (some regions belong directly to continent)
ALTER TABLE geo_regions ALTER COLUMN country_id DROP NOT NULL;

-- Add index for continent lookups
CREATE INDEX IF NOT EXISTS idx_geo_regions_continent ON geo_regions(continent_id);

COMMENT ON COLUMN geo_regions.continent_id IS 'Continent is required - every region belongs to exactly one continent (anchor point)';
COMMENT ON COLUMN geo_regions.country_id IS 'Country is optional - some WOF regions link directly to continent (territories). If set, must belong to continent_id';

-- ============================================================================
-- GEO_DISTRICTS: Add continent_id + country_id, make region_id nullable
-- ============================================================================

-- Add continent_id to geo_districts
ALTER TABLE geo_districts ADD COLUMN IF NOT EXISTS continent_id smallint REFERENCES geo_continents(id);

-- Add country_id to geo_districts (optional)
ALTER TABLE geo_districts ADD COLUMN IF NOT EXISTS country_id smallint REFERENCES geo_countries(id);

-- Populate continent_id and country_id from existing region relationships
UPDATE geo_districts d
SET
    continent_id = r.continent_id,
    country_id = r.country_id
FROM geo_regions r
WHERE d.region_id = r.id AND d.continent_id IS NULL;

-- Make continent_id NOT NULL (all districts must have a continent)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'geo_districts' AND column_name = 'continent_id' AND is_nullable = 'YES'
    ) THEN
        -- First ensure all rows have a value
        UPDATE geo_districts SET continent_id = 1 WHERE continent_id IS NULL;
        ALTER TABLE geo_districts ALTER COLUMN continent_id SET NOT NULL;
    END IF;
END $$;

-- Make region_id nullable (some districts belong directly to country or continent)
ALTER TABLE geo_districts ALTER COLUMN region_id DROP NOT NULL;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_geo_districts_continent ON geo_districts(continent_id);
CREATE INDEX IF NOT EXISTS idx_geo_districts_country ON geo_districts(country_id);

COMMENT ON COLUMN geo_districts.continent_id IS 'Continent is required - every district belongs to exactly one continent (anchor point)';
COMMENT ON COLUMN geo_districts.country_id IS 'Country is optional - some WOF districts link directly to continent. If set, must belong to continent_id';
COMMENT ON COLUMN geo_districts.region_id IS 'Region is optional - requires country_id. If set, must belong to country_id';

-- ============================================================================
-- TRIGGER: Validate geo_regions hierarchy
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_region_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    country_continent_id smallint;
BEGIN
    -- If country_id is set, verify it belongs to the region's continent
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

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_region_hierarchy ON geo_regions;
CREATE TRIGGER trg_validate_region_hierarchy
    BEFORE INSERT OR UPDATE ON geo_regions
    FOR EACH ROW
    EXECUTE FUNCTION validate_region_hierarchy();

-- ============================================================================
-- TRIGGER: Validate geo_districts hierarchy
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_district_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    country_continent_id smallint;
    region_country_id smallint;
BEGIN
    -- If country_id is set, verify it belongs to the district's continent
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

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_district_hierarchy ON geo_districts;
CREATE TRIGGER trg_validate_district_hierarchy
    BEFORE INSERT OR UPDATE ON geo_districts
    FOR EACH ROW
    EXECUTE FUNCTION validate_district_hierarchy();

-- ============================================================================
-- UPDATE: City hierarchy trigger (already has continent_id from migration 20)
-- Now update to handle region without country properly
-- ============================================================================

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

-- ============================================================================
-- VALIDATION FUNCTIONS: Check hierarchy integrity at all levels
-- ============================================================================

-- Validate regions
CREATE OR REPLACE FUNCTION validate_all_region_hierarchies()
RETURNS TABLE(region_id integer, region_name text, error_type text, details text) AS $$
BEGIN
    -- Find regions where country doesn't belong to region's continent
    RETURN QUERY
    SELECT r.id, r.name::text, 'country_continent_mismatch'::text,
           format('Country %s belongs to continent %s, not %s', r.country_id, c.continent_id, r.continent_id)
    FROM geo_regions r
    JOIN geo_countries c ON r.country_id = c.id
    WHERE r.country_id IS NOT NULL AND c.continent_id != r.continent_id;
END;
$$ LANGUAGE plpgsql;

-- Validate districts
CREATE OR REPLACE FUNCTION validate_all_district_hierarchies()
RETURNS TABLE(district_id integer, district_name text, error_type text, details text) AS $$
BEGIN
    -- Find districts where country doesn't belong to district's continent
    RETURN QUERY
    SELECT d.id, d.name::text, 'country_continent_mismatch'::text,
           format('Country %s belongs to continent %s, not %s', d.country_id, c.continent_id, d.continent_id)
    FROM geo_districts d
    JOIN geo_countries c ON d.country_id = c.id
    WHERE d.country_id IS NOT NULL AND c.continent_id != d.continent_id;

    -- Find districts where region doesn't belong to district's country
    RETURN QUERY
    SELECT d.id, d.name::text, 'region_country_mismatch'::text,
           format('Region %s belongs to country %s, not %s', d.region_id, r.country_id, d.country_id)
    FROM geo_districts d
    JOIN geo_regions r ON d.region_id = r.id
    WHERE d.region_id IS NOT NULL AND r.country_id != d.country_id;

    -- Find districts with region but no country
    RETURN QUERY
    SELECT d.id, d.name::text, 'region_without_country'::text,
           format('District has region_id %s but country_id is NULL', d.region_id)
    FROM geo_districts d
    WHERE d.region_id IS NOT NULL AND d.country_id IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Update city validation (add country_continent check)
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

-- +goose StatementEnd

-- +goose Down
-- Down migration intentionally left empty to prevent accidental data loss
-- To rollback, manually run the reverse operations
