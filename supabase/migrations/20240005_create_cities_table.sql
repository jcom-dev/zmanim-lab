-- Migration: Create cities table for global location system
-- Story: 1.5 Global Location System
-- Date: 2025-11-25

-- Enable pg_trgm extension for fuzzy search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create cities table
CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    name_ascii TEXT NOT NULL,  -- ASCII version for search
    country TEXT NOT NULL,
    country_code VARCHAR(2) NOT NULL,
    region TEXT,               -- state, province, county, etc.
    region_type TEXT,          -- 'state', 'province', 'county', 'district', 'prefecture'
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    timezone TEXT NOT NULL,
    population INTEGER,
    location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography
    ) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigram index for fuzzy search on name
CREATE INDEX idx_cities_name_trgm ON cities USING gin(name_ascii gin_trgm_ops);

-- B-tree indexes for filtering
CREATE INDEX idx_cities_country_code ON cities(country_code);
CREATE INDEX idx_cities_country ON cities(country);
CREATE INDEX idx_cities_population ON cities(population DESC NULLS LAST);

-- Spatial index for nearby queries
CREATE INDEX idx_cities_location ON cities USING GIST(location);

-- Composite index for search ranking
CREATE INDEX idx_cities_search_rank ON cities(country_code, population DESC NULLS LAST);

-- Add trigger for updated_at
CREATE TRIGGER update_cities_updated_at
    BEFORE UPDATE ON cities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add comment
COMMENT ON TABLE cities IS 'Global cities database for location search and selection';
COMMENT ON COLUMN cities.region_type IS 'Type of administrative region: state (US), province (CA), county (UK), district (IL), prefecture (JP)';
