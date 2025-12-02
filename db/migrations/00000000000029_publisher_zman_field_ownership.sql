-- Migration: Publisher Zman Field Ownership
-- Epic 5, Story 5.18: Publisher owns description, transliteration, formula with diff/revert
-- Date: 2025-12-02

-- Add transliteration column to publisher_zmanim
-- Publisher's custom transliteration (can differ from registry)
ALTER TABLE publisher_zmanim
ADD COLUMN IF NOT EXISTS transliteration TEXT;

-- Add description column to publisher_zmanim
-- Publisher's description of what this zman represents (can differ from registry)
-- This is DISTINCT from publisher_comment which is for personal notes/minhag
ALTER TABLE publisher_zmanim
ADD COLUMN IF NOT EXISTS description TEXT;

-- Comments for clarity
COMMENT ON COLUMN publisher_zmanim.transliteration IS 'Publisher''s custom transliteration (can differ from registry)';
COMMENT ON COLUMN publisher_zmanim.description IS 'Publisher''s description of what this zman represents (can differ from registry)';
COMMENT ON COLUMN publisher_zmanim.publisher_comment IS 'Publisher''s personal notes, minhag, or halachic source';
