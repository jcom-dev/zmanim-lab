-- Migration: Add tag_key column to zman_tags and populate from existing data
-- This fixes the schema mismatch where tag_key was defined in initial schema
-- but missing from the actual database table

-- Add tag_key column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'zman_tags' AND column_name = 'tag_key'
    ) THEN
        -- Add the column as nullable first
        ALTER TABLE zman_tags ADD COLUMN tag_key VARCHAR(50);

        -- Populate tag_key from name (use name as tag_key for existing records)
        UPDATE zman_tags SET tag_key = name WHERE tag_key IS NULL;

        -- Make it NOT NULL and UNIQUE
        ALTER TABLE zman_tags ALTER COLUMN tag_key SET NOT NULL;
        ALTER TABLE zman_tags ADD CONSTRAINT zman_tags_tag_key_key UNIQUE (tag_key);

        -- Create index if it doesn't exist
        IF NOT EXISTS (
            SELECT 1 FROM pg_indexes WHERE indexname = 'idx_zman_tags_key'
        ) THEN
            CREATE INDEX idx_zman_tags_key ON zman_tags(tag_key);
        END IF;
    END IF;
END $$;

COMMENT ON COLUMN zman_tags.tag_key IS 'Unique key identifier for the tag (e.g., shabbos, yom_tov)';
