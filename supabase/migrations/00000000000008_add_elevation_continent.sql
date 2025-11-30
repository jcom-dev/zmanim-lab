-- Migration: Add elevation and continent columns to cities table
-- Source: GeoNames (http://download.geonames.org/export/dump/)

-- Add elevation column (meters above sea level, critical for zmanim calculations)
ALTER TABLE cities ADD COLUMN IF NOT EXISTS elevation INTEGER;

-- Add continent column for filtering
ALTER TABLE cities ADD COLUMN IF NOT EXISTS continent TEXT;

-- Add geonameid for deduplication during imports
ALTER TABLE cities ADD COLUMN IF NOT EXISTS geonameid INTEGER;

-- Create index on continent for fast filtering
CREATE INDEX IF NOT EXISTS idx_cities_continent ON cities(continent);

-- Create unique index on geonameid for upserts
CREATE UNIQUE INDEX IF NOT EXISTS idx_cities_geonameid ON cities(geonameid) WHERE geonameid IS NOT NULL;

-- Create index on population for sorting
CREATE INDEX IF NOT EXISTS idx_cities_population ON cities(population DESC NULLS LAST);

-- Add comments
COMMENT ON COLUMN cities.elevation IS 'Elevation in meters above sea level, used for zmanim calculations';
COMMENT ON COLUMN cities.continent IS 'Continent code: AF=Africa, AS=Asia, EU=Europe, NA=North America, SA=South America, OC=Oceania, AN=Antarctica';
COMMENT ON COLUMN cities.geonameid IS 'GeoNames ID for data source reference and deduplication';
