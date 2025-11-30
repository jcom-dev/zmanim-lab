-- Add bio and slug columns to publishers table

ALTER TABLE publishers ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE publishers ADD COLUMN IF NOT EXISTS slug TEXT;

-- Create unique index on slug (only for non-null values)
CREATE UNIQUE INDEX IF NOT EXISTS idx_publishers_slug ON publishers(slug) WHERE slug IS NOT NULL;

COMMENT ON COLUMN publishers.bio IS 'Short biography or about text for the publisher';
COMMENT ON COLUMN publishers.slug IS 'URL-friendly unique identifier for the publisher';
