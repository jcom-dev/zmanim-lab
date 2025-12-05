-- +goose Up
-- +goose StatementBegin

-- WOF enforces that localities always belong to a region (region is "common" in hierarchy)
-- County/district is optional ("common_optional")
-- Country is redundant since region already has country_id (derive via JOIN)

-- First, delete any cities without a region (shouldn't exist with WOF data)
DELETE FROM cities WHERE region_id IS NULL;

-- Make region_id NOT NULL
ALTER TABLE cities ALTER COLUMN region_id SET NOT NULL;

-- Drop redundant country_id (country is accessible via region.country_id)
ALTER TABLE cities DROP COLUMN IF EXISTS country_id;

COMMENT ON COLUMN cities.region_id IS 'Region is required per WOF hierarchy (country derived via region.country_id)';
COMMENT ON COLUMN cities.district_id IS 'District/county is optional per WOF hierarchy';

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Re-add country_id column
ALTER TABLE cities ADD COLUMN country_id smallint REFERENCES geo_countries(id);

-- Populate country_id from region
UPDATE cities c SET country_id = r.country_id FROM geo_regions r WHERE c.region_id = r.id;

-- Make it NOT NULL
ALTER TABLE cities ALTER COLUMN country_id SET NOT NULL;

-- Make region_id nullable again
ALTER TABLE cities ALTER COLUMN region_id DROP NOT NULL;

-- +goose StatementEnd
