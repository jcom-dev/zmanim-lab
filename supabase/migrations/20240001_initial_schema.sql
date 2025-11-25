-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Publishers table
CREATE TABLE publishers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    organization VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    description TEXT,
    website VARCHAR(500),
    logo_url VARCHAR(500),
    contact_info JSONB DEFAULT '{}',
    status VARCHAR(20) NOT NULL DEFAULT 'pending_verification',
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID REFERENCES auth.users(id),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT publishers_status_check
        CHECK (status IN ('pending_verification', 'verified', 'active', 'suspended', 'retired'))
);

CREATE INDEX idx_publishers_status ON publishers(status);
CREATE INDEX idx_publishers_slug ON publishers(slug);

-- Algorithms table
CREATE TABLE algorithms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    description TEXT,
    formula_definition JSONB NOT NULL,
    calculation_type VARCHAR(50) NOT NULL,
    validation_status VARCHAR(20) DEFAULT 'pending',
    validation_results JSONB,
    is_active BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP WITH TIME ZONE,
    deprecated_at TIMESTAMP WITH TIME ZONE,
    tags TEXT[] DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT algorithms_version_unique UNIQUE (publisher_id, name, version),
    CONSTRAINT algorithms_calc_type_check
        CHECK (calculation_type IN ('solar_depression', 'fixed_minutes', 'proportional', 'custom'))
);

CREATE INDEX idx_algorithms_publisher ON algorithms(publisher_id);
CREATE INDEX idx_algorithms_active ON algorithms(is_active);
CREATE INDEX idx_algorithms_type ON algorithms(calculation_type);

-- Geographic Regions table
CREATE TABLE geographic_regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    name_local VARCHAR(255),
    type VARCHAR(50) NOT NULL,
    parent_id UUID REFERENCES geographic_regions(id),
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    boundary GEOGRAPHY(POLYGON, 4326),
    country_code VARCHAR(2),
    timezone VARCHAR(100) NOT NULL,
    elevation NUMERIC,
    population INT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_geo_regions_location ON geographic_regions USING GIST(location);
CREATE INDEX idx_geo_regions_boundary ON geographic_regions USING GIST(boundary);
CREATE INDEX idx_geo_regions_type ON geographic_regions(type);
CREATE INDEX idx_geo_regions_parent ON geographic_regions(parent_id);

-- Coverage Areas table
CREATE TABLE coverage_areas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    boundary GEOGRAPHY(POLYGON, 4326) NOT NULL,
    center_point GEOGRAPHY(POINT, 4326),
    priority INT DEFAULT 0,
    country_code VARCHAR(2),
    region VARCHAR(100),
    city VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_coverage_publisher ON coverage_areas(publisher_id);
CREATE INDEX idx_coverage_boundary ON coverage_areas USING GIST(boundary);
CREATE INDEX idx_coverage_center ON coverage_areas USING GIST(center_point);
CREATE INDEX idx_coverage_active ON coverage_areas(is_active);

-- User Profiles table
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name VARCHAR(255),
    avatar_url VARCHAR(500),
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Subscriptions table
CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    subscribed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT user_subscriptions_unique UNIQUE (user_id, publisher_id)
);

CREATE INDEX idx_user_subs_user ON user_subscriptions(user_id);
CREATE INDEX idx_user_subs_publisher ON user_subscriptions(publisher_id);

-- Calculation Cache table
CREATE TABLE calculation_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    algorithm_id UUID NOT NULL REFERENCES algorithms(id) ON DELETE CASCADE,
    location_id UUID NOT NULL REFERENCES geographic_regions(id),
    calculation_date DATE NOT NULL,
    zmanim_data JSONB NOT NULL,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    hit_count INT DEFAULT 0,
    CONSTRAINT calc_cache_unique UNIQUE (algorithm_id, location_id, calculation_date)
);

CREATE INDEX idx_calc_cache_algo_loc_date ON calculation_cache(algorithm_id, location_id, calculation_date);
CREATE INDEX idx_calc_cache_expires ON calculation_cache(expires_at);

-- Audit Logs table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL,
    actor_id UUID REFERENCES auth.users(id),
    changes JSONB,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_created ON audit_logs(created_at);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers
CREATE TRIGGER update_publishers_updated_at BEFORE UPDATE ON publishers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_algorithms_updated_at BEFORE UPDATE ON algorithms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_coverage_areas_updated_at BEFORE UPDATE ON coverage_areas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_geo_regions_updated_at BEFORE UPDATE ON geographic_regions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
