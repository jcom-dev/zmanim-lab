-- ============================================
-- ZMANIM LAB - CONSOLIDATED INITIAL MIGRATION
-- ============================================
-- This migration creates the complete database schema for Zmanim Lab.
-- Consolidated from 26 individual migrations on 2025-11-30.
--
-- Tables created:
-- 1. Core Tables: publishers, algorithms, system_config
-- 2. Geography: countries, cities, publisher_coverage
-- 3. Zmanim: master_zmanim_registry, zmanim_templates, publisher_zmanim, zman_definitions
-- 4. Tags & Categories: zman_tags, master_zman_tags, day_types, jewish_events
-- 5. Versioning: publisher_zman_versions, zman_registry_requests
-- 6. AI Features: embeddings, ai_index_status, ai_audit_logs, explanation_cache
-- 7. User Management: publisher_requests, publisher_invitations, password_reset_tokens, publisher_onboarding
-- 8. Display & Events: zman_display_contexts, master_zman_events, publisher_zman_events
-- 9. Primitives: astronomical_primitives

-- ============================================
-- EXTENSIONS
-- ============================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";
-- pgvector extension is optional (for RAG features) - may not be available in all environments
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS "vector";
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgvector extension not available - RAG features will be disabled';
END $$;
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For fuzzy text search (similarity function)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- PART 1: CORE TABLES
-- ============================================

-- Publishers table
CREATE TABLE publishers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    organization TEXT,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    website TEXT,
    description TEXT,
    logo_url TEXT,
    location GEOGRAPHY(POINT, 4326),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    timezone TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'suspended')),
    verification_token TEXT,
    verified_at TIMESTAMPTZ,
    clerk_user_id TEXT UNIQUE,
    is_published BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_publishers_status ON publishers(status);
CREATE INDEX idx_publishers_location ON publishers USING GIST(location);
CREATE INDEX idx_publishers_clerk_user_id ON publishers(clerk_user_id);

CREATE TRIGGER update_publishers_updated_at
    BEFORE UPDATE ON publishers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE publishers IS 'Publishers who provide zmanim calculations';
COMMENT ON COLUMN publishers.is_published IS 'Whether the publisher profile and zmanim are publicly visible';

-- Algorithms table
CREATE TABLE algorithms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    configuration JSONB,
    status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'pending', 'published', 'deprecated')),
    is_public BOOLEAN DEFAULT FALSE,
    forked_from UUID REFERENCES algorithms(id) ON DELETE SET NULL,
    attribution_text TEXT,
    fork_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_algorithms_publisher_id ON algorithms(publisher_id);
CREATE INDEX idx_algorithms_status ON algorithms(status);
CREATE INDEX idx_algorithms_public ON algorithms(is_public) WHERE is_public = true;
CREATE INDEX idx_algorithms_forked_from ON algorithms(forked_from) WHERE forked_from IS NOT NULL;

CREATE TRIGGER update_algorithms_updated_at
    BEFORE UPDATE ON algorithms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE algorithms IS 'Algorithm configurations for publishers';
COMMENT ON COLUMN algorithms.is_public IS 'Whether this algorithm is visible and can be copied/forked by other publishers';
COMMENT ON COLUMN algorithms.forked_from IS 'Reference to the source algorithm if this was forked';
COMMENT ON COLUMN algorithms.attribution_text IS 'Attribution text shown for forked algorithms';
COMMENT ON COLUMN algorithms.fork_count IS 'Number of times this algorithm has been forked';

-- System Config table
CREATE TABLE system_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_system_config_key ON system_config(key);

CREATE TRIGGER update_system_config_updated_at
    BEFORE UPDATE ON system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default system configs
INSERT INTO system_config (key, value, description) VALUES
    ('publisher_registration', '{"enabled": true, "require_approval": true}', 'Publisher registration settings'),
    ('default_algorithm_template', '{"name": "Standard GRA", "description": "Default algorithm template based on GRA"}', 'Default algorithm template for new publishers'),
    ('cache_ttl', '{"zmanim": 86400, "cities": 604800, "algorithms": 3600}', 'Cache TTL settings in seconds')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- PART 2: GEOGRAPHY TABLES
-- ============================================

-- Countries table
CREATE TABLE countries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(2) UNIQUE NOT NULL,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Cities table
CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    hebrew_name TEXT,
    country_code VARCHAR(2) NOT NULL,
    region TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    timezone TEXT NOT NULL,
    elevation_meters INTEGER DEFAULT 0,
    population INTEGER,
    location GEOGRAPHY(POINT, 4326) GENERATED ALWAYS AS (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography) STORED,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_cities_country ON cities(country_code);
CREATE INDEX idx_cities_name ON cities(name);
CREATE INDEX idx_cities_location ON cities USING GIST(location);
CREATE INDEX idx_cities_region ON cities(country_code, region);

-- Publisher Coverage table
CREATE TABLE publisher_coverage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    coverage_level TEXT NOT NULL CHECK (coverage_level IN ('country', 'region', 'city')),
    country_code VARCHAR(2),
    region TEXT,
    city_id UUID REFERENCES cities(id) ON DELETE CASCADE,
    priority INTEGER DEFAULT 5 CHECK (priority >= 1 AND priority <= 10),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT valid_coverage_data CHECK (
        (coverage_level = 'country' AND country_code IS NOT NULL AND region IS NULL AND city_id IS NULL) OR
        (coverage_level = 'region' AND country_code IS NOT NULL AND region IS NOT NULL AND city_id IS NULL) OR
        (coverage_level = 'city' AND city_id IS NOT NULL)
    )
);

CREATE INDEX idx_publisher_coverage_publisher ON publisher_coverage(publisher_id);
CREATE INDEX idx_publisher_coverage_country ON publisher_coverage(country_code) WHERE coverage_level = 'country';
CREATE INDEX idx_publisher_coverage_region ON publisher_coverage(country_code, region) WHERE coverage_level = 'region';
CREATE INDEX idx_publisher_coverage_city ON publisher_coverage(city_id) WHERE coverage_level = 'city';
CREATE INDEX idx_publisher_coverage_active ON publisher_coverage(is_active);

CREATE UNIQUE INDEX idx_publisher_coverage_unique_country
    ON publisher_coverage(publisher_id, country_code) WHERE coverage_level = 'country';
CREATE UNIQUE INDEX idx_publisher_coverage_unique_region
    ON publisher_coverage(publisher_id, country_code, region) WHERE coverage_level = 'region';
CREATE UNIQUE INDEX idx_publisher_coverage_unique_city
    ON publisher_coverage(publisher_id, city_id) WHERE coverage_level = 'city';

CREATE TRIGGER update_publisher_coverage_updated_at
    BEFORE UPDATE ON publisher_coverage
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

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
    SELECT c.id, c.country_code, c.region INTO v_city
    FROM cities c WHERE c.id = p_city_id;

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

-- ============================================
-- PART 3: ZMAN DEFINITIONS (Legacy)
-- ============================================

CREATE TABLE zman_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    name_hebrew TEXT NOT NULL,
    name_english TEXT NOT NULL,
    transliteration TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'general',
    sort_order INT DEFAULT 0,
    is_standard BOOLEAN DEFAULT FALSE,
    halachic_notes TEXT,
    halachic_source VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hebrew_name CHECK (name_hebrew ~ '[א-ת]')
);

CREATE INDEX idx_zman_definitions_key ON zman_definitions(key);
CREATE INDEX idx_zman_definitions_category ON zman_definitions(category);

CREATE TRIGGER update_zman_definitions_updated_at
    BEFORE UPDATE ON zman_definitions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON COLUMN zman_definitions.halachic_notes IS 'Markdown-formatted halachic documentation and sources';
COMMENT ON COLUMN zman_definitions.halachic_source IS 'Primary halachic source reference';

-- ============================================
-- PART 4: MASTER ZMANIM REGISTRY
-- ============================================

CREATE TABLE master_zmanim_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zman_key VARCHAR(100) UNIQUE NOT NULL,
    canonical_hebrew_name TEXT NOT NULL,
    canonical_english_name TEXT NOT NULL,
    transliteration TEXT,
    description TEXT,
    halachic_notes TEXT,
    halachic_source VARCHAR(500),
    time_category VARCHAR(50) NOT NULL,
    default_formula_dsl TEXT NOT NULL,
    is_core BOOLEAN DEFAULT false,
    is_hidden BOOLEAN DEFAULT false NOT NULL,
    sort_order INT DEFAULT 0,
    created_by VARCHAR(255),
    updated_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_time_category CHECK (time_category IN ('dawn', 'sunrise', 'morning', 'midday', 'afternoon', 'sunset', 'nightfall', 'midnight'))
);

CREATE INDEX idx_master_registry_key ON master_zmanim_registry(zman_key);
CREATE INDEX idx_master_registry_category ON master_zmanim_registry(time_category);
CREATE INDEX idx_master_registry_sort ON master_zmanim_registry(time_category, sort_order);
CREATE INDEX idx_master_registry_hidden ON master_zmanim_registry(is_hidden);

CREATE OR REPLACE FUNCTION update_master_registry_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER master_registry_updated_at
    BEFORE UPDATE ON master_zmanim_registry
    FOR EACH ROW
    EXECUTE FUNCTION update_master_registry_updated_at();

COMMENT ON TABLE master_zmanim_registry IS 'Canonical list of all zmanim - publishers must select from this registry';
COMMENT ON COLUMN master_zmanim_registry.zman_key IS 'Unique identifier for this zman type';
COMMENT ON COLUMN master_zmanim_registry.time_category IS 'Time of day grouping for UI display';
COMMENT ON COLUMN master_zmanim_registry.is_core IS 'If true, this zman is a core/essential zman that cannot be removed from the registry';
COMMENT ON COLUMN master_zmanim_registry.is_hidden IS 'When true, this zman is hidden from public registry queries but visible to admins. Useful for deprecated or experimental zmanim.';
COMMENT ON COLUMN master_zmanim_registry.halachic_notes IS 'Halachic background and reasoning for this zman';
COMMENT ON COLUMN master_zmanim_registry.created_by IS 'Clerk user ID of the admin who created this zman';
COMMENT ON COLUMN master_zmanim_registry.updated_by IS 'Clerk user ID of the admin who last updated this zman';

-- ============================================
-- PART 5: ZMAN TAGS
-- ============================================

CREATE TABLE zman_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name_hebrew TEXT NOT NULL,
    display_name_english TEXT NOT NULL,
    tag_type VARCHAR(50) NOT NULL CHECK (tag_type IN ('event', 'timing', 'behavior', 'shita', 'method')),
    description TEXT,
    color VARCHAR(7),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX idx_zman_tags_type ON zman_tags(tag_type);
CREATE INDEX idx_zman_tags_key ON zman_tags(tag_key);

CREATE TABLE master_zman_tags (
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES zman_tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (master_zman_id, tag_id)
);

CREATE INDEX idx_master_zman_tags_zman ON master_zman_tags(master_zman_id);
CREATE INDEX idx_master_zman_tags_tag ON master_zman_tags(tag_id);

COMMENT ON TABLE zman_tags IS 'Tags for categorizing zmanim by shita or calculation method';
COMMENT ON TABLE master_zman_tags IS 'Many-to-many relationship between zmanim and tags';

-- ============================================
-- PART 6: ZMANIM TEMPLATES
-- ============================================

CREATE TABLE zmanim_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zman_key TEXT UNIQUE NOT NULL,
    hebrew_name TEXT NOT NULL,
    english_name TEXT NOT NULL,
    formula_dsl TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('essential', 'optional')),
    description TEXT,
    is_required BOOLEAN DEFAULT false NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX idx_zmanim_templates_category ON zmanim_templates(category);
CREATE INDEX idx_zmanim_templates_sort ON zmanim_templates(sort_order);

COMMENT ON TABLE zmanim_templates IS 'System-wide default zmanim formulas that publishers can copy from';
COMMENT ON COLUMN zmanim_templates.formula_dsl IS 'DSL formula string. proportional_hours(N, gra) returns absolute time N hours after sunrise. proportional_hours(N, mga) returns N hours after dawn (72min before sunrise).';

-- ============================================
-- PART 7: PUBLISHER ZMANIM
-- ============================================

CREATE TABLE publisher_zmanim (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    zman_key TEXT NOT NULL,
    hebrew_name TEXT NOT NULL,
    english_name TEXT NOT NULL,
    formula_dsl TEXT NOT NULL,
    ai_explanation TEXT,
    publisher_comment TEXT,
    is_enabled BOOLEAN DEFAULT true NOT NULL,
    is_visible BOOLEAN DEFAULT true NOT NULL,
    is_published BOOLEAN DEFAULT false NOT NULL,
    is_custom BOOLEAN DEFAULT false NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('essential', 'optional', 'custom')),
    dependencies TEXT[] DEFAULT '{}' NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    master_zman_id UUID REFERENCES master_zmanim_registry(id),
    current_version INT DEFAULT 1,
    deleted_at TIMESTAMPTZ,
    deleted_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(publisher_id, zman_key)
);

CREATE INDEX idx_publisher_zmanim_publisher ON publisher_zmanim(publisher_id);
CREATE INDEX idx_publisher_zmanim_enabled ON publisher_zmanim(publisher_id, is_enabled) WHERE is_enabled = true;
CREATE INDEX idx_publisher_zmanim_category ON publisher_zmanim(category);
CREATE INDEX idx_publisher_zmanim_custom ON publisher_zmanim(publisher_id, is_custom) WHERE is_custom = true;
CREATE INDEX idx_publisher_zmanim_published ON publisher_zmanim(publisher_id, is_published) WHERE is_published = true;
CREATE INDEX idx_publisher_zmanim_active ON publisher_zmanim(publisher_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_publisher_zmanim_deleted ON publisher_zmanim(publisher_id, deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_publisher_zmanim_master ON publisher_zmanim(master_zman_id);

CREATE OR REPLACE FUNCTION update_publisher_zmanim_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER publisher_zmanim_updated_at
    BEFORE UPDATE ON publisher_zmanim
    FOR EACH ROW
    EXECUTE FUNCTION update_publisher_zmanim_updated_at();

COMMENT ON TABLE publisher_zmanim IS 'Individual zmanim formulas for each publisher using DSL syntax';
COMMENT ON COLUMN publisher_zmanim.formula_dsl IS 'DSL formula string. Examples: "proportional_hours(3, gra)" for 3 hours after sunrise, "solar(16.1, before_sunrise)" for dawn';
COMMENT ON COLUMN publisher_zmanim.dependencies IS 'Auto-extracted @references from formula_dsl';
COMMENT ON COLUMN publisher_zmanim.category IS 'essential = always enabled, optional = can toggle, custom = user created';
COMMENT ON COLUMN publisher_zmanim.is_enabled IS 'Whether this zman is active in the algorithm (for preview/calculation)';
COMMENT ON COLUMN publisher_zmanim.is_published IS 'Whether this zman is publicly visible to end users';

-- ============================================
-- PART 8: PUBLISHER ZMAN VERSIONS
-- ============================================

CREATE TABLE publisher_zman_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    formula_dsl TEXT NOT NULL,
    created_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(publisher_zman_id, version_number)
);

CREATE INDEX idx_zman_versions_lookup ON publisher_zman_versions(publisher_zman_id, version_number DESC);

CREATE OR REPLACE FUNCTION get_next_zman_version(p_publisher_zman_id UUID)
RETURNS INT AS $$
DECLARE
    max_version INT;
BEGIN
    SELECT COALESCE(MAX(version_number), 0) INTO max_version
    FROM publisher_zman_versions
    WHERE publisher_zman_id = p_publisher_zman_id;

    RETURN max_version + 1;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION prune_zman_versions()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM publisher_zman_versions
    WHERE publisher_zman_id = NEW.publisher_zman_id
    AND id NOT IN (
        SELECT id
        FROM publisher_zman_versions
        WHERE publisher_zman_id = NEW.publisher_zman_id
        ORDER BY version_number DESC
        LIMIT 7
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prune_versions_trigger
    AFTER INSERT ON publisher_zman_versions
    FOR EACH ROW
    EXECUTE FUNCTION prune_zman_versions();

COMMENT ON TABLE publisher_zman_versions IS 'Version history for each publisher zman (max 7 versions, formula changes only)';

-- ============================================
-- PART 9: ZMAN REGISTRY REQUESTS
-- ============================================

CREATE TABLE zman_registry_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    requested_key VARCHAR(100) NOT NULL,
    requested_hebrew_name TEXT NOT NULL,
    requested_english_name TEXT NOT NULL,
    requested_formula_dsl TEXT,
    time_category VARCHAR(50) NOT NULL,
    justification TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL,
    reviewed_by VARCHAR(255),
    reviewed_at TIMESTAMPTZ,
    reviewer_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_request_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX idx_zman_requests_publisher ON zman_registry_requests(publisher_id);
CREATE INDEX idx_zman_requests_status ON zman_registry_requests(status);

COMMENT ON TABLE zman_registry_requests IS 'Requests from publishers to add new zmanim to the master registry';

-- ============================================
-- PART 10: DAY TYPES (Deprecated - use jewish_events)
-- ============================================

CREATE TABLE day_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name_hebrew TEXT NOT NULL,
    display_name_english TEXT NOT NULL,
    description TEXT,
    parent_type VARCHAR(100),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX idx_day_types_name ON day_types(name);
CREATE INDEX idx_day_types_parent ON day_types(parent_type);

CREATE TABLE master_zman_day_types (
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    day_type_id UUID NOT NULL REFERENCES day_types(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (master_zman_id, day_type_id)
);

CREATE INDEX idx_master_zman_day_types_zman ON master_zman_day_types(master_zman_id);
CREATE INDEX idx_master_zman_day_types_day ON master_zman_day_types(day_type_id);

CREATE TABLE publisher_zman_day_types (
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    day_type_id UUID NOT NULL REFERENCES day_types(id) ON DELETE CASCADE,
    is_visible BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (publisher_zman_id, day_type_id)
);

CREATE INDEX idx_pub_zman_day_types_zman ON publisher_zman_day_types(publisher_zman_id);
CREATE INDEX idx_pub_zman_day_types_day ON publisher_zman_day_types(day_type_id);

CREATE OR REPLACE FUNCTION update_publisher_zman_day_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER publisher_zman_day_types_updated_at
    BEFORE UPDATE ON publisher_zman_day_types
    FOR EACH ROW
    EXECUTE FUNCTION update_publisher_zman_day_types_updated_at();

COMMENT ON TABLE day_types IS 'DEPRECATED: Use jewish_events instead. Types of days for which zmanim can be configured.';
COMMENT ON COLUMN day_types.parent_type IS 'Parent type name for hierarchical day types';
COMMENT ON TABLE master_zman_day_types IS 'DEPRECATED: Use master_zman_events instead.';
COMMENT ON TABLE publisher_zman_day_types IS 'DEPRECATED: Use publisher_zman_events instead.';

-- ============================================
-- PART 11: JEWISH EVENTS
-- ============================================

CREATE TABLE jewish_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name_hebrew TEXT NOT NULL,
    name_english TEXT NOT NULL,
    event_type VARCHAR(30) NOT NULL,
    duration_days_israel INT DEFAULT 1,
    duration_days_diaspora INT DEFAULT 1,
    fast_start_type VARCHAR(20),
    parent_event_code VARCHAR(50),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_event_type CHECK (event_type IN ('weekly', 'yom_tov', 'fast', 'informational')),
    CONSTRAINT chk_fast_start_type CHECK (fast_start_type IS NULL OR fast_start_type IN ('dawn', 'sunset'))
);

CREATE INDEX idx_jewish_events_code ON jewish_events(code);
CREATE INDEX idx_jewish_events_type ON jewish_events(event_type);
CREATE INDEX idx_jewish_events_parent ON jewish_events(parent_event_code);

COMMENT ON TABLE jewish_events IS 'Canonical list of Jewish events (Shabbos, Yom Tov, fasts, etc.) with Israel/Diaspora duration differences';
COMMENT ON COLUMN jewish_events.event_type IS 'Type of event: weekly (Shabbos), yom_tov, fast, or informational (no linked zmanim)';
COMMENT ON COLUMN jewish_events.duration_days_israel IS 'Number of days this event lasts in Israel';
COMMENT ON COLUMN jewish_events.duration_days_diaspora IS 'Number of days this event lasts in the Diaspora';
COMMENT ON COLUMN jewish_events.fast_start_type IS 'For fasts: dawn (regular fasts) or sunset (Yom Kippur, Tisha B''Av)';

-- ============================================
-- PART 12: MASTER ZMAN EVENTS
-- ============================================

CREATE TABLE master_zman_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    jewish_event_id UUID NOT NULL REFERENCES jewish_events(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT true,
    applies_to_day INT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(master_zman_id, jewish_event_id, applies_to_day)
);

CREATE INDEX idx_master_zman_events_zman ON master_zman_events(master_zman_id);
CREATE INDEX idx_master_zman_events_event ON master_zman_events(jewish_event_id);

COMMENT ON TABLE master_zman_events IS 'Links zmanim to the Jewish events they apply to';
COMMENT ON COLUMN master_zman_events.applies_to_day IS 'NULL = all days of event, 1 = day 1 only, 2 = day 2 only (for 2-day Yom Tov in Diaspora)';

-- ============================================
-- PART 13: ZMAN DISPLAY CONTEXTS
-- ============================================

CREATE TABLE zman_display_contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    context_code VARCHAR(50) NOT NULL,
    display_name_hebrew TEXT NOT NULL,
    display_name_english TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(master_zman_id, context_code)
);

CREATE INDEX idx_zman_display_contexts_zman ON zman_display_contexts(master_zman_id);
CREATE INDEX idx_zman_display_contexts_context ON zman_display_contexts(context_code);

COMMENT ON TABLE zman_display_contexts IS 'Context-specific display names for zmanim with the same calculation but different labels';
COMMENT ON COLUMN zman_display_contexts.context_code IS 'Context identifier - matches jewish_events.code or special values';

-- ============================================
-- PART 14: PUBLISHER ZMAN EVENTS
-- ============================================

CREATE TABLE publisher_zman_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    jewish_event_id UUID NOT NULL REFERENCES jewish_events(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    applies_to_day INT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(publisher_zman_id, jewish_event_id, applies_to_day)
);

CREATE INDEX idx_publisher_zman_events_zman ON publisher_zman_events(publisher_zman_id);
CREATE INDEX idx_publisher_zman_events_event ON publisher_zman_events(jewish_event_id);

CREATE OR REPLACE FUNCTION update_publisher_zman_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER publisher_zman_events_updated_at
    BEFORE UPDATE ON publisher_zman_events
    FOR EACH ROW
    EXECUTE FUNCTION update_publisher_zman_events_updated_at();

COMMENT ON TABLE publisher_zman_events IS 'Publisher overrides for which events their zmanim apply to';

-- ============================================
-- PART 15: ASTRONOMICAL PRIMITIVES
-- ============================================

CREATE TABLE astronomical_primitives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variable_name VARCHAR(50) UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    formula_dsl TEXT NOT NULL,
    category VARCHAR(50) NOT NULL,
    calculation_type VARCHAR(30) NOT NULL,
    solar_angle DECIMAL(5,2),
    is_dawn BOOLEAN,
    edge_type VARCHAR(20) DEFAULT 'center',
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_calculation_type CHECK (calculation_type IN ('horizon', 'solar_angle', 'transit')),
    CONSTRAINT chk_edge_type CHECK (edge_type IN ('center', 'top_edge', 'bottom_edge')),
    CONSTRAINT chk_category CHECK (category IN (
        'horizon',
        'civil_twilight',
        'nautical_twilight',
        'astronomical_twilight',
        'solar_position'
    )),
    CONSTRAINT chk_solar_angle CHECK (
        (calculation_type = 'solar_angle' AND solar_angle IS NOT NULL) OR
        (calculation_type != 'solar_angle')
    )
);

CREATE INDEX idx_astronomical_primitives_variable_name ON astronomical_primitives(variable_name);
CREATE INDEX idx_astronomical_primitives_category ON astronomical_primitives(category);

COMMENT ON TABLE astronomical_primitives IS 'Canonical registry of astronomical times that can be referenced in DSL formulas. These are pure astronomical calculations with no halachic interpretation.';
COMMENT ON COLUMN astronomical_primitives.variable_name IS 'The unique identifier used in DSL formulas (e.g., sunrise, nautical_dawn). Must be snake_case.';
COMMENT ON COLUMN astronomical_primitives.formula_dsl IS 'The DSL formula that calculates this time. Base primitives use their own name, derived use solar() function.';
COMMENT ON COLUMN astronomical_primitives.calculation_type IS 'How to compute: horizon (0° crossing), solar_angle (degrees below horizon), transit (noon/midnight)';
COMMENT ON COLUMN astronomical_primitives.solar_angle IS 'Degrees below horizon for solar_angle calculations (6° civil, 12° nautical, 18° astronomical)';
COMMENT ON COLUMN astronomical_primitives.is_dawn IS 'True for morning events (dawn/sunrise), false for evening events (dusk/sunset), NULL for position events (noon/midnight)';
COMMENT ON COLUMN astronomical_primitives.edge_type IS 'Which part of the sun: center (geometric), top_edge (visible sunrise/sunset), bottom_edge';

-- ============================================
-- PART 16: AI FEATURES
-- ============================================

-- Embeddings table for RAG (only created if pgvector extension is available)
DO $$
BEGIN
    -- Check if vector type exists (pgvector extension loaded)
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'vector') THEN
        CREATE TABLE IF NOT EXISTS embeddings (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            source VARCHAR(255) NOT NULL,
            content_type VARCHAR(50) NOT NULL,
            chunk_index INT NOT NULL,
            content TEXT NOT NULL,
            metadata JSONB DEFAULT '{}',
            embedding vector(1536) NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            updated_at TIMESTAMP DEFAULT NOW(),
            UNIQUE(source, chunk_index)
        );

        CREATE INDEX IF NOT EXISTS embeddings_vector_idx ON embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
        CREATE INDEX IF NOT EXISTS embeddings_source_idx ON embeddings(source);
        CREATE INDEX IF NOT EXISTS embeddings_content_type_idx ON embeddings(content_type);
    ELSE
        RAISE NOTICE 'Skipping embeddings table - pgvector extension not available';
    END IF;
END $$;

CREATE OR REPLACE FUNCTION update_embeddings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger only if embeddings table exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'embeddings') THEN
        DROP TRIGGER IF EXISTS embeddings_updated_at ON embeddings;
        CREATE TRIGGER embeddings_updated_at
            BEFORE UPDATE ON embeddings
            FOR EACH ROW
            EXECUTE FUNCTION update_embeddings_updated_at();

        COMMENT ON TABLE embeddings IS 'Vector embeddings for RAG semantic search';
        COMMENT ON COLUMN embeddings.source IS 'Source document identifier (dsl-spec, kosher-java, halacha)';
        COMMENT ON COLUMN embeddings.content_type IS 'Type of content (documentation, example, source)';
        COMMENT ON COLUMN embeddings.embedding IS 'OpenAI text-embedding-3-small 1536-dimensional vector';
    END IF;
END $$;

-- AI Index Status
CREATE TABLE ai_index_status (
    id SERIAL PRIMARY KEY,
    source VARCHAR(255) NOT NULL UNIQUE,
    total_chunks INT NOT NULL DEFAULT 0,
    last_indexed_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TRIGGER ai_index_status_updated_at
    BEFORE UPDATE ON ai_index_status
    FOR EACH ROW
    EXECUTE FUNCTION update_embeddings_updated_at();

COMMENT ON TABLE ai_index_status IS 'Tracks indexing status for each knowledge source';

-- AI Audit Logs
CREATE TABLE ai_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID REFERENCES publishers(id) ON DELETE SET NULL,
    user_id VARCHAR(255),
    request_type VARCHAR(50) NOT NULL,
    input_text TEXT NOT NULL,
    output_text TEXT,
    tokens_used INT,
    model VARCHAR(100),
    confidence DECIMAL(4,3),
    success BOOLEAN NOT NULL DEFAULT false,
    error_message TEXT,
    duration_ms INT,
    rag_context_used BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ai_audit_publisher ON ai_audit_logs(publisher_id);
CREATE INDEX idx_ai_audit_user ON ai_audit_logs(user_id);
CREATE INDEX idx_ai_audit_created ON ai_audit_logs(created_at DESC);
CREATE INDEX idx_ai_audit_type ON ai_audit_logs(request_type);
CREATE INDEX idx_ai_audit_success ON ai_audit_logs(success);

COMMENT ON TABLE ai_audit_logs IS 'Audit log for all AI-powered formula generation and explanation requests';
COMMENT ON COLUMN ai_audit_logs.request_type IS 'Type of AI request: generate_formula or explain_formula';
COMMENT ON COLUMN ai_audit_logs.confidence IS 'AI confidence score for generated output (0.0 to 1.0)';
COMMENT ON COLUMN ai_audit_logs.rag_context_used IS 'Whether RAG context was included in the prompt';

-- Explanation Cache
CREATE TABLE explanation_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    formula_hash VARCHAR(64) NOT NULL,
    language VARCHAR(10) NOT NULL,
    explanation TEXT NOT NULL,
    source VARCHAR(20) DEFAULT 'ai',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,

    UNIQUE(formula_hash, language)
);

CREATE INDEX idx_explanation_cache_lookup ON explanation_cache(formula_hash, language);
CREATE INDEX idx_explanation_cache_expiry ON explanation_cache(expires_at);

CREATE OR REPLACE FUNCTION cleanup_expired_explanations()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM explanation_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE explanation_cache IS 'Cache for AI-generated formula explanations';
COMMENT ON COLUMN explanation_cache.formula_hash IS 'SHA-256 hash of the formula text';
COMMENT ON COLUMN explanation_cache.expires_at IS 'TTL is typically 7 days';

-- ============================================
-- PART 17: USER MANAGEMENT
-- ============================================

-- Publisher Registration Requests
CREATE TABLE publisher_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    organization TEXT NOT NULL,
    email TEXT NOT NULL,
    website TEXT,
    description TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    rejection_reason TEXT,
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_publisher_requests_status ON publisher_requests(status);
CREATE UNIQUE INDEX idx_publisher_requests_email_pending
    ON publisher_requests(email) WHERE status = 'pending';

-- Publisher Team Invitations
CREATE TABLE publisher_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID REFERENCES publishers(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    invited_by TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_publisher_invitations_token ON publisher_invitations(token);
CREATE INDEX idx_publisher_invitations_publisher ON publisher_invitations(publisher_id);
CREATE INDEX idx_publisher_invitations_email ON publisher_invitations(email, publisher_id);

-- Password Reset Tokens
CREATE TABLE password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_password_reset_tokens_token ON password_reset_tokens(token);
CREATE INDEX idx_password_reset_tokens_email ON password_reset_tokens(email);

-- Publisher Onboarding
CREATE TABLE publisher_onboarding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    current_step INT DEFAULT 0,
    completed_steps INT[] DEFAULT '{}',
    wizard_data JSONB DEFAULT '{}',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    skipped BOOLEAN DEFAULT false,

    UNIQUE(publisher_id)
);

CREATE INDEX idx_onboarding_publisher ON publisher_onboarding(publisher_id);

COMMENT ON TABLE publisher_onboarding IS 'Tracks onboarding wizard state for publishers';
COMMENT ON COLUMN publisher_onboarding.wizard_data IS 'JSON data containing template selection, customizations, and coverage';
COMMENT ON COLUMN publisher_onboarding.skipped IS 'True if publisher skipped the wizard';

-- ============================================
-- PART 18: VIEWS
-- ============================================

CREATE OR REPLACE VIEW publisher_zmanim_with_registry AS
SELECT
    pz.id,
    pz.publisher_id,
    pz.zman_key,
    COALESCE(mr.canonical_hebrew_name, pz.hebrew_name) AS hebrew_name,
    COALESCE(mr.canonical_english_name, pz.english_name) AS english_name,
    mr.transliteration,
    pz.formula_dsl,
    mr.default_formula_dsl,
    pz.ai_explanation,
    pz.publisher_comment,
    pz.is_enabled,
    pz.is_visible,
    COALESCE(pz.is_custom, false) AS is_custom,
    COALESCE(mr.time_category, pz.category) AS time_category,
    pz.category,
    pz.dependencies,
    pz.sort_order,
    pz.current_version,
    pz.deleted_at,
    pz.deleted_by,
    pz.created_at,
    pz.updated_at,
    pz.master_zman_id,
    mr.description AS zman_description,
    mr.halachic_notes,
    mr.halachic_source,
    mr.is_core
FROM publisher_zmanim pz
LEFT JOIN master_zmanim_registry mr ON pz.master_zman_id = mr.id;

COMMENT ON VIEW publisher_zmanim_with_registry IS 'Convenience view that joins publisher_zmanim with master registry data';
COMMENT ON TABLE publisher_invitations IS 'DEPRECATED: This table is no longer used. User management now creates users directly via Clerk instead of using invitations. Table kept for historical reference but will be empty.';
