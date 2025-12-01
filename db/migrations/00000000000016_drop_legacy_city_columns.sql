-- Migration: Drop redundant legacy columns from cities table
-- These columns are now derived via JOINs to geo_countries, geo_regions, geo_continents

-- Drop legacy text columns that are now normalized
ALTER TABLE cities DROP COLUMN IF EXISTS country_code;
ALTER TABLE cities DROP COLUMN IF EXISTS country;
ALTER TABLE cities DROP COLUMN IF EXISTS region;
ALTER TABLE cities DROP COLUMN IF EXISTS region_code;
ALTER TABLE cities DROP COLUMN IF EXISTS continent;

-- Add NOT NULL constraints to FK columns (all cities should have country_id)
-- Note: region_id can be NULL for cities without region data
ALTER TABLE cities ALTER COLUMN country_id SET NOT NULL;

-- Create index on country_id for faster joins
CREATE INDEX IF NOT EXISTS idx_cities_country_id ON cities(country_id);

-- Create index on region_id for faster joins (partial index excludes nulls)
CREATE INDEX IF NOT EXISTS idx_cities_region_id ON cities(region_id) WHERE region_id IS NOT NULL;
