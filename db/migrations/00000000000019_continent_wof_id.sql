-- +goose Up
-- +goose StatementBegin

-- Add wof_id to geo_continents for WOF-driven import
ALTER TABLE geo_continents ADD COLUMN IF NOT EXISTS wof_id bigint UNIQUE;
COMMENT ON COLUMN geo_continents.wof_id IS 'Who''s On First stable ID for this continent';
CREATE INDEX IF NOT EXISTS idx_geo_continents_wof_id ON geo_continents(wof_id) WHERE wof_id IS NOT NULL;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

DROP INDEX IF EXISTS idx_geo_continents_wof_id;
ALTER TABLE geo_continents DROP COLUMN IF EXISTS wof_id;

-- +goose StatementEnd
