-- Add name_ascii column for ASCII-normalized city name searches
-- This allows searching for cities without diacritics (e.g., "Zurich" finds "Zürich")

ALTER TABLE cities ADD COLUMN IF NOT EXISTS name_ascii TEXT;

-- Populate name_ascii from existing names (simple transliteration)
-- For now, just copy the name - the GeoNames importer will populate ASCII names
UPDATE cities SET name_ascii = name WHERE name_ascii IS NULL;

-- Create index for faster ASCII name searches
CREATE INDEX IF NOT EXISTS idx_cities_name_ascii ON cities(name_ascii);
