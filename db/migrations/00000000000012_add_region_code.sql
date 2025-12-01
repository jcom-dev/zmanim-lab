-- Add region_code column to store raw GeoNames admin1 code
-- The existing 'region' column will store human-readable names

ALTER TABLE cities ADD COLUMN IF NOT EXISTS region_code TEXT;

-- Index for filtering by region code
CREATE INDEX IF NOT EXISTS idx_cities_region_code ON cities(country_code, region_code);

COMMENT ON COLUMN cities.region_code IS 'Raw GeoNames admin1 code (e.g., CA, 40)';
COMMENT ON COLUMN cities.region IS 'Human-readable region/state name (e.g., California, Berat County)';
