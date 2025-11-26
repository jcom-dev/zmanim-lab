-- Migration: Create publisher coverage tables for city-based coverage
-- Story: 1.6 Publisher Coverage
-- Date: 2025-11-26

-- Publisher coverage defines hierarchical coverage (country, region, or city level)
CREATE TABLE publisher_coverage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    coverage_level TEXT NOT NULL CHECK (coverage_level IN ('country', 'region', 'city')),
    -- For country level: country_code is set
    -- For region level: country_code + region are set
    -- For city level: city_id is set
    country_code VARCHAR(2),
    region TEXT,
    city_id UUID REFERENCES cities(id) ON DELETE CASCADE,
    priority INTEGER DEFAULT 5 CHECK (priority >= 1 AND priority <= 10),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Ensure proper data based on coverage level
    CONSTRAINT valid_coverage_data CHECK (
        (coverage_level = 'country' AND country_code IS NOT NULL AND region IS NULL AND city_id IS NULL) OR
        (coverage_level = 'region' AND country_code IS NOT NULL AND region IS NOT NULL AND city_id IS NULL) OR
        (coverage_level = 'city' AND city_id IS NOT NULL)
    )
);

-- Indexes for efficient queries
CREATE INDEX idx_publisher_coverage_publisher ON publisher_coverage(publisher_id);
CREATE INDEX idx_publisher_coverage_country ON publisher_coverage(country_code) WHERE coverage_level = 'country';
CREATE INDEX idx_publisher_coverage_region ON publisher_coverage(country_code, region) WHERE coverage_level = 'region';
CREATE INDEX idx_publisher_coverage_city ON publisher_coverage(city_id) WHERE coverage_level = 'city';
CREATE INDEX idx_publisher_coverage_active ON publisher_coverage(is_active);

-- Prevent duplicate coverage entries
CREATE UNIQUE INDEX idx_publisher_coverage_unique_country
    ON publisher_coverage(publisher_id, country_code)
    WHERE coverage_level = 'country';

CREATE UNIQUE INDEX idx_publisher_coverage_unique_region
    ON publisher_coverage(publisher_id, country_code, region)
    WHERE coverage_level = 'region';

CREATE UNIQUE INDEX idx_publisher_coverage_unique_city
    ON publisher_coverage(publisher_id, city_id)
    WHERE coverage_level = 'city';

-- Add trigger for updated_at
CREATE TRIGGER update_publisher_coverage_updated_at
    BEFORE UPDATE ON publisher_coverage
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Comments
COMMENT ON TABLE publisher_coverage IS 'Publisher geographic coverage at country, region, or city level';
COMMENT ON COLUMN publisher_coverage.coverage_level IS 'Level of coverage: country, region, or city';
COMMENT ON COLUMN publisher_coverage.priority IS 'Priority for this coverage (1-10, higher = more prominent)';

-- Function to find publishers for a city with priority ordering
CREATE OR REPLACE FUNCTION get_publishers_for_city(p_city_id UUID)
RETURNS TABLE (
    publisher_id UUID,
    publisher_name TEXT,
    coverage_level TEXT,
    priority INTEGER,
    match_type TEXT
) AS $$
DECLARE
    v_city RECORD;
BEGIN
    -- Get city details
    SELECT c.id, c.country_code, c.region INTO v_city
    FROM cities c WHERE c.id = p_city_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Return publishers matching this city, ordered by specificity then priority
    RETURN QUERY
    SELECT DISTINCT ON (pc.publisher_id)
        pc.publisher_id,
        p.name::TEXT as publisher_name,
        pc.coverage_level,
        pc.priority,
        CASE
            WHEN pc.coverage_level = 'city' THEN 'exact_city'
            WHEN pc.coverage_level = 'region' THEN 'region_match'
            WHEN pc.coverage_level = 'country' THEN 'country_match'
        END as match_type
    FROM publisher_coverage pc
    JOIN publishers p ON p.id = pc.publisher_id
    WHERE pc.is_active = TRUE
      AND p.status = 'active'
      AND (
        -- Exact city match
        (pc.coverage_level = 'city' AND pc.city_id = p_city_id)
        OR
        -- Region match
        (pc.coverage_level = 'region' AND pc.country_code = v_city.country_code AND pc.region = v_city.region)
        OR
        -- Country match
        (pc.coverage_level = 'country' AND pc.country_code = v_city.country_code)
      )
    ORDER BY pc.publisher_id,
             CASE pc.coverage_level
                 WHEN 'city' THEN 1
                 WHEN 'region' THEN 2
                 WHEN 'country' THEN 3
             END,
             pc.priority DESC;
END;
$$ LANGUAGE plpgsql;
