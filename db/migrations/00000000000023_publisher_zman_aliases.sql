-- Migration: Publisher Zman Aliases
-- Epic 5, Story 5.0: Database Schema for Publisher Aliases & Zman Requests
-- Date: 2025-12-02

-- Publisher Zman Aliases: Custom display names per publisher
-- Allows publishers to override how zmanim are displayed while preserving canonical master registry names
CREATE TABLE IF NOT EXISTS publisher_zman_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    custom_hebrew_name TEXT NOT NULL,
    custom_english_name TEXT NOT NULL,
    custom_transliteration TEXT,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    UNIQUE(publisher_id, publisher_zman_id)
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_publisher_zman_aliases_publisher ON publisher_zman_aliases(publisher_id);
CREATE INDEX IF NOT EXISTS idx_publisher_zman_aliases_zman ON publisher_zman_aliases(publisher_zman_id);

-- Trigger to update updated_at timestamp
DROP TRIGGER IF EXISTS update_publisher_zman_aliases_updated_at ON publisher_zman_aliases;
CREATE TRIGGER update_publisher_zman_aliases_updated_at
    BEFORE UPDATE ON publisher_zman_aliases
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE publisher_zman_aliases IS 'Custom display names for zmanim per publisher. Original master registry names remain accessible via master_zmanim_registry.';
COMMENT ON COLUMN publisher_zman_aliases.custom_hebrew_name IS 'Publisher-specific Hebrew display name';
COMMENT ON COLUMN publisher_zman_aliases.custom_english_name IS 'Publisher-specific English display name';
COMMENT ON COLUMN publisher_zman_aliases.custom_transliteration IS 'Optional publisher-specific transliteration';
COMMENT ON COLUMN publisher_zman_aliases.is_active IS 'Whether this alias is currently in use';
