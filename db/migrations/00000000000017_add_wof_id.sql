-- +goose Up
-- +goose StatementBegin

-- Add wof_id (Who's On First ID) to all geographic tables for reliable matching
-- WOF IDs are stable 64-bit integers that enable:
--   1. Reliable sync with WOF data updates
--   2. Data provenance tracking
--   3. Incremental imports (upsert by wof_id)

-- Countries
ALTER TABLE geo_countries ADD COLUMN IF NOT EXISTS wof_id bigint UNIQUE;
COMMENT ON COLUMN geo_countries.wof_id IS 'Who''s On First stable ID for this country';
CREATE INDEX IF NOT EXISTS idx_geo_countries_wof_id ON geo_countries(wof_id) WHERE wof_id IS NOT NULL;

-- Regions
ALTER TABLE geo_regions ADD COLUMN IF NOT EXISTS wof_id bigint UNIQUE;
COMMENT ON COLUMN geo_regions.wof_id IS 'Who''s On First stable ID for this region';
CREATE INDEX IF NOT EXISTS idx_geo_regions_wof_id ON geo_regions(wof_id) WHERE wof_id IS NOT NULL;

-- Districts
ALTER TABLE geo_districts ADD COLUMN IF NOT EXISTS wof_id bigint UNIQUE;
COMMENT ON COLUMN geo_districts.wof_id IS 'Who''s On First stable ID for this district';
CREATE INDEX IF NOT EXISTS idx_geo_districts_wof_id ON geo_districts(wof_id) WHERE wof_id IS NOT NULL;

-- Cities - rename geonameid to wof_id (we're now using WOF, not GeoNames)
-- First add wof_id, then we can drop geonameid later if needed
ALTER TABLE cities ADD COLUMN IF NOT EXISTS wof_id bigint UNIQUE;
COMMENT ON COLUMN cities.wof_id IS 'Who''s On First stable ID for this locality';
CREATE INDEX IF NOT EXISTS idx_cities_wof_id ON cities(wof_id) WHERE wof_id IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_cities_wof_id;
ALTER TABLE cities DROP COLUMN IF EXISTS wof_id;

DROP INDEX IF EXISTS idx_geo_districts_wof_id;
ALTER TABLE geo_districts DROP COLUMN IF EXISTS wof_id;

DROP INDEX IF EXISTS idx_geo_regions_wof_id;
ALTER TABLE geo_regions DROP COLUMN IF EXISTS wof_id;

DROP INDEX IF EXISTS idx_geo_countries_wof_id;
ALTER TABLE geo_countries DROP COLUMN IF EXISTS wof_id;

-- +goose StatementEnd
