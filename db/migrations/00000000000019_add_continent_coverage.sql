-- Add continent-level coverage support
-- Migration: 00000000000019_add_continent_coverage.sql

-- 1. Add continent_code column
ALTER TABLE publisher_coverage ADD COLUMN continent_code VARCHAR(2);

-- 2. Drop old check constraint
ALTER TABLE publisher_coverage DROP CONSTRAINT IF EXISTS coverage_level_check;
ALTER TABLE publisher_coverage DROP CONSTRAINT IF EXISTS valid_coverage_data;

-- 3. Update coverage_level check to include 'continent'
ALTER TABLE publisher_coverage ADD CONSTRAINT coverage_level_check
    CHECK (coverage_level IN ('continent', 'country', 'region', 'city'));

-- 4. Add new valid_coverage_data constraint
ALTER TABLE publisher_coverage ADD CONSTRAINT valid_coverage_data CHECK (
    (coverage_level = 'continent' AND continent_code IS NOT NULL AND country_code IS NULL AND region IS NULL AND city_id IS NULL) OR
    (coverage_level = 'country' AND country_code IS NOT NULL AND region IS NULL AND city_id IS NULL) OR
    (coverage_level = 'region' AND country_code IS NOT NULL AND region IS NOT NULL AND city_id IS NULL) OR
    (coverage_level = 'city' AND city_id IS NOT NULL)
);

-- 5. Create index for continent lookups
CREATE INDEX idx_publisher_coverage_continent ON publisher_coverage(continent_code) WHERE coverage_level = 'continent';
