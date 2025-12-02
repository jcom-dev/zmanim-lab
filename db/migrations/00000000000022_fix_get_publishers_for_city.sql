-- Fix get_publishers_for_city function to work with normalized schema
-- The cities table no longer has country_code column - it uses country_id with FK to geo_countries

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
    -- Get city info including country code via join with geo_countries
    SELECT c.id, co.code as country_code, r.name as region
    INTO v_city
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    LEFT JOIN geo_regions r ON c.region_id = r.id
    WHERE c.id = p_city_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

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
        (pc.coverage_level = 'city' AND pc.city_id = p_city_id)
        OR
        (pc.coverage_level = 'region' AND pc.country_code = v_city.country_code AND pc.region = v_city.region)
        OR
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

COMMENT ON FUNCTION get_publishers_for_city(UUID) IS 'Find publishers serving a city based on coverage (city, region, or country level)';
