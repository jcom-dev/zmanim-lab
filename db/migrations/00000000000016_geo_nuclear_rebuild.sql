-- +goose Up
-- +goose StatementBegin

-- ============================================================================
-- NUCLEAR GEO REBUILD
-- Drop all location data and rebuild with proper 5-level hierarchy:
-- Continent -> Country -> ADM1 (Region) -> ADM2 (District) -> City
-- ============================================================================

-- Step 1: Drop all foreign key dependencies first
-- ----------------------------------------------------------------------------

-- Drop publisher_coverage (references cities)
DROP TABLE IF EXISTS publisher_coverage CASCADE;

-- Drop cities (references geo_regions, geo_countries)
DROP TABLE IF EXISTS cities CASCADE;

-- Step 2: Drop boundary tables
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS geo_region_boundaries CASCADE;
DROP TABLE IF EXISTS geo_country_boundaries CASCADE;
DROP TABLE IF EXISTS geo_boundary_imports CASCADE;
DROP TABLE IF EXISTS geo_boundary_name_mappings CASCADE;

-- Step 3: Drop geo hierarchy tables
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS geo_regions CASCADE;
DROP TABLE IF EXISTS geo_countries CASCADE;
DROP TABLE IF EXISTS geo_continents CASCADE;

-- Step 4: Drop legacy tables
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS countries CASCADE;

-- Step 5: Drop old function if exists
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS get_publishers_for_city(uuid) CASCADE;
DROP FUNCTION IF EXISTS update_geo_boundary_updated_at() CASCADE;

-- ============================================================================
-- REBUILD: 5-LEVEL GEOGRAPHIC HIERARCHY
-- ============================================================================

-- Level 0: Continents
-- ----------------------------------------------------------------------------
CREATE TABLE geo_continents (
    id smallint PRIMARY KEY,
    code varchar(2) NOT NULL UNIQUE,
    name text NOT NULL
);

COMMENT ON TABLE geo_continents IS 'Level 0: 7 continents with ISO codes';

-- Seed continents
INSERT INTO geo_continents (id, code, name) VALUES
    (1, 'AF', 'Africa'),
    (2, 'AN', 'Antarctica'),
    (3, 'AS', 'Asia'),
    (4, 'EU', 'Europe'),
    (5, 'NA', 'North America'),
    (6, 'OC', 'Oceania'),
    (7, 'SA', 'South America');

-- Level 1: Countries (ADM0)
-- ----------------------------------------------------------------------------
CREATE TABLE geo_countries (
    id smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code varchar(2) NOT NULL UNIQUE,
    code_iso3 varchar(3),                    -- ISO 3166-1 alpha-3
    name text NOT NULL,
    name_local text,                         -- Local/native name
    continent_id smallint NOT NULL REFERENCES geo_continents(id),

    -- Country-specific labels for subdivisions
    adm1_label text DEFAULT 'Region',        -- What ADM1 is called (State, Province, etc.)
    adm2_label text DEFAULT 'District',      -- What ADM2 is called (County, Borough, etc.)
    has_adm1 boolean DEFAULT true,           -- Does this country have ADM1 subdivisions?
    has_adm2 boolean DEFAULT false,          -- Does this country have ADM2 subdivisions?
    is_city_state boolean DEFAULT false,     -- Singapore, Monaco, Vatican, etc.

    population bigint,
    area_km2 double precision,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE geo_countries IS 'Level 1 (ADM0): Countries with ISO 3166-1 codes and subdivision metadata';
COMMENT ON COLUMN geo_countries.adm1_label IS 'Display label for ADM1 level: State (US), Province (CA), Constituent Country (GB)';
COMMENT ON COLUMN geo_countries.adm2_label IS 'Display label for ADM2 level: County (US), Borough (GB), Département (FR)';
COMMENT ON COLUMN geo_countries.is_city_state IS 'True for city-states like Singapore, Monaco, Vatican';

CREATE INDEX idx_geo_countries_continent ON geo_countries(continent_id);
CREATE INDEX idx_geo_countries_name_trgm ON geo_countries USING gin(name gin_trgm_ops);

-- Level 2: Regions (ADM1) - States, Provinces, Constituent Countries
-- ----------------------------------------------------------------------------
CREATE TABLE geo_regions (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    country_id smallint NOT NULL REFERENCES geo_countries(id) ON DELETE CASCADE,
    code text NOT NULL,                      -- ISO 3166-2 code (e.g., US-CA, GB-ENG)
    name text NOT NULL,
    name_local text,                         -- Local/native name

    population bigint,
    area_km2 double precision,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    UNIQUE(country_id, code)
);

COMMENT ON TABLE geo_regions IS 'Level 2 (ADM1): States, provinces, constituent countries, regions';
COMMENT ON COLUMN geo_regions.code IS 'ISO 3166-2 subdivision code (e.g., US-CA for California)';

CREATE INDEX idx_geo_regions_country ON geo_regions(country_id);
CREATE INDEX idx_geo_regions_name_trgm ON geo_regions USING gin(name gin_trgm_ops);

-- Level 3: Districts (ADM2) - Counties, Boroughs, Départements
-- ----------------------------------------------------------------------------
CREATE TABLE geo_districts (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    region_id integer NOT NULL REFERENCES geo_regions(id) ON DELETE CASCADE,
    code text NOT NULL,                      -- Local admin code or geoBoundaries code
    name text NOT NULL,
    name_local text,                         -- Local/native name

    population bigint,
    area_km2 double precision,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    UNIQUE(region_id, code)
);

COMMENT ON TABLE geo_districts IS 'Level 3 (ADM2): Counties, boroughs, départements, local authorities';
COMMENT ON COLUMN geo_districts.code IS 'Local administrative code (e.g., E08000003 for Manchester)';

CREATE INDEX idx_geo_districts_region ON geo_districts(region_id);
CREATE INDEX idx_geo_districts_name_trgm ON geo_districts USING gin(name gin_trgm_ops);

-- Level 4: Cities
-- ----------------------------------------------------------------------------
CREATE TABLE cities (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Geographic hierarchy (nullable for flexibility during import)
    country_id smallint NOT NULL REFERENCES geo_countries(id),
    region_id integer REFERENCES geo_regions(id),
    district_id integer REFERENCES geo_districts(id),

    -- Names
    name text NOT NULL,
    name_ascii text,                         -- ASCII transliteration for search
    name_local text,                         -- Local/native name (Hebrew, Arabic, etc.)

    -- Coordinates
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    location geography(Point, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
    ) STORED,

    -- Metadata
    timezone text NOT NULL,
    elevation_m integer DEFAULT 0,           -- Elevation in meters (for zmanim calculations)
    population integer,

    -- External IDs for deduplication
    geonameid integer UNIQUE,                -- GeoNames ID

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE cities IS 'Level 4: Cities with coordinates, timezone, and elevation for zmanim calculations';
COMMENT ON COLUMN cities.elevation_m IS 'Elevation in meters above sea level, used for zmanim calculations';
COMMENT ON COLUMN cities.geonameid IS 'GeoNames ID for data source reference and deduplication';

-- City indexes for common queries
CREATE INDEX idx_cities_country ON cities(country_id);
CREATE INDEX idx_cities_region ON cities(region_id);
CREATE INDEX idx_cities_district ON cities(district_id);

-- ============================================================================
-- HIERARCHY CONSISTENCY TRIGGER
-- Ensures city's region belongs to city's country, and district belongs to region
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_city_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    v_region_country_id smallint;
    v_district_region_id integer;
BEGIN
    -- If region_id is set, verify it belongs to the city's country
    IF NEW.region_id IS NOT NULL THEN
        SELECT country_id INTO v_region_country_id
        FROM geo_regions WHERE id = NEW.region_id;

        IF v_region_country_id IS NULL THEN
            RAISE EXCEPTION 'Region ID % does not exist', NEW.region_id;
        END IF;

        IF v_region_country_id != NEW.country_id THEN
            RAISE EXCEPTION 'Region ID % belongs to country %, but city is in country %',
                NEW.region_id, v_region_country_id, NEW.country_id;
        END IF;
    END IF;

    -- If district_id is set, verify it belongs to the city's region
    IF NEW.district_id IS NOT NULL THEN
        IF NEW.region_id IS NULL THEN
            RAISE EXCEPTION 'Cannot set district_id without region_id';
        END IF;

        SELECT region_id INTO v_district_region_id
        FROM geo_districts WHERE id = NEW.district_id;

        IF v_district_region_id IS NULL THEN
            RAISE EXCEPTION 'District ID % does not exist', NEW.district_id;
        END IF;

        IF v_district_region_id != NEW.region_id THEN
            RAISE EXCEPTION 'District ID % belongs to region %, but city is in region %',
                NEW.district_id, v_district_region_id, NEW.region_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_city_hierarchy_trigger
    BEFORE INSERT OR UPDATE ON cities
    FOR EACH ROW
    EXECUTE FUNCTION validate_city_hierarchy();
CREATE INDEX idx_cities_location ON cities USING GIST(location);
CREATE INDEX idx_cities_population ON cities(population DESC NULLS LAST);
CREATE INDEX idx_cities_name_trgm ON cities USING gin(name gin_trgm_ops);
CREATE INDEX idx_cities_name_ascii_trgm ON cities USING gin(name_ascii gin_trgm_ops);

-- Composite indexes for common query patterns
CREATE INDEX idx_cities_country_population ON cities(country_id, population DESC NULLS LAST, name);
CREATE INDEX idx_cities_region_population ON cities(region_id, population DESC NULLS LAST, name)
    WHERE region_id IS NOT NULL;
CREATE INDEX idx_cities_country_region_population ON cities(country_id, region_id, population DESC NULLS LAST, name);

-- ============================================================================
-- BOUNDARY TABLES (PostGIS polygons)
-- ============================================================================

-- Country boundaries
CREATE TABLE geo_country_boundaries (
    country_id smallint PRIMARY KEY REFERENCES geo_countries(id) ON DELETE CASCADE,
    boundary geography(MultiPolygon, 4326) NOT NULL,
    boundary_simplified geography(MultiPolygon, 4326),  -- Simplified for web rendering
    area_km2 double precision,
    centroid geography(Point, 4326),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE geo_country_boundaries IS 'Polygon boundaries for countries';
COMMENT ON COLUMN geo_country_boundaries.boundary_simplified IS 'Simplified boundary for faster web rendering';

CREATE INDEX idx_country_boundaries_geom ON geo_country_boundaries USING GIST(boundary);
CREATE INDEX idx_country_boundaries_simplified ON geo_country_boundaries USING GIST(boundary_simplified);
CREATE INDEX idx_country_boundaries_centroid ON geo_country_boundaries USING GIST(centroid);

-- Region boundaries (ADM1)
CREATE TABLE geo_region_boundaries (
    region_id integer PRIMARY KEY REFERENCES geo_regions(id) ON DELETE CASCADE,
    boundary geography(MultiPolygon, 4326) NOT NULL,
    boundary_simplified geography(MultiPolygon, 4326),
    area_km2 double precision,
    centroid geography(Point, 4326),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE geo_region_boundaries IS 'Polygon boundaries for regions/states (ADM1)';

CREATE INDEX idx_region_boundaries_geom ON geo_region_boundaries USING GIST(boundary);
CREATE INDEX idx_region_boundaries_simplified ON geo_region_boundaries USING GIST(boundary_simplified);
CREATE INDEX idx_region_boundaries_centroid ON geo_region_boundaries USING GIST(centroid);

-- District boundaries (ADM2)
CREATE TABLE geo_district_boundaries (
    district_id integer PRIMARY KEY REFERENCES geo_districts(id) ON DELETE CASCADE,
    boundary geography(MultiPolygon, 4326) NOT NULL,
    boundary_simplified geography(MultiPolygon, 4326),
    area_km2 double precision,
    centroid geography(Point, 4326),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

COMMENT ON TABLE geo_district_boundaries IS 'Polygon boundaries for districts/counties (ADM2)';

CREATE INDEX idx_district_boundaries_geom ON geo_district_boundaries USING GIST(boundary);
CREATE INDEX idx_district_boundaries_simplified ON geo_district_boundaries USING GIST(boundary_simplified);
CREATE INDEX idx_district_boundaries_centroid ON geo_district_boundaries USING GIST(centroid);

-- ============================================================================
-- IMPORT TRACKING
-- ============================================================================

CREATE TABLE geo_boundary_imports (
    id serial PRIMARY KEY,
    source text NOT NULL,                    -- 'natural_earth_110m', 'geoboundaries_adm1', etc.
    level text NOT NULL,                     -- 'country', 'region', 'district'
    country_code varchar(2),                 -- NULL for global imports
    version text,
    records_imported integer DEFAULT 0,
    records_matched integer DEFAULT 0,
    records_unmatched integer DEFAULT 0,
    imported_at timestamptz DEFAULT now(),
    notes text
);

COMMENT ON TABLE geo_boundary_imports IS 'Tracks boundary data imports for reproducibility';

-- Name mappings for handling mismatches between data sources
CREATE TABLE geo_name_mappings (
    id serial PRIMARY KEY,
    level text NOT NULL CHECK (level IN ('country', 'region', 'district', 'city')),
    source text NOT NULL,                    -- 'natural_earth', 'geoboundaries', 'geonames'
    source_name text NOT NULL,
    source_country_code varchar(2),
    target_id integer NOT NULL,              -- ID in the target table
    created_at timestamptz DEFAULT now(),
    notes text,

    UNIQUE(level, source, source_name, source_country_code)
);

COMMENT ON TABLE geo_name_mappings IS 'Manual name mappings between data sources';

-- ============================================================================
-- PUBLISHER COVERAGE (rebuilt with district support)
-- ============================================================================

CREATE TABLE publisher_coverage (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    publisher_id uuid NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,

    -- Coverage level determines which ID field is used
    coverage_level text NOT NULL CHECK (coverage_level IN ('continent', 'country', 'region', 'district', 'city')),

    -- Geographic reference (only one should be set based on coverage_level)
    continent_code varchar(2),               -- For continent-level
    country_id smallint REFERENCES geo_countries(id) ON DELETE CASCADE,
    region_id integer REFERENCES geo_regions(id) ON DELETE CASCADE,
    district_id integer REFERENCES geo_districts(id) ON DELETE CASCADE,
    city_id uuid REFERENCES cities(id) ON DELETE CASCADE,

    priority integer DEFAULT 5 CHECK (priority >= 1 AND priority <= 10),
    is_active boolean DEFAULT true,

    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),

    -- Ensure correct fields are set for each coverage level
    CONSTRAINT valid_coverage_data CHECK (
        (coverage_level = 'continent' AND continent_code IS NOT NULL AND country_id IS NULL AND region_id IS NULL AND district_id IS NULL AND city_id IS NULL) OR
        (coverage_level = 'country' AND country_id IS NOT NULL AND region_id IS NULL AND district_id IS NULL AND city_id IS NULL) OR
        (coverage_level = 'region' AND region_id IS NOT NULL AND district_id IS NULL AND city_id IS NULL) OR
        (coverage_level = 'district' AND district_id IS NOT NULL AND city_id IS NULL) OR
        (coverage_level = 'city' AND city_id IS NOT NULL)
    )
);

COMMENT ON TABLE publisher_coverage IS 'Publisher geographic coverage at continent, country, region, district, or city level';
COMMENT ON COLUMN publisher_coverage.coverage_level IS 'Granularity: continent > country > region > district > city';
COMMENT ON COLUMN publisher_coverage.priority IS 'Priority for this coverage (1-10, higher = more prominent)';

-- Coverage indexes
CREATE INDEX idx_publisher_coverage_publisher ON publisher_coverage(publisher_id);
CREATE INDEX idx_publisher_coverage_active ON publisher_coverage(publisher_id, is_active) WHERE is_active = true;
CREATE INDEX idx_publisher_coverage_continent ON publisher_coverage(continent_code) WHERE coverage_level = 'continent';
CREATE INDEX idx_publisher_coverage_country ON publisher_coverage(country_id) WHERE coverage_level = 'country';
CREATE INDEX idx_publisher_coverage_region ON publisher_coverage(region_id) WHERE coverage_level = 'region';
CREATE INDEX idx_publisher_coverage_district ON publisher_coverage(district_id) WHERE coverage_level = 'district';
CREATE INDEX idx_publisher_coverage_city ON publisher_coverage(city_id) WHERE coverage_level = 'city';

-- Unique constraints to prevent duplicate coverage
CREATE UNIQUE INDEX idx_publisher_coverage_unique_continent ON publisher_coverage(publisher_id, continent_code)
    WHERE coverage_level = 'continent';
CREATE UNIQUE INDEX idx_publisher_coverage_unique_country ON publisher_coverage(publisher_id, country_id)
    WHERE coverage_level = 'country';
CREATE UNIQUE INDEX idx_publisher_coverage_unique_region ON publisher_coverage(publisher_id, region_id)
    WHERE coverage_level = 'region';
CREATE UNIQUE INDEX idx_publisher_coverage_unique_district ON publisher_coverage(publisher_id, district_id)
    WHERE coverage_level = 'district';
CREATE UNIQUE INDEX idx_publisher_coverage_unique_city ON publisher_coverage(publisher_id, city_id)
    WHERE coverage_level = 'city';

-- ============================================================================
-- POST-IMPORT: Assign cities to regions/districts via point-in-polygon
-- This is the authoritative method - coordinates are truth, not name matching
-- ============================================================================

-- Assign cities to countries based on coordinates
CREATE OR REPLACE FUNCTION assign_cities_to_countries()
RETURNS TABLE(updated_count integer, unmatched_count integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated integer := 0;
    v_unmatched integer := 0;
BEGIN
    -- Temporarily disable the hierarchy trigger for bulk updates
    ALTER TABLE cities DISABLE TRIGGER validate_city_hierarchy_trigger;

    -- Update cities where coordinates fall within a country boundary
    WITH matches AS (
        UPDATE cities c
        SET country_id = cb.country_id,
            updated_at = now()
        FROM geo_country_boundaries cb
        WHERE ST_Contains(cb.boundary::geometry, c.location::geometry)
          AND c.country_id != cb.country_id
        RETURNING c.id
    )
    SELECT COUNT(*) INTO v_updated FROM matches;

    -- Count cities that don't fall within any country boundary
    SELECT COUNT(*) INTO v_unmatched
    FROM cities c
    WHERE NOT EXISTS (
        SELECT 1 FROM geo_country_boundaries cb
        WHERE ST_Contains(cb.boundary::geometry, c.location::geometry)
    );

    ALTER TABLE cities ENABLE TRIGGER validate_city_hierarchy_trigger;

    RETURN QUERY SELECT v_updated, v_unmatched;
END;
$$;

-- Assign cities to regions (ADM1) based on coordinates
CREATE OR REPLACE FUNCTION assign_cities_to_regions()
RETURNS TABLE(updated_count integer, unmatched_count integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated integer := 0;
    v_unmatched integer := 0;
BEGIN
    -- Temporarily disable the hierarchy trigger for bulk updates
    ALTER TABLE cities DISABLE TRIGGER validate_city_hierarchy_trigger;

    -- Update cities where coordinates fall within a region boundary
    -- Only match regions that belong to the city's country
    WITH matches AS (
        UPDATE cities c
        SET region_id = r.id,
            updated_at = now()
        FROM geo_region_boundaries rb
        JOIN geo_regions r ON rb.region_id = r.id
        WHERE ST_Contains(rb.boundary::geometry, c.location::geometry)
          AND r.country_id = c.country_id
          AND (c.region_id IS NULL OR c.region_id != r.id)
        RETURNING c.id
    )
    SELECT COUNT(*) INTO v_updated FROM matches;

    -- Count cities in countries with regions that don't fall within any region boundary
    SELECT COUNT(*) INTO v_unmatched
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm1 = true
      AND c.region_id IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM geo_region_boundaries rb
        JOIN geo_regions r ON rb.region_id = r.id
        WHERE ST_Contains(rb.boundary::geometry, c.location::geometry)
          AND r.country_id = c.country_id
    );

    ALTER TABLE cities ENABLE TRIGGER validate_city_hierarchy_trigger;

    RETURN QUERY SELECT v_updated, v_unmatched;
END;
$$;

-- Assign cities to districts (ADM2) based on coordinates
CREATE OR REPLACE FUNCTION assign_cities_to_districts()
RETURNS TABLE(updated_count integer, unmatched_count integer)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated integer := 0;
    v_unmatched integer := 0;
BEGIN
    -- Temporarily disable the hierarchy trigger for bulk updates
    ALTER TABLE cities DISABLE TRIGGER validate_city_hierarchy_trigger;

    -- Update cities where coordinates fall within a district boundary
    -- Only match districts that belong to the city's region
    WITH matches AS (
        UPDATE cities c
        SET district_id = d.id,
            updated_at = now()
        FROM geo_district_boundaries db
        JOIN geo_districts d ON db.district_id = d.id
        WHERE ST_Contains(db.boundary::geometry, c.location::geometry)
          AND d.region_id = c.region_id
          AND c.region_id IS NOT NULL
          AND (c.district_id IS NULL OR c.district_id != d.id)
        RETURNING c.id
    )
    SELECT COUNT(*) INTO v_updated FROM matches;

    -- Count cities in countries with districts that don't fall within any district boundary
    SELECT COUNT(*) INTO v_unmatched
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm2 = true
      AND c.region_id IS NOT NULL
      AND c.district_id IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM geo_district_boundaries db
        JOIN geo_districts d ON db.district_id = d.id
        WHERE ST_Contains(db.boundary::geometry, c.location::geometry)
          AND d.region_id = c.region_id
    );

    ALTER TABLE cities ENABLE TRIGGER validate_city_hierarchy_trigger;

    RETURN QUERY SELECT v_updated, v_unmatched;
END;
$$;

-- Master function: Run all assignments in order (country -> region -> district)
CREATE OR REPLACE FUNCTION assign_all_city_hierarchy()
RETURNS TABLE(
    level text,
    updated_count integer,
    unmatched_count integer
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_country_updated integer;
    v_country_unmatched integer;
    v_region_updated integer;
    v_region_unmatched integer;
    v_district_updated integer;
    v_district_unmatched integer;
BEGIN
    RAISE NOTICE 'Starting city hierarchy assignment via point-in-polygon...';

    -- Step 1: Assign countries
    RAISE NOTICE 'Step 1/3: Assigning cities to countries...';
    SELECT * INTO v_country_updated, v_country_unmatched FROM assign_cities_to_countries();
    RAISE NOTICE 'Countries: % updated, % unmatched', v_country_updated, v_country_unmatched;

    -- Step 2: Assign regions (depends on country being set)
    RAISE NOTICE 'Step 2/3: Assigning cities to regions...';
    SELECT * INTO v_region_updated, v_region_unmatched FROM assign_cities_to_regions();
    RAISE NOTICE 'Regions: % updated, % unmatched', v_region_updated, v_region_unmatched;

    -- Step 3: Assign districts (depends on region being set)
    RAISE NOTICE 'Step 3/3: Assigning cities to districts...';
    SELECT * INTO v_district_updated, v_district_unmatched FROM assign_cities_to_districts();
    RAISE NOTICE 'Districts: % updated, % unmatched', v_district_updated, v_district_unmatched;

    RAISE NOTICE 'City hierarchy assignment complete.';

    RETURN QUERY VALUES
        ('country'::text, v_country_updated, v_country_unmatched),
        ('region'::text, v_region_updated, v_region_unmatched),
        ('district'::text, v_district_updated, v_district_unmatched);
END;
$$;

COMMENT ON FUNCTION assign_all_city_hierarchy() IS 'Assigns all cities to countries/regions/districts based on point-in-polygon. Run after importing boundaries.';

-- ============================================================================
-- VALIDATION: Check hierarchy consistency
-- ============================================================================

CREATE OR REPLACE FUNCTION validate_all_city_hierarchy()
RETURNS TABLE(
    issue_type text,
    city_id uuid,
    city_name text,
    details text
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Check for cities where assigned region doesn't match point-in-polygon result
    RETURN QUERY
    SELECT
        'region_mismatch'::text,
        c.id,
        c.name,
        format('Assigned to region %s (%s) but coordinates are in region %s (%s)',
               c.region_id, r1.name, r2.id, r2.name)
    FROM cities c
    JOIN geo_regions r1 ON c.region_id = r1.id
    JOIN geo_region_boundaries rb ON ST_Contains(rb.boundary::geometry, c.location::geometry)
    JOIN geo_regions r2 ON rb.region_id = r2.id AND r2.country_id = c.country_id
    WHERE c.region_id != r2.id;

    -- Check for cities where assigned district doesn't match point-in-polygon result
    RETURN QUERY
    SELECT
        'district_mismatch'::text,
        c.id,
        c.name,
        format('Assigned to district %s (%s) but coordinates are in district %s (%s)',
               c.district_id, d1.name, d2.id, d2.name)
    FROM cities c
    JOIN geo_districts d1 ON c.district_id = d1.id
    JOIN geo_district_boundaries db ON ST_Contains(db.boundary::geometry, c.location::geometry)
    JOIN geo_districts d2 ON db.district_id = d2.id AND d2.region_id = c.region_id
    WHERE c.district_id != d2.id;

    -- Check for cities missing region assignment in countries that have regions
    RETURN QUERY
    SELECT
        'missing_region'::text,
        c.id,
        c.name,
        format('In country %s which has_adm1=true but no region assigned', co.name)
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm1 = true
      AND c.region_id IS NULL;

    -- Check for cities missing district assignment in countries that have districts
    RETURN QUERY
    SELECT
        'missing_district'::text,
        c.id,
        c.name,
        format('In country %s which has_adm2=true but no district assigned', co.name)
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm2 = true
      AND c.region_id IS NOT NULL
      AND c.district_id IS NULL;
END;
$$;

COMMENT ON FUNCTION validate_all_city_hierarchy() IS 'Validates that all city hierarchy assignments match point-in-polygon results';

-- ============================================================================
-- HELPER FUNCTION: Find publishers for a city
-- ============================================================================

CREATE OR REPLACE FUNCTION get_publishers_for_city(p_city_id uuid)
RETURNS TABLE(
    publisher_id uuid,
    publisher_name text,
    coverage_level text,
    priority integer,
    match_type text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_city RECORD;
BEGIN
    -- Get city's geographic hierarchy
    SELECT
        c.id,
        c.country_id,
        c.region_id,
        c.district_id,
        co.continent_id,
        cont.code as continent_code
    INTO v_city
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    JOIN geo_continents cont ON co.continent_id = cont.id
    WHERE c.id = p_city_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Return publishers with coverage matching this city
    -- Priority: city > district > region > country > continent
    RETURN QUERY
    SELECT DISTINCT ON (pc.publisher_id)
        pc.publisher_id,
        p.name::TEXT as publisher_name,
        pc.coverage_level,
        pc.priority,
        CASE pc.coverage_level
            WHEN 'city' THEN 'exact_city'
            WHEN 'district' THEN 'district_match'
            WHEN 'region' THEN 'region_match'
            WHEN 'country' THEN 'country_match'
            WHEN 'continent' THEN 'continent_match'
        END as match_type
    FROM publisher_coverage pc
    JOIN publishers p ON p.id = pc.publisher_id
    WHERE pc.is_active = TRUE
      AND p.status = 'active'
      AND (
        (pc.coverage_level = 'city' AND pc.city_id = p_city_id)
        OR (pc.coverage_level = 'district' AND pc.district_id = v_city.district_id AND v_city.district_id IS NOT NULL)
        OR (pc.coverage_level = 'region' AND pc.region_id = v_city.region_id AND v_city.region_id IS NOT NULL)
        OR (pc.coverage_level = 'country' AND pc.country_id = v_city.country_id)
        OR (pc.coverage_level = 'continent' AND pc.continent_code = v_city.continent_code)
      )
    ORDER BY pc.publisher_id,
             CASE pc.coverage_level
                 WHEN 'city' THEN 1
                 WHEN 'district' THEN 2
                 WHEN 'region' THEN 3
                 WHEN 'country' THEN 4
                 WHEN 'continent' THEN 5
             END,
             pc.priority DESC;
END;
$$;

COMMENT ON FUNCTION get_publishers_for_city(uuid) IS 'Find publishers serving a city based on geographic hierarchy (city > district > region > country > continent)';

-- ============================================================================
-- UPDATE TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_geo_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_geo_countries_updated_at
    BEFORE UPDATE ON geo_countries FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_geo_regions_updated_at
    BEFORE UPDATE ON geo_regions FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_geo_districts_updated_at
    BEFORE UPDATE ON geo_districts FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_cities_updated_at
    BEFORE UPDATE ON cities FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_geo_country_boundaries_updated_at
    BEFORE UPDATE ON geo_country_boundaries FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_geo_region_boundaries_updated_at
    BEFORE UPDATE ON geo_region_boundaries FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_geo_district_boundaries_updated_at
    BEFORE UPDATE ON geo_district_boundaries FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

CREATE TRIGGER update_publisher_coverage_updated_at
    BEFORE UPDATE ON publisher_coverage FOR EACH ROW EXECUTE FUNCTION update_geo_updated_at();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- This is a destructive migration - the down migration cannot restore data
-- It will recreate the old schema structure but data will be lost

DROP FUNCTION IF EXISTS get_publishers_for_city(uuid) CASCADE;
DROP FUNCTION IF EXISTS update_geo_updated_at() CASCADE;

DROP TABLE IF EXISTS publisher_coverage CASCADE;
DROP TABLE IF EXISTS geo_name_mappings CASCADE;
DROP TABLE IF EXISTS geo_boundary_imports CASCADE;
DROP TABLE IF EXISTS geo_district_boundaries CASCADE;
DROP TABLE IF EXISTS geo_region_boundaries CASCADE;
DROP TABLE IF EXISTS geo_country_boundaries CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS geo_districts CASCADE;
DROP TABLE IF EXISTS geo_regions CASCADE;
DROP TABLE IF EXISTS geo_countries CASCADE;
DROP TABLE IF EXISTS geo_continents CASCADE;

-- Note: Original schema would need to be recreated from migration 00000000000001
-- This down migration is intentionally minimal as it's a destructive change

-- +goose StatementEnd
