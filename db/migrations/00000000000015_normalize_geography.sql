-- ============================================
-- GEOGRAPHIC DATA NORMALIZATION
-- ============================================
-- Creates normalized lookup tables for continents, countries, and regions
-- to replace denormalized TEXT columns in cities table.
--
-- Storage savings: ~82% reduction on geographic text columns
-- Adds referential integrity and cleaner data model.

-- ============================================
-- 1. CONTINENTS TABLE (7 rows)
-- ============================================
CREATE TABLE geo_continents (
    id SMALLINT PRIMARY KEY,
    code VARCHAR(2) UNIQUE NOT NULL,
    name TEXT NOT NULL
);

INSERT INTO geo_continents (id, code, name) VALUES
    (1, 'AF', 'Africa'),
    (2, 'AN', 'Antarctica'),
    (3, 'AS', 'Asia'),
    (4, 'EU', 'Europe'),
    (5, 'NA', 'North America'),
    (6, 'OC', 'Oceania'),
    (7, 'SA', 'South America');

COMMENT ON TABLE geo_continents IS 'Lookup table for 7 continents with ISO codes';

-- ============================================
-- 2. COUNTRIES TABLE (~250 rows)
-- ============================================
CREATE TABLE geo_countries (
    id SMALLINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    code VARCHAR(2) UNIQUE NOT NULL,
    name TEXT NOT NULL,
    continent_id SMALLINT NOT NULL REFERENCES geo_continents(id)
);

CREATE INDEX idx_geo_countries_continent ON geo_countries(continent_id);

COMMENT ON TABLE geo_countries IS 'Lookup table for countries with ISO 3166-1 alpha-2 codes';
COMMENT ON COLUMN geo_countries.code IS 'ISO 3166-1 alpha-2 country code (e.g., US, IL, GB)';

-- ============================================
-- 3. REGIONS TABLE (~3,800 rows)
-- ============================================
CREATE TABLE geo_regions (
    id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    country_id SMALLINT NOT NULL REFERENCES geo_countries(id),
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    UNIQUE(country_id, code)
);

CREATE INDEX idx_geo_regions_country ON geo_regions(country_id);

COMMENT ON TABLE geo_regions IS 'Lookup table for administrative regions (states, provinces, districts)';
COMMENT ON COLUMN geo_regions.code IS 'GeoNames admin1 code within the country';
COMMENT ON COLUMN geo_regions.name IS 'Human-readable region name (e.g., California, Ontario)';

-- ============================================
-- 4. ADD FK COLUMNS TO CITIES
-- ============================================
ALTER TABLE cities
    ADD COLUMN country_id SMALLINT REFERENCES geo_countries(id),
    ADD COLUMN region_id INTEGER REFERENCES geo_regions(id);

CREATE INDEX idx_cities_country_id ON cities(country_id);
CREATE INDEX idx_cities_region_id ON cities(region_id);

COMMENT ON COLUMN cities.country_id IS 'FK to geo_countries - normalized replacement for country/country_code';
COMMENT ON COLUMN cities.region_id IS 'FK to geo_regions - normalized replacement for region/region_code';
