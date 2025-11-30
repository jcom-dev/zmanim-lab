-- Add slug column to publishers table

ALTER TABLE publishers ADD COLUMN IF NOT EXISTS slug TEXT;

-- Create unique index on slug (only for non-null values)
CREATE UNIQUE INDEX IF NOT EXISTS idx_publishers_slug ON publishers(slug) WHERE slug IS NOT NULL;

COMMENT ON COLUMN publishers.slug IS 'URL-friendly unique identifier for the publisher';
