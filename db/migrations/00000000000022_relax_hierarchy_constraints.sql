-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- RELAX HIERARCHY CONSTRAINTS
-- ============================================================================
-- WOF has regions/districts that don't belong to countries (e.g., territories,
-- disputed areas, maritime regions).
--
-- New rule: continent_id is REQUIRED everywhere. Everything else is optional
-- BUT if a parent level is set, it must have referential integrity:
--   - region with country_id: country must exist and belong to same continent
--   - district with region_id: region must exist (and if region has country, district.country must match)
--   - city with district_id: district must exist (etc.)
--
-- Key change: region_id WITHOUT country_id is now VALID (region might not have a country)

-- ============================================================================
-- TRIGGER: Validate geo_districts hierarchy (relaxed)
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_district_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    country_continent_id smallint;
    region_rec RECORD;
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

    -- If region_id is set, verify region exists and belongs to same continent
    -- If region has a country, district must have the same country (or NULL)
    IF NEW.region_id IS NOT NULL THEN
        SELECT continent_id, country_id INTO region_rec
        FROM geo_regions WHERE id = NEW.region_id;

        IF region_rec IS NULL THEN
            RAISE EXCEPTION 'Region % does not exist', NEW.region_id;
        END IF;

        IF region_rec.continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Region % belongs to continent %, not continent %',
                NEW.region_id, region_rec.continent_id, NEW.continent_id;
        END IF;

        -- If region has a country, district must have same country
        IF region_rec.country_id IS NOT NULL THEN
            IF NEW.country_id IS NULL THEN
                RAISE EXCEPTION 'Region % has country %, district must have same country_id',
                    NEW.region_id, region_rec.country_id;
            ELSIF NEW.country_id != region_rec.country_id THEN
                RAISE EXCEPTION 'Region % belongs to country %, not country %',
                    NEW.region_id, region_rec.country_id, NEW.country_id;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER: Validate cities hierarchy (relaxed)
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_city_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    country_continent_id smallint;
    region_rec RECORD;
    district_rec RECORD;
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

    -- If region_id is set, verify region exists and belongs to same continent
    IF NEW.region_id IS NOT NULL THEN
        SELECT continent_id, country_id INTO region_rec
        FROM geo_regions WHERE id = NEW.region_id;

        IF region_rec IS NULL THEN
            RAISE EXCEPTION 'Region % does not exist', NEW.region_id;
        END IF;

        IF region_rec.continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Region % belongs to continent %, not continent %',
                NEW.region_id, region_rec.continent_id, NEW.continent_id;
        END IF;

        -- If region has a country, city must have same country
        IF region_rec.country_id IS NOT NULL THEN
            IF NEW.country_id IS NULL THEN
                RAISE EXCEPTION 'Region % has country %, city must have same country_id',
                    NEW.region_id, region_rec.country_id;
            ELSIF NEW.country_id != region_rec.country_id THEN
                RAISE EXCEPTION 'Region % belongs to country %, not country %',
                    NEW.region_id, region_rec.country_id, NEW.country_id;
            END IF;
        END IF;
    END IF;

    -- If district_id is set, verify district exists and belongs to same continent
    IF NEW.district_id IS NOT NULL THEN
        SELECT continent_id, country_id, region_id INTO district_rec
        FROM geo_districts WHERE id = NEW.district_id;

        IF district_rec IS NULL THEN
            RAISE EXCEPTION 'District % does not exist', NEW.district_id;
        END IF;

        IF district_rec.continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'District % belongs to continent %, not continent %',
                NEW.district_id, district_rec.continent_id, NEW.continent_id;
        END IF;

        -- If district has a region, city must have same region
        IF district_rec.region_id IS NOT NULL THEN
            IF NEW.region_id IS NULL THEN
                RAISE EXCEPTION 'District % has region %, city must have same region_id',
                    NEW.district_id, district_rec.region_id;
            ELSIF NEW.region_id != district_rec.region_id THEN
                RAISE EXCEPTION 'District % belongs to region %, not region %',
                    NEW.district_id, district_rec.region_id, NEW.region_id;
            END IF;
        END IF;

        -- If district has a country, city must have same country
        IF district_rec.country_id IS NOT NULL THEN
            IF NEW.country_id IS NULL THEN
                RAISE EXCEPTION 'District % has country %, city must have same country_id',
                    NEW.district_id, district_rec.country_id;
            ELSIF NEW.country_id != district_rec.country_id THEN
                RAISE EXCEPTION 'District % belongs to country %, not country %',
                    NEW.district_id, district_rec.country_id, NEW.country_id;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VALIDATION FUNCTIONS: Updated for relaxed constraints
-- ============================================================================

-- Validate districts (relaxed)
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

    -- Find districts where region's continent doesn't match district's continent
    RETURN QUERY
    SELECT d.id, d.name::text, 'region_continent_mismatch'::text,
           format('Region %s belongs to continent %s, not %s', d.region_id, r.continent_id, d.continent_id)
    FROM geo_districts d
    JOIN geo_regions r ON d.region_id = r.id
    WHERE d.region_id IS NOT NULL AND r.continent_id != d.continent_id;

    -- Find districts where region has country but district has different/no country
    RETURN QUERY
    SELECT d.id, d.name::text, 'region_country_mismatch'::text,
           format('Region %s has country %s, district has country %s', d.region_id, r.country_id, d.country_id)
    FROM geo_districts d
    JOIN geo_regions r ON d.region_id = r.id
    WHERE d.region_id IS NOT NULL
      AND r.country_id IS NOT NULL
      AND (d.country_id IS NULL OR d.country_id != r.country_id);
END;
$$ LANGUAGE plpgsql;

-- Validate cities (relaxed)
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

    -- Find cities where region's continent doesn't match
    RETURN QUERY
    SELECT c.id, c.name::text, 'region_continent_mismatch'::text,
           format('Region %s belongs to continent %s, not %s', c.region_id, r.continent_id, c.continent_id)
    FROM cities c
    JOIN geo_regions r ON c.region_id = r.id
    WHERE c.region_id IS NOT NULL AND r.continent_id != c.continent_id;

    -- Find cities where region has country but city has different/no country
    RETURN QUERY
    SELECT c.id, c.name::text, 'region_country_mismatch'::text,
           format('Region %s has country %s, city has country %s', c.region_id, r.country_id, c.country_id)
    FROM cities c
    JOIN geo_regions r ON c.region_id = r.id
    WHERE c.region_id IS NOT NULL
      AND r.country_id IS NOT NULL
      AND (c.country_id IS NULL OR c.country_id != r.country_id);

    -- Find cities where district's continent doesn't match
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_continent_mismatch'::text,
           format('District %s belongs to continent %s, not %s', c.district_id, d.continent_id, c.continent_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL AND d.continent_id != c.continent_id;

    -- Find cities where district has region but city has different/no region
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_region_mismatch'::text,
           format('District %s has region %s, city has region %s', c.district_id, d.region_id, c.region_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL
      AND d.region_id IS NOT NULL
      AND (c.region_id IS NULL OR c.region_id != d.region_id);

    -- Find cities where district has country but city has different/no country
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_country_mismatch'::text,
           format('District %s has country %s, city has country %s', c.district_id, d.country_id, c.country_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL
      AND d.country_id IS NOT NULL
      AND (c.country_id IS NULL OR c.country_id != d.country_id);
END;
$$ LANGUAGE plpgsql;

-- +goose StatementEnd

-- +goose Down
-- Intentionally empty - these are trigger updates that don't need rollback
