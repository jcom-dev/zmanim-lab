-- Zmanim Lab Database Schema
-- Migration 1: Complete schema with tables, indexes, functions, triggers, and constraints

-- ============================================================================
-- EXTENSIONS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;
COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;
COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

CREATE FUNCTION public.cleanup_expired_explanations() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM explanation_cache WHERE expires_at < NOW();
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;

CREATE FUNCTION public.get_next_zman_version(p_publisher_zman_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    max_version INT;
BEGIN
    SELECT COALESCE(MAX(version_number), 0) INTO max_version
    FROM publisher_zman_versions
    WHERE publisher_zman_id = p_publisher_zman_id;
    RETURN max_version + 1;
END;
$$;

CREATE FUNCTION public.get_publishers_for_city(p_city_id uuid) RETURNS TABLE(publisher_id uuid, publisher_name text, coverage_level text, priority integer, match_type text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_city RECORD;
BEGIN
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
$$;
COMMENT ON FUNCTION public.get_publishers_for_city(p_city_id uuid) IS 'Find publishers serving a city based on coverage (city, region, or country level)';

CREATE FUNCTION public.prune_zman_versions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;

CREATE FUNCTION public.update_embeddings_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE FUNCTION public.update_master_registry_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION public.update_publisher_zman_day_types_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION public.update_publisher_zman_events_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION public.update_publisher_zmanim_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- ============================================================================
-- TABLES
-- ============================================================================

-- AI Audit Logs
CREATE TABLE public.ai_audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid,
    user_id character varying(255),
    request_type character varying(50) NOT NULL,
    input_text text NOT NULL,
    output_text text,
    tokens_used integer,
    model character varying(100),
    confidence numeric(4,3),
    success boolean DEFAULT false NOT NULL,
    error_message text,
    duration_ms integer,
    rag_context_used boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.ai_audit_logs IS 'Audit log for all AI-powered formula generation and explanation requests';
COMMENT ON COLUMN public.ai_audit_logs.request_type IS 'Type of AI request: generate_formula or explain_formula';
COMMENT ON COLUMN public.ai_audit_logs.confidence IS 'AI confidence score for generated output (0.0 to 1.0)';
COMMENT ON COLUMN public.ai_audit_logs.rag_context_used IS 'Whether RAG context was included in the prompt';

-- AI Index Status
CREATE TABLE public.ai_index_status (
    id integer NOT NULL GENERATED BY DEFAULT AS IDENTITY,
    source character varying(255) NOT NULL,
    total_chunks integer DEFAULT 0 NOT NULL,
    last_indexed_at timestamp without time zone,
    status character varying(50) DEFAULT 'pending'::character varying,
    error_message text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);
COMMENT ON TABLE public.ai_index_status IS 'Tracks indexing status for each knowledge source. After migrations, run: cd api && go run cmd/indexer/main.go';

-- Algorithms
CREATE TABLE public.algorithms (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    name text NOT NULL,
    description text,
    configuration jsonb,
    status text DEFAULT 'draft'::text,
    is_public boolean DEFAULT false,
    forked_from uuid,
    attribution_text text,
    fork_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT algorithms_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'pending'::text, 'published'::text, 'deprecated'::text])))
);
COMMENT ON TABLE public.algorithms IS 'Algorithm configurations for publishers';
COMMENT ON COLUMN public.algorithms.is_public IS 'Whether this algorithm is visible and can be copied/forked by other publishers';
COMMENT ON COLUMN public.algorithms.forked_from IS 'Reference to the source algorithm if this was forked';
COMMENT ON COLUMN public.algorithms.attribution_text IS 'Attribution text shown for forked algorithms';
COMMENT ON COLUMN public.algorithms.fork_count IS 'Number of times this algorithm has been forked';

-- Astronomical Primitives
CREATE TABLE public.astronomical_primitives (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    variable_name character varying(50) NOT NULL,
    display_name text NOT NULL,
    description text,
    formula_dsl text NOT NULL,
    category character varying(50) NOT NULL,
    calculation_type character varying(30) NOT NULL,
    solar_angle numeric(5,2),
    is_dawn boolean,
    edge_type character varying(20) DEFAULT 'center'::character varying,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_calculation_type CHECK (((calculation_type)::text = ANY ((ARRAY['horizon'::character varying, 'solar_angle'::character varying, 'transit'::character varying])::text[]))),
    CONSTRAINT chk_category CHECK (((category)::text = ANY ((ARRAY['horizon'::character varying, 'civil_twilight'::character varying, 'nautical_twilight'::character varying, 'astronomical_twilight'::character varying, 'solar_position'::character varying])::text[]))),
    CONSTRAINT chk_edge_type CHECK (((edge_type)::text = ANY ((ARRAY['center'::character varying, 'top_edge'::character varying, 'bottom_edge'::character varying])::text[]))),
    CONSTRAINT chk_solar_angle CHECK (((((calculation_type)::text = 'solar_angle'::text) AND (solar_angle IS NOT NULL)) OR ((calculation_type)::text <> 'solar_angle'::text)))
);
COMMENT ON TABLE public.astronomical_primitives IS 'Canonical registry of astronomical times that can be referenced in DSL formulas. These are pure astronomical calculations with no halachic interpretation.';
COMMENT ON COLUMN public.astronomical_primitives.variable_name IS 'The unique identifier used in DSL formulas (e.g., sunrise, nautical_dawn). Must be snake_case.';
COMMENT ON COLUMN public.astronomical_primitives.formula_dsl IS 'The DSL formula that calculates this time. Base primitives use their own name, derived use solar() function.';
COMMENT ON COLUMN public.astronomical_primitives.calculation_type IS 'How to compute: horizon (0° crossing), solar_angle (degrees below horizon), transit (noon/midnight)';
COMMENT ON COLUMN public.astronomical_primitives.solar_angle IS 'Degrees below horizon for solar_angle calculations (6° civil, 12° nautical, 18° astronomical)';
COMMENT ON COLUMN public.astronomical_primitives.is_dawn IS 'True for morning events (dawn/sunrise), false for evening events (dusk/sunset), NULL for position events (noon/midnight)';
COMMENT ON COLUMN public.astronomical_primitives.edge_type IS 'Which part of the sun: center (geometric), top_edge (visible sunrise/sunset), bottom_edge';

-- Geo Continents (must be before geo_countries)
CREATE TABLE public.geo_continents (
    id smallint NOT NULL,
    code character varying(2) NOT NULL,
    name text NOT NULL
);
COMMENT ON TABLE public.geo_continents IS 'Lookup table for 7 continents with ISO codes';

-- Geo Countries (must be before geo_regions and cities)
CREATE TABLE public.geo_countries (
    id smallint NOT NULL GENERATED ALWAYS AS IDENTITY,
    code character varying(2) NOT NULL,
    name text NOT NULL,
    continent_id smallint NOT NULL
);
COMMENT ON TABLE public.geo_countries IS 'Lookup table for countries with ISO 3166-1 alpha-2 codes';
COMMENT ON COLUMN public.geo_countries.code IS 'ISO 3166-1 alpha-2 country code (e.g., US, IL, GB)';

-- Geo Regions (must be before cities)
CREATE TABLE public.geo_regions (
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
    country_id smallint NOT NULL,
    code text NOT NULL,
    name text NOT NULL
);
COMMENT ON TABLE public.geo_regions IS 'Lookup table for administrative regions (states, provinces, districts)';
COMMENT ON COLUMN public.geo_regions.code IS 'GeoNames admin1 code within the country';
COMMENT ON COLUMN public.geo_regions.name IS 'Human-readable region name (e.g., California, Ontario)';

-- Cities
CREATE TABLE public.cities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    hebrew_name text,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    timezone text NOT NULL,
    elevation_meters integer DEFAULT 0,
    population integer,
    location public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint(longitude, latitude), 4326))::public.geography) STORED,
    created_at timestamp with time zone DEFAULT now(),
    elevation integer,
    geonameid integer,
    name_ascii text,
    country_id smallint NOT NULL,
    region_id integer
);
COMMENT ON TABLE public.cities IS 'Cities table - use idx_cities_name_trgm for ILIKE searches, idx_cities_country_population for country listings';
COMMENT ON COLUMN public.cities.elevation IS 'Elevation in meters above sea level, used for zmanim calculations';
COMMENT ON COLUMN public.cities.geonameid IS 'GeoNames ID for data source reference and deduplication';
COMMENT ON COLUMN public.cities.country_id IS 'FK to geo_countries - normalized replacement for country/country_code';
COMMENT ON COLUMN public.cities.region_id IS 'FK to geo_regions - normalized replacement for region/region_code';

-- Countries (legacy)
CREATE TABLE public.countries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(2) NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- Day Types (deprecated)
CREATE TABLE public.day_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL,
    description text,
    parent_type character varying(100),
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.day_types IS 'DEPRECATED: Use jewish_events instead. Types of days for which zmanim can be configured.';
COMMENT ON COLUMN public.day_types.parent_type IS 'Parent type name for hierarchical day types';

-- Embeddings
CREATE TABLE public.embeddings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source character varying(255) NOT NULL,
    content_type character varying(50) NOT NULL,
    chunk_index integer NOT NULL,
    content text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb,
    embedding public.vector(1536) NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);
COMMENT ON TABLE public.embeddings IS 'Vector embeddings for RAG semantic search';
COMMENT ON COLUMN public.embeddings.source IS 'Source document identifier (dsl-spec, kosher-java, halacha)';
COMMENT ON COLUMN public.embeddings.content_type IS 'Type of content (documentation, example, source)';
COMMENT ON COLUMN public.embeddings.embedding IS 'OpenAI text-embedding-3-small 1536-dimensional vector';

-- Explanation Cache
CREATE TABLE public.explanation_cache (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    formula_hash character varying(64) NOT NULL,
    language character varying(10) NOT NULL,
    explanation text NOT NULL,
    source character varying(20) DEFAULT 'ai'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone NOT NULL
);
COMMENT ON TABLE public.explanation_cache IS 'Cache for AI-generated formula explanations';
COMMENT ON COLUMN public.explanation_cache.formula_hash IS 'SHA-256 hash of the formula text';
COMMENT ON COLUMN public.explanation_cache.expires_at IS 'TTL is typically 7 days';

-- Jewish Events
CREATE TABLE public.jewish_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code character varying(50) NOT NULL,
    name_hebrew text NOT NULL,
    name_english text NOT NULL,
    event_type character varying(30) NOT NULL,
    duration_days_israel integer DEFAULT 1,
    duration_days_diaspora integer DEFAULT 1,
    fast_start_type character varying(20),
    parent_event_code character varying(50),
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_event_type CHECK (((event_type)::text = ANY ((ARRAY['weekly'::character varying, 'yom_tov'::character varying, 'fast'::character varying, 'informational'::character varying])::text[]))),
    CONSTRAINT chk_fast_start_type CHECK (((fast_start_type IS NULL) OR ((fast_start_type)::text = ANY ((ARRAY['dawn'::character varying, 'sunset'::character varying])::text[]))))
);
COMMENT ON TABLE public.jewish_events IS 'Canonical list of Jewish events (Shabbos, Yom Tov, fasts, etc.) with Israel/Diaspora duration differences';
COMMENT ON COLUMN public.jewish_events.event_type IS 'Type of event: weekly (Shabbos), yom_tov, fast, or informational (no linked zmanim)';
COMMENT ON COLUMN public.jewish_events.duration_days_israel IS 'Number of days this event lasts in Israel';
COMMENT ON COLUMN public.jewish_events.duration_days_diaspora IS 'Number of days this event lasts in the Diaspora';
COMMENT ON COLUMN public.jewish_events.fast_start_type IS 'For fasts: dawn (regular fasts) or sunset (Yom Kippur, Tisha B''Av)';

-- Zman Tags
CREATE TABLE public.zman_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tag_key character varying(50) NOT NULL,
    name character varying(100) NOT NULL,
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL,
    tag_type character varying(50) NOT NULL,
    description text,
    color character varying(7),
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT zman_tags_tag_type_check CHECK ((tag_type)::text = ANY (ARRAY['event'::text, 'timing'::text, 'behavior'::text, 'shita'::text, 'calculation'::text, 'category'::text]))
);
COMMENT ON TABLE public.zman_tags IS 'Tags for categorizing zmanim by event type, timing, and behavior';
COMMENT ON COLUMN public.zman_tags.tag_key IS 'Unique key identifier for the tag (e.g., shabbos, yom_tov)';

-- Master Zmanim Registry
CREATE TABLE public.master_zmanim_registry (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    zman_key character varying(100) NOT NULL,
    canonical_hebrew_name text NOT NULL,
    canonical_english_name text NOT NULL,
    transliteration text,
    description text,
    halachic_notes text,
    halachic_source character varying(500),
    time_category character varying(50) NOT NULL,
    default_formula_dsl text NOT NULL,
    is_core boolean DEFAULT false,
    is_hidden boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0,
    created_by character varying(255),
    updated_by character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_time_category CHECK (((time_category)::text = ANY ((ARRAY['dawn'::character varying, 'sunrise'::character varying, 'morning'::character varying, 'midday'::character varying, 'afternoon'::character varying, 'sunset'::character varying, 'nightfall'::character varying, 'midnight'::character varying])::text[])))
);
COMMENT ON TABLE public.master_zmanim_registry IS 'Master zmanim registry - trigram indexes available for fuzzy Hebrew/English/transliteration searches';
COMMENT ON COLUMN public.master_zmanim_registry.zman_key IS 'Unique identifier for this zman type';
COMMENT ON COLUMN public.master_zmanim_registry.halachic_notes IS 'Halachic background and reasoning for this zman';
COMMENT ON COLUMN public.master_zmanim_registry.time_category IS 'Time of day grouping for UI display';
COMMENT ON COLUMN public.master_zmanim_registry.is_core IS 'If true, this zman is a core/essential zman that cannot be removed from the registry';
COMMENT ON COLUMN public.master_zmanim_registry.is_hidden IS 'When true, this zman is hidden from public registry queries but visible to admins. Useful for deprecated or experimental zmanim.';
COMMENT ON COLUMN public.master_zmanim_registry.created_by IS 'Clerk user ID of the admin who created this zman';
COMMENT ON COLUMN public.master_zmanim_registry.updated_by IS 'Clerk user ID of the admin who last updated this zman';

-- Master Zman Day Types (deprecated)
CREATE TABLE public.master_zman_day_types (
    master_zman_id uuid NOT NULL,
    day_type_id uuid NOT NULL,
    is_default boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.master_zman_day_types IS 'DEPRECATED: Use master_zman_events instead.';

-- Master Zman Events
CREATE TABLE public.master_zman_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    master_zman_id uuid NOT NULL,
    jewish_event_id uuid NOT NULL,
    is_default boolean DEFAULT true,
    applies_to_day integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.master_zman_events IS 'Links zmanim to the Jewish events they apply to';
COMMENT ON COLUMN public.master_zman_events.applies_to_day IS 'NULL = all days of event, 1 = day 1 only, 2 = day 2 only (for 2-day Yom Tov in Diaspora)';

-- Master Zman Tags
CREATE TABLE public.master_zman_tags (
    master_zman_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.master_zman_tags IS 'Many-to-many relationship between zmanim and tags';

-- Password Reset Tokens
CREATE TABLE public.password_reset_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    token text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- Publishers
CREATE TABLE public.publishers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    phone text,
    website text,
    description text,
    logo_url text,
    location public.geography(Point,4326),
    latitude double precision,
    longitude double precision,
    timezone text,
    status text DEFAULT 'pending'::text NOT NULL,
    verification_token text,
    verified_at timestamp with time zone,
    clerk_user_id text,
    is_published boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    bio text,
    slug text,
    is_verified boolean DEFAULT false NOT NULL,
    logo_data text,
    CONSTRAINT publishers_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text])))
);
COMMENT ON TABLE public.publishers IS 'Publishers who provide zmanim calculations. Publisher name IS the organization name.';
COMMENT ON COLUMN public.publishers.is_published IS 'Whether the publisher profile and zmanim are publicly visible';
COMMENT ON COLUMN public.publishers.bio IS 'Short biography or about text for the publisher';
COMMENT ON COLUMN public.publishers.slug IS 'URL-friendly unique identifier for the publisher';
COMMENT ON COLUMN public.publishers.is_verified IS 'Verified publishers can have their zmanim linked to by other publishers';
COMMENT ON COLUMN public.publishers.logo_data IS 'Base64 encoded logo image (PNG format, data:image/png;base64,...)';

-- Publisher Coverage
CREATE TABLE public.publisher_coverage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    coverage_level text NOT NULL,
    country_code character varying(2),
    region text,
    city_id uuid,
    priority integer DEFAULT 5,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    continent_code character varying(2),
    CONSTRAINT coverage_level_check CHECK ((coverage_level = ANY (ARRAY['continent'::text, 'country'::text, 'region'::text, 'city'::text]))),
    CONSTRAINT publisher_coverage_priority_check CHECK (((priority >= 1) AND (priority <= 10))),
    CONSTRAINT valid_coverage_data CHECK ((((coverage_level = 'continent'::text) AND (continent_code IS NOT NULL) AND (country_code IS NULL) AND (region IS NULL) AND (city_id IS NULL)) OR ((coverage_level = 'country'::text) AND (country_code IS NOT NULL) AND (region IS NULL) AND (city_id IS NULL)) OR ((coverage_level = 'region'::text) AND (country_code IS NOT NULL) AND (region IS NOT NULL) AND (city_id IS NULL)) OR ((coverage_level = 'city'::text) AND (city_id IS NOT NULL))))
);
COMMENT ON TABLE public.publisher_coverage IS 'Publisher geographic coverage at country, region, or city level';
COMMENT ON COLUMN public.publisher_coverage.coverage_level IS 'Level of coverage: country, region, or city';
COMMENT ON COLUMN public.publisher_coverage.priority IS 'Priority for this coverage (1-10, higher = more prominent)';

-- Publisher Invitations (deprecated)
CREATE TABLE public.publisher_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid,
    email text NOT NULL,
    token text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    invited_by text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    accepted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.publisher_invitations IS 'DEPRECATED: This table is no longer used. User management now creates users directly via Clerk instead of using invitations. Table kept for historical reference but will be empty.';

-- Publisher Onboarding
CREATE TABLE public.publisher_onboarding (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    current_step integer DEFAULT 0,
    completed_steps integer[] DEFAULT '{}'::integer[],
    wizard_data jsonb DEFAULT '{}'::jsonb,
    started_at timestamp with time zone DEFAULT now(),
    last_updated_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone,
    skipped boolean DEFAULT false
);
COMMENT ON TABLE public.publisher_onboarding IS 'Tracks onboarding wizard state for publishers';
COMMENT ON COLUMN public.publisher_onboarding.wizard_data IS 'JSON data containing template selection, customizations, and coverage';
COMMENT ON COLUMN public.publisher_onboarding.skipped IS 'True if publisher skipped the wizard';

-- Publisher Requests
CREATE TABLE public.publisher_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    email text NOT NULL,
    website text,
    description text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    rejection_reason text,
    reviewed_by text,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.publisher_requests IS 'Requests from users to become publishers. Publisher name IS the organization name.';

-- Publisher Zmanim
CREATE TABLE public.publisher_zmanim (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    zman_key text NOT NULL,
    hebrew_name text NOT NULL,
    english_name text NOT NULL,
    formula_dsl text NOT NULL,
    ai_explanation text,
    publisher_comment text,
    is_enabled boolean DEFAULT true NOT NULL,
    is_visible boolean DEFAULT true NOT NULL,
    is_published boolean DEFAULT false NOT NULL,
    is_custom boolean DEFAULT false NOT NULL,
    category text NOT NULL,
    dependencies text[] DEFAULT '{}'::text[] NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    master_zman_id uuid,
    current_version integer DEFAULT 1,
    deleted_at timestamp with time zone,
    deleted_by character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    linked_publisher_zman_id uuid,
    source_type character varying(20) DEFAULT 'custom'::character varying,
    is_beta boolean DEFAULT false NOT NULL,
    certified_at timestamp with time zone,
    transliteration text,
    description text,
    CONSTRAINT no_self_links CHECK (((linked_publisher_zman_id IS NULL) OR (linked_publisher_zman_id <> id))),
    CONSTRAINT publisher_zmanim_category_check CHECK ((category = ANY (ARRAY['essential'::text, 'optional'::text, 'custom'::text]))),
    CONSTRAINT publisher_zmanim_source_type_check CHECK (((source_type)::text = ANY ((ARRAY['registry'::character varying, 'copied'::character varying, 'linked'::character varying, 'custom'::character varying])::text[])))
);
COMMENT ON TABLE public.publisher_zmanim IS 'Publisher zmanim - filtered queries should use publisher_id + deleted_at + is_enabled for best performance';
COMMENT ON COLUMN public.publisher_zmanim.formula_dsl IS 'DSL formula string. Examples: "proportional_hours(3, gra)" for 3 hours after sunrise, "solar(16.1, before_sunrise)" for dawn';
COMMENT ON COLUMN public.publisher_zmanim.publisher_comment IS 'Publisher''s personal notes, minhag, or halachic source';
COMMENT ON COLUMN public.publisher_zmanim.is_enabled IS 'Whether this zman is active in the algorithm (for preview/calculation)';
COMMENT ON COLUMN public.publisher_zmanim.is_published IS 'Whether this zman is publicly visible to end users';
COMMENT ON COLUMN public.publisher_zmanim.category IS 'essential = always enabled, optional = can toggle, custom = user created';
COMMENT ON COLUMN public.publisher_zmanim.dependencies IS 'Auto-extracted @references from formula_dsl';
COMMENT ON COLUMN public.publisher_zmanim.linked_publisher_zman_id IS 'For linked zmanim, points to the source zman from another publisher';
COMMENT ON COLUMN public.publisher_zmanim.source_type IS 'How this zman was created: registry, copied, linked, or custom';
COMMENT ON COLUMN public.publisher_zmanim.is_beta IS 'When true, this zman is in beta mode and displayed with a warning to users. Publishers use beta mode to gather feedback before certifying a zman as stable.';
COMMENT ON COLUMN public.publisher_zmanim.certified_at IS 'Timestamp when is_beta was changed from true to false, indicating publisher certification';
COMMENT ON COLUMN public.publisher_zmanim.transliteration IS 'Publisher''s custom transliteration (can differ from registry)';
COMMENT ON COLUMN public.publisher_zmanim.description IS 'Publisher''s description of what this zman represents (can differ from registry)';

-- Publisher Zman Aliases
CREATE TABLE public.publisher_zman_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    publisher_zman_id uuid NOT NULL,
    custom_hebrew_name text NOT NULL,
    custom_english_name text NOT NULL,
    custom_transliteration text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.publisher_zman_aliases IS 'Custom display names for zmanim per publisher. Original master registry names remain accessible via master_zmanim_registry.';
COMMENT ON COLUMN public.publisher_zman_aliases.custom_hebrew_name IS 'Publisher-specific Hebrew display name';
COMMENT ON COLUMN public.publisher_zman_aliases.custom_english_name IS 'Publisher-specific English display name';
COMMENT ON COLUMN public.publisher_zman_aliases.custom_transliteration IS 'Optional publisher-specific transliteration';
COMMENT ON COLUMN public.publisher_zman_aliases.is_active IS 'Whether this alias is currently in use';

-- Publisher Zman Day Types (deprecated)
CREATE TABLE public.publisher_zman_day_types (
    publisher_zman_id uuid NOT NULL,
    day_type_id uuid NOT NULL,
    is_visible boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.publisher_zman_day_types IS 'DEPRECATED: Use publisher_zman_events instead.';

-- Publisher Zman Events
CREATE TABLE public.publisher_zman_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_zman_id uuid NOT NULL,
    jewish_event_id uuid NOT NULL,
    is_enabled boolean DEFAULT true,
    applies_to_day integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.publisher_zman_events IS 'Publisher overrides for which events their zmanim apply to';

-- Publisher Zman Versions
CREATE TABLE public.publisher_zman_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_zman_id uuid NOT NULL,
    version_number integer NOT NULL,
    formula_dsl text NOT NULL,
    created_by character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.publisher_zman_versions IS 'Version history for each publisher zman (max 7 versions, formula changes only)';

-- Schema Migrations table is created by migrate.sh script, not here

-- System Config
CREATE TABLE public.system_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    value jsonb NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Zman Definitions
CREATE TABLE public.zman_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(100) NOT NULL,
    name_hebrew text NOT NULL,
    name_english text NOT NULL,
    transliteration text,
    category character varying(50) DEFAULT 'general'::character varying NOT NULL,
    sort_order integer DEFAULT 0,
    is_standard boolean DEFAULT false,
    halachic_notes text,
    halachic_source character varying(500),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT chk_hebrew_name CHECK ((name_hebrew ~ '[א-ת]'::text))
);
COMMENT ON COLUMN public.zman_definitions.halachic_notes IS 'Markdown-formatted halachic documentation and sources';
COMMENT ON COLUMN public.zman_definitions.halachic_source IS 'Primary halachic source reference';

-- Zman Display Contexts
CREATE TABLE public.zman_display_contexts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    master_zman_id uuid NOT NULL,
    context_code character varying(50) NOT NULL,
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON TABLE public.zman_display_contexts IS 'Context-specific display names for zmanim with the same calculation but different labels';
COMMENT ON COLUMN public.zman_display_contexts.context_code IS 'Context identifier - matches jewish_events.code or special values';

-- Zman Registry Requests
CREATE TABLE public.zman_registry_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    requested_key character varying(100) NOT NULL,
    requested_hebrew_name text NOT NULL,
    requested_english_name text NOT NULL,
    requested_formula_dsl text,
    time_category character varying(50) NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying NOT NULL,
    reviewed_by character varying(255),
    reviewed_at timestamp with time zone,
    reviewer_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    transliteration text,
    description text,
    halachic_notes text,
    halachic_source text,
    publisher_email text,
    publisher_name text,
    auto_add_on_approval boolean DEFAULT true,
    CONSTRAINT chk_request_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'approved'::character varying, 'rejected'::character varying])::text[])))
);
COMMENT ON TABLE public.zman_registry_requests IS 'Requests from publishers to add new zmanim to the master registry';
COMMENT ON COLUMN public.zman_registry_requests.transliteration IS 'Transliteration of the Hebrew name';
COMMENT ON COLUMN public.zman_registry_requests.description IS 'Brief description of the zman';
COMMENT ON COLUMN public.zman_registry_requests.halachic_notes IS 'Halachic context or notes';
COMMENT ON COLUMN public.zman_registry_requests.halachic_source IS 'Source references (seforim, poskim)';
COMMENT ON COLUMN public.zman_registry_requests.publisher_email IS 'Contact email for the requesting publisher';
COMMENT ON COLUMN public.zman_registry_requests.publisher_name IS 'Display name of the requesting publisher';
COMMENT ON COLUMN public.zman_registry_requests.auto_add_on_approval IS 'If true, automatically add this zman to publisher''s list when approved';

-- Zman Request Tags
CREATE TABLE public.zman_request_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    request_id uuid NOT NULL,
    tag_id uuid,
    requested_tag_name text,
    requested_tag_type text,
    is_new_tag_request boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tag_reference_check CHECK ((((tag_id IS NOT NULL) AND (requested_tag_name IS NULL) AND (is_new_tag_request = false)) OR ((tag_id IS NULL) AND (requested_tag_name IS NOT NULL) AND (is_new_tag_request = true)))),
    CONSTRAINT zman_request_tags_requested_tag_type_check CHECK (((requested_tag_type IS NULL) OR (requested_tag_type = ANY (ARRAY['event'::text, 'timing'::text, 'behavior'::text, 'shita'::text, 'method'::text]))))
);
COMMENT ON TABLE public.zman_request_tags IS 'Tags associated with zman registry requests. Supports both existing tag references and new tag requests.';
COMMENT ON COLUMN public.zman_request_tags.tag_id IS 'Reference to existing tag (if using existing tag)';
COMMENT ON COLUMN public.zman_request_tags.requested_tag_name IS 'Name of requested new tag (if requesting new tag)';
COMMENT ON COLUMN public.zman_request_tags.requested_tag_type IS 'Type of requested new tag: event, timing, behavior, shita, method';
COMMENT ON COLUMN public.zman_request_tags.is_new_tag_request IS 'True if this is a request for a new tag to be created';

-- Zmanim Templates
CREATE TABLE public.zmanim_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    zman_key text NOT NULL,
    hebrew_name text NOT NULL,
    english_name text NOT NULL,
    formula_dsl text NOT NULL,
    category text NOT NULL,
    description text,
    is_required boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT zmanim_templates_category_check CHECK ((category = ANY (ARRAY['essential'::text, 'optional'::text])))
);
COMMENT ON TABLE public.zmanim_templates IS 'System-wide default zmanim formulas that publishers can copy from';
COMMENT ON COLUMN public.zmanim_templates.formula_dsl IS 'DSL formula string. proportional_hours(N, gra) returns absolute time N hours after sunrise. proportional_hours(N, mga) returns N hours after dawn (72min before sunrise).';

-- ============================================================================
-- PRIMARY KEYS
-- ============================================================================

ALTER TABLE ONLY public.ai_audit_logs ADD CONSTRAINT ai_audit_logs_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.ai_index_status ADD CONSTRAINT ai_index_status_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.algorithms ADD CONSTRAINT algorithms_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.astronomical_primitives ADD CONSTRAINT astronomical_primitives_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.cities ADD CONSTRAINT cities_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.countries ADD CONSTRAINT countries_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.day_types ADD CONSTRAINT day_types_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.embeddings ADD CONSTRAINT embeddings_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.explanation_cache ADD CONSTRAINT explanation_cache_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.geo_continents ADD CONSTRAINT geo_continents_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.geo_countries ADD CONSTRAINT geo_countries_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.geo_regions ADD CONSTRAINT geo_regions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.jewish_events ADD CONSTRAINT jewish_events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.master_zman_day_types ADD CONSTRAINT master_zman_day_types_pkey PRIMARY KEY (master_zman_id, day_type_id);
ALTER TABLE ONLY public.master_zman_events ADD CONSTRAINT master_zman_events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.master_zman_tags ADD CONSTRAINT master_zman_tags_pkey PRIMARY KEY (master_zman_id, tag_id);
ALTER TABLE ONLY public.master_zmanim_registry ADD CONSTRAINT master_zmanim_registry_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.password_reset_tokens ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_coverage ADD CONSTRAINT publisher_coverage_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_invitations ADD CONSTRAINT publisher_invitations_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_onboarding ADD CONSTRAINT publisher_onboarding_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_requests ADD CONSTRAINT publisher_requests_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_zman_aliases ADD CONSTRAINT publisher_zman_aliases_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_zman_day_types ADD CONSTRAINT publisher_zman_day_types_pkey PRIMARY KEY (publisher_zman_id, day_type_id);
ALTER TABLE ONLY public.publisher_zman_events ADD CONSTRAINT publisher_zman_events_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_zman_versions ADD CONSTRAINT publisher_zman_versions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publisher_zmanim ADD CONSTRAINT publisher_zmanim_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.publishers ADD CONSTRAINT publishers_pkey PRIMARY KEY (id);
-- schema_migrations primary key is created by migrate.sh script
ALTER TABLE ONLY public.system_config ADD CONSTRAINT system_config_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.zman_definitions ADD CONSTRAINT zman_definitions_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.zman_display_contexts ADD CONSTRAINT zman_display_contexts_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.zman_registry_requests ADD CONSTRAINT zman_registry_requests_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.zman_request_tags ADD CONSTRAINT zman_request_tags_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.zman_tags ADD CONSTRAINT zman_tags_pkey PRIMARY KEY (id);
ALTER TABLE ONLY public.zmanim_templates ADD CONSTRAINT zmanim_templates_pkey PRIMARY KEY (id);

-- ============================================================================
-- UNIQUE CONSTRAINTS
-- ============================================================================

ALTER TABLE ONLY public.ai_index_status ADD CONSTRAINT ai_index_status_source_key UNIQUE (source);
ALTER TABLE ONLY public.astronomical_primitives ADD CONSTRAINT astronomical_primitives_variable_name_key UNIQUE (variable_name);
ALTER TABLE ONLY public.countries ADD CONSTRAINT countries_code_key UNIQUE (code);
ALTER TABLE ONLY public.day_types ADD CONSTRAINT day_types_name_key UNIQUE (name);
ALTER TABLE ONLY public.embeddings ADD CONSTRAINT embeddings_source_chunk_index_key UNIQUE (source, chunk_index);
ALTER TABLE ONLY public.explanation_cache ADD CONSTRAINT explanation_cache_formula_hash_language_key UNIQUE (formula_hash, language);
ALTER TABLE ONLY public.geo_continents ADD CONSTRAINT geo_continents_code_key UNIQUE (code);
ALTER TABLE ONLY public.geo_countries ADD CONSTRAINT geo_countries_code_key UNIQUE (code);
ALTER TABLE ONLY public.geo_regions ADD CONSTRAINT geo_regions_country_id_code_key UNIQUE (country_id, code);
ALTER TABLE ONLY public.jewish_events ADD CONSTRAINT jewish_events_code_key UNIQUE (code);
ALTER TABLE ONLY public.master_zman_events ADD CONSTRAINT master_zman_events_master_zman_id_jewish_event_id_applies_t_key UNIQUE (master_zman_id, jewish_event_id, applies_to_day);
ALTER TABLE ONLY public.master_zmanim_registry ADD CONSTRAINT master_zmanim_registry_zman_key_key UNIQUE (zman_key);
ALTER TABLE ONLY public.password_reset_tokens ADD CONSTRAINT password_reset_tokens_email_key UNIQUE (email);
ALTER TABLE ONLY public.publisher_invitations ADD CONSTRAINT publisher_invitations_token_key UNIQUE (token);
ALTER TABLE ONLY public.publisher_onboarding ADD CONSTRAINT publisher_onboarding_publisher_id_key UNIQUE (publisher_id);
ALTER TABLE ONLY public.publisher_zman_aliases ADD CONSTRAINT publisher_zman_aliases_publisher_id_publisher_zman_id_key UNIQUE (publisher_id, publisher_zman_id);
ALTER TABLE ONLY public.publisher_zman_events ADD CONSTRAINT publisher_zman_events_publisher_zman_id_jewish_event_id_app_key UNIQUE (publisher_zman_id, jewish_event_id, applies_to_day);
ALTER TABLE ONLY public.publisher_zman_versions ADD CONSTRAINT publisher_zman_versions_publisher_zman_id_version_number_key UNIQUE (publisher_zman_id, version_number);
ALTER TABLE ONLY public.publisher_zmanim ADD CONSTRAINT publisher_zmanim_publisher_id_zman_key_key UNIQUE (publisher_id, zman_key);
ALTER TABLE ONLY public.publishers ADD CONSTRAINT publishers_clerk_user_id_key UNIQUE (clerk_user_id);
ALTER TABLE ONLY public.publishers ADD CONSTRAINT publishers_email_key UNIQUE (email);
ALTER TABLE ONLY public.system_config ADD CONSTRAINT system_config_key_key UNIQUE (key);
ALTER TABLE ONLY public.zman_definitions ADD CONSTRAINT zman_definitions_key_key UNIQUE (key);
ALTER TABLE ONLY public.zman_display_contexts ADD CONSTRAINT zman_display_contexts_master_zman_id_context_code_key UNIQUE (master_zman_id, context_code);
ALTER TABLE ONLY public.zman_tags ADD CONSTRAINT zman_tags_name_key UNIQUE (name);
ALTER TABLE ONLY public.zman_tags ADD CONSTRAINT zman_tags_tag_key_key UNIQUE (tag_key);
ALTER TABLE ONLY public.zmanim_templates ADD CONSTRAINT zmanim_templates_zman_key_key UNIQUE (zman_key);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Embeddings
CREATE INDEX embeddings_content_type_idx ON public.embeddings USING btree (content_type);
CREATE INDEX embeddings_source_idx ON public.embeddings USING btree (source);
CREATE INDEX embeddings_vector_idx ON public.embeddings USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');

-- AI Audit Logs
CREATE INDEX idx_ai_audit_created ON public.ai_audit_logs USING btree (created_at DESC);
CREATE INDEX idx_ai_audit_publisher ON public.ai_audit_logs USING btree (publisher_id);
CREATE INDEX idx_ai_audit_success ON public.ai_audit_logs USING btree (success);
CREATE INDEX idx_ai_audit_type ON public.ai_audit_logs USING btree (request_type);
CREATE INDEX idx_ai_audit_user ON public.ai_audit_logs USING btree (user_id);

-- Algorithms
CREATE INDEX idx_algorithms_forked_from ON public.algorithms USING btree (forked_from) WHERE (forked_from IS NOT NULL);
CREATE INDEX idx_algorithms_public ON public.algorithms USING btree (is_public) WHERE (is_public = true);
CREATE INDEX idx_algorithms_publisher_id ON public.algorithms USING btree (publisher_id);
CREATE INDEX idx_algorithms_status ON public.algorithms USING btree (status);

-- Astronomical Primitives
CREATE INDEX idx_astronomical_primitives_category ON public.astronomical_primitives USING btree (category);
CREATE INDEX idx_astronomical_primitives_variable_name ON public.astronomical_primitives USING btree (variable_name);

-- Cities
CREATE INDEX idx_cities_country_id ON public.cities USING btree (country_id);
CREATE INDEX idx_cities_country_population ON public.cities USING btree (country_id, population DESC NULLS LAST, name);
CREATE INDEX idx_cities_covering ON public.cities USING btree (id) INCLUDE (name, hebrew_name, country_id, region_id, latitude, longitude, timezone, population, elevation, geonameid);
CREATE UNIQUE INDEX idx_cities_geonameid ON public.cities USING btree (geonameid) WHERE (geonameid IS NOT NULL);
CREATE INDEX idx_cities_location ON public.cities USING gist (location);
CREATE INDEX idx_cities_name ON public.cities USING btree (name);
CREATE INDEX idx_cities_name_ascii ON public.cities USING btree (name_ascii);
CREATE INDEX idx_cities_name_ascii_trgm ON public.cities USING gin (name_ascii public.gin_trgm_ops);
CREATE INDEX idx_cities_name_trgm ON public.cities USING gin (name public.gin_trgm_ops);
CREATE INDEX idx_cities_population ON public.cities USING btree (population DESC NULLS LAST);
CREATE INDEX idx_cities_region_id ON public.cities USING btree (region_id);
CREATE INDEX idx_cities_region_population ON public.cities USING btree (region_id, population DESC NULLS LAST, name) WHERE (region_id IS NOT NULL);

-- Day Types
CREATE INDEX idx_day_types_name ON public.day_types USING btree (name);
CREATE INDEX idx_day_types_parent ON public.day_types USING btree (parent_type);

-- Explanation Cache
CREATE INDEX idx_explanation_cache_expiry ON public.explanation_cache USING btree (expires_at);
CREATE INDEX idx_explanation_cache_lookup ON public.explanation_cache USING btree (formula_hash, language);

-- Geo Countries/Regions
CREATE INDEX idx_geo_countries_continent ON public.geo_countries USING btree (continent_id);
CREATE INDEX idx_geo_countries_covering ON public.geo_countries USING btree (continent_id, name) INCLUDE (id, code);
CREATE INDEX idx_geo_regions_country ON public.geo_regions USING btree (country_id);
CREATE INDEX idx_geo_regions_covering ON public.geo_regions USING btree (country_id, name) INCLUDE (id, code);

-- Jewish Events
CREATE INDEX idx_jewish_events_code ON public.jewish_events USING btree (code);
CREATE INDEX idx_jewish_events_parent ON public.jewish_events USING btree (parent_event_code);
CREATE INDEX idx_jewish_events_type ON public.jewish_events USING btree (event_type);

-- Master Registry
CREATE INDEX idx_master_registry_category ON public.master_zmanim_registry USING btree (time_category);
CREATE INDEX idx_master_registry_english_name_trgm ON public.master_zmanim_registry USING gin (canonical_english_name public.gin_trgm_ops);
CREATE INDEX idx_master_registry_hebrew_name_trgm ON public.master_zmanim_registry USING gin (canonical_hebrew_name public.gin_trgm_ops);
CREATE INDEX idx_master_registry_hidden ON public.master_zmanim_registry USING btree (is_hidden);
CREATE INDEX idx_master_registry_key ON public.master_zmanim_registry USING btree (zman_key);
CREATE INDEX idx_master_registry_sort ON public.master_zmanim_registry USING btree (time_category, sort_order);
CREATE INDEX idx_master_registry_transliteration_trgm ON public.master_zmanim_registry USING gin (transliteration public.gin_trgm_ops);
CREATE INDEX idx_master_registry_visible_by_category ON public.master_zmanim_registry USING btree (time_category, sort_order, canonical_hebrew_name) WHERE (is_hidden = false);

-- Master Zman Day Types/Events/Tags
CREATE INDEX idx_master_zman_day_types_day ON public.master_zman_day_types USING btree (day_type_id);
CREATE INDEX idx_master_zman_day_types_zman ON public.master_zman_day_types USING btree (master_zman_id);
CREATE INDEX idx_master_zman_events_event ON public.master_zman_events USING btree (jewish_event_id);
CREATE INDEX idx_master_zman_events_zman ON public.master_zman_events USING btree (master_zman_id);
CREATE INDEX idx_master_zman_tags_tag ON public.master_zman_tags USING btree (tag_id);
CREATE INDEX idx_master_zman_tags_zman ON public.master_zman_tags USING btree (master_zman_id);

-- Publisher Onboarding
CREATE INDEX idx_onboarding_publisher ON public.publisher_onboarding USING btree (publisher_id);

-- Password Reset Tokens
CREATE INDEX idx_password_reset_tokens_email ON public.password_reset_tokens USING btree (email);
CREATE INDEX idx_password_reset_tokens_token ON public.password_reset_tokens USING btree (token);

-- Publisher Zman Day Types
CREATE INDEX idx_pub_zman_day_types_day ON public.publisher_zman_day_types USING btree (day_type_id);
CREATE INDEX idx_pub_zman_day_types_zman ON public.publisher_zman_day_types USING btree (publisher_zman_id);

-- Publisher Coverage
CREATE INDEX idx_publisher_coverage_active ON public.publisher_coverage USING btree (is_active);
CREATE INDEX idx_publisher_coverage_calc ON public.publisher_coverage USING btree (publisher_id, is_active, coverage_level, country_code, region) WHERE (is_active = true);
CREATE INDEX idx_publisher_coverage_city ON public.publisher_coverage USING btree (city_id) WHERE (coverage_level = 'city'::text);
CREATE INDEX idx_publisher_coverage_continent ON public.publisher_coverage USING btree (continent_code) WHERE (coverage_level = 'continent'::text);
CREATE INDEX idx_publisher_coverage_country ON public.publisher_coverage USING btree (country_code) WHERE (coverage_level = 'country'::text);
CREATE INDEX idx_publisher_coverage_geo_lookup ON public.publisher_coverage USING btree (country_code, region, coverage_level, priority DESC) WHERE (is_active = true);
CREATE INDEX idx_publisher_coverage_publisher ON public.publisher_coverage USING btree (publisher_id);
CREATE INDEX idx_publisher_coverage_region ON public.publisher_coverage USING btree (country_code, region) WHERE (coverage_level = 'region'::text);
CREATE UNIQUE INDEX idx_publisher_coverage_unique_city ON public.publisher_coverage USING btree (publisher_id, city_id) WHERE (coverage_level = 'city'::text);
CREATE UNIQUE INDEX idx_publisher_coverage_unique_country ON public.publisher_coverage USING btree (publisher_id, country_code) WHERE (coverage_level = 'country'::text);
CREATE UNIQUE INDEX idx_publisher_coverage_unique_region ON public.publisher_coverage USING btree (publisher_id, country_code, region) WHERE (coverage_level = 'region'::text);

-- Publisher Invitations
CREATE INDEX idx_publisher_invitations_email ON public.publisher_invitations USING btree (email, publisher_id);
CREATE INDEX idx_publisher_invitations_publisher ON public.publisher_invitations USING btree (publisher_id);
CREATE INDEX idx_publisher_invitations_token ON public.publisher_invitations USING btree (token);

-- Publisher Requests
CREATE UNIQUE INDEX idx_publisher_requests_email_pending ON public.publisher_requests USING btree (email) WHERE (status = 'pending'::text);
CREATE INDEX idx_publisher_requests_status ON public.publisher_requests USING btree (status);

-- Publisher Zman Aliases
CREATE INDEX idx_publisher_zman_aliases_publisher ON public.publisher_zman_aliases USING btree (publisher_id);
CREATE INDEX idx_publisher_zman_aliases_zman ON public.publisher_zman_aliases USING btree (publisher_zman_id);

-- Publisher Zman Events
CREATE INDEX idx_publisher_zman_events_event ON public.publisher_zman_events USING btree (jewish_event_id);
CREATE INDEX idx_publisher_zman_events_zman ON public.publisher_zman_events USING btree (publisher_zman_id);

-- Publisher Zmanim
CREATE INDEX idx_publisher_zmanim_active ON public.publisher_zmanim USING btree (publisher_id) WHERE (deleted_at IS NULL);
CREATE INDEX idx_publisher_zmanim_active_enabled ON public.publisher_zmanim USING btree (publisher_id, is_enabled) WHERE (deleted_at IS NULL);
CREATE INDEX idx_publisher_zmanim_beta ON public.publisher_zmanim USING btree (publisher_id, is_beta) WHERE (is_beta = true);
CREATE INDEX idx_publisher_zmanim_category ON public.publisher_zmanim USING btree (category);
CREATE INDEX idx_publisher_zmanim_custom ON public.publisher_zmanim USING btree (publisher_id, is_custom) WHERE (is_custom = true);
CREATE INDEX idx_publisher_zmanim_deleted ON public.publisher_zmanim USING btree (publisher_id, deleted_at) WHERE (deleted_at IS NOT NULL);
CREATE INDEX idx_publisher_zmanim_enabled ON public.publisher_zmanim USING btree (publisher_id, is_enabled) WHERE (is_enabled = true);
CREATE INDEX idx_publisher_zmanim_english_name_trgm ON public.publisher_zmanim USING gin (english_name public.gin_trgm_ops) WHERE ((is_published = true) AND (is_visible = true));
CREATE INDEX idx_publisher_zmanim_hebrew_name_trgm ON public.publisher_zmanim USING gin (hebrew_name public.gin_trgm_ops) WHERE ((is_published = true) AND (is_visible = true));
CREATE INDEX idx_publisher_zmanim_linked ON public.publisher_zmanim USING btree (linked_publisher_zman_id);
CREATE INDEX idx_publisher_zmanim_linked_source ON public.publisher_zmanim USING btree (publisher_id, source_type, linked_publisher_zman_id) WHERE ((source_type)::text = 'linked'::text);
CREATE INDEX idx_publisher_zmanim_master ON public.publisher_zmanim USING btree (master_zman_id);
CREATE INDEX idx_publisher_zmanim_public_search ON public.publisher_zmanim USING btree (is_published, is_visible, category) WHERE ((is_published = true) AND (is_visible = true));
CREATE INDEX idx_publisher_zmanim_published ON public.publisher_zmanim USING btree (publisher_id, is_published) WHERE (is_published = true);
CREATE INDEX idx_publisher_zmanim_publisher ON public.publisher_zmanim USING btree (publisher_id);
CREATE INDEX idx_publisher_zmanim_source_type ON public.publisher_zmanim USING btree (source_type);

-- Publishers
CREATE INDEX idx_publishers_clerk_user_id ON public.publishers USING btree (clerk_user_id);
CREATE INDEX idx_publishers_location ON public.publishers USING gist (location);
CREATE UNIQUE INDEX idx_publishers_slug ON public.publishers USING btree (slug) WHERE (slug IS NOT NULL);
CREATE INDEX idx_publishers_status ON public.publishers USING btree (status);
CREATE INDEX idx_publishers_verified ON public.publishers USING btree (is_verified) WHERE (is_verified = true);

-- System Config
CREATE INDEX idx_system_config_key ON public.system_config USING btree (key);

-- Zman Definitions
CREATE INDEX idx_zman_definitions_category ON public.zman_definitions USING btree (category);
CREATE INDEX idx_zman_definitions_key ON public.zman_definitions USING btree (key);

-- Zman Registry Requests (query optimization)
CREATE INDEX idx_zman_registry_requests_publisher ON public.zman_registry_requests USING btree (publisher_id);
CREATE INDEX idx_zman_registry_requests_status ON public.zman_registry_requests USING btree (status);
CREATE INDEX idx_zman_registry_requests_publisher_created ON public.zman_registry_requests USING btree (publisher_id, created_at DESC);
CREATE INDEX idx_zman_registry_requests_pending ON public.zman_registry_requests USING btree (created_at DESC) WHERE (status = 'pending'::character varying);

-- Zman Request Tags (query optimization)
CREATE INDEX idx_zman_request_tags_request ON public.zman_request_tags USING btree (request_id);
CREATE INDEX idx_zman_request_tags_tag ON public.zman_request_tags USING btree (tag_id) WHERE (tag_id IS NOT NULL);

-- Zman Tags (query optimization)
CREATE INDEX idx_zman_tags_name_lower ON public.zman_tags USING btree (LOWER(name::text));
CREATE INDEX idx_zman_tags_type ON public.zman_tags USING btree (tag_type);

-- Publisher Zman Versions (query optimization)
CREATE INDEX idx_publisher_zman_versions_zman_version ON public.publisher_zman_versions USING btree (publisher_zman_id, version_number DESC);

-- Algorithms (query optimization - composite for publishing workflow)
CREATE INDEX idx_algorithms_publisher_status ON public.algorithms USING btree (publisher_id, status);

-- Zmanim Templates (query optimization)
CREATE INDEX idx_zmanim_templates_key ON public.zmanim_templates USING btree (zman_key);

-- Master Zman Tags (covering index for tag aggregation)
CREATE INDEX idx_master_zman_tags_covering ON public.master_zman_tags USING btree (master_zman_id) INCLUDE (tag_id);

-- Publisher Zman Events (composite for event lookup)
CREATE INDEX idx_publisher_zman_events_composite ON public.publisher_zman_events USING btree (publisher_zman_id, jewish_event_id);

-- Cities (covering index for search results)
CREATE INDEX idx_cities_search_covering ON public.cities USING btree (name) INCLUDE (hebrew_name, country_id, region_id, timezone, population, latitude, longitude);

-- ============================================================================
-- VIEWS
-- ============================================================================

CREATE VIEW public.master_zmanim_with_tags AS
 SELECT id,
    zman_key,
    canonical_hebrew_name,
    canonical_english_name,
    transliteration,
    description,
    halachic_notes,
    halachic_source,
    time_category,
    default_formula_dsl,
    is_core,
    is_hidden,
    sort_order,
    created_by,
    updated_by,
    created_at,
    updated_at,
    COALESCE(( SELECT json_agg(json_build_object('tag_key', t.tag_key, 'display_name_hebrew', t.display_name_hebrew, 'display_name_english', t.display_name_english, 'tag_type', t.tag_type) ORDER BY t.sort_order) AS json_agg
           FROM (public.master_zman_tags mzt
             JOIN public.zman_tags t ON ((mzt.tag_id = t.id)))
          WHERE (mzt.master_zman_id = mz.id)), '[]'::json) AS tags
   FROM public.master_zmanim_registry mz;
COMMENT ON VIEW public.master_zmanim_with_tags IS 'Master zmanim registry with their associated tags';

CREATE VIEW public.publisher_zmanim_resolved AS
 SELECT pz.id,
    pz.publisher_id,
    pz.zman_key,
    pz.hebrew_name,
    pz.english_name,
    COALESCE(linked_pz.formula_dsl, pz.formula_dsl) AS formula_dsl,
    pz.formula_dsl AS own_formula_dsl,
    pz.ai_explanation,
    pz.publisher_comment,
    pz.is_enabled,
    pz.is_visible,
    pz.is_published,
    pz.is_custom,
    pz.category,
    pz.dependencies,
    pz.sort_order,
    pz.master_zman_id,
    pz.linked_publisher_zman_id,
    pz.source_type,
    pz.current_version,
    pz.deleted_at,
    pz.deleted_by,
    pz.created_at,
    pz.updated_at,
    linked_pz.publisher_id AS linked_source_publisher_id,
    linked_pub.name AS linked_source_publisher_name,
    linked_pz.deleted_at AS linked_source_deleted_at,
        CASE
            WHEN (pz.linked_publisher_zman_id IS NOT NULL) THEN true
            ELSE false
        END AS is_linked,
        CASE
            WHEN ((pz.linked_publisher_zman_id IS NOT NULL) AND (linked_pz.deleted_at IS NOT NULL)) THEN true
            ELSE false
        END AS linked_source_is_deleted
   FROM ((public.publisher_zmanim pz
     LEFT JOIN public.publisher_zmanim linked_pz ON ((pz.linked_publisher_zman_id = linked_pz.id)))
     LEFT JOIN public.publishers linked_pub ON ((linked_pz.publisher_id = linked_pub.id)));
COMMENT ON VIEW public.publisher_zmanim_resolved IS 'Resolves linked zmanim to their source formulas at query time';

CREATE VIEW public.publisher_zmanim_with_registry AS
 SELECT pz.id,
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
    COALESCE(mr.time_category, (pz.category)::character varying) AS time_category,
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
   FROM (public.publisher_zmanim pz
     LEFT JOIN public.master_zmanim_registry mr ON ((pz.master_zman_id = mr.id)));
COMMENT ON VIEW public.publisher_zmanim_with_registry IS 'Convenience view that joins publisher_zmanim with master registry data';

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER ai_index_status_updated_at BEFORE UPDATE ON public.ai_index_status FOR EACH ROW EXECUTE FUNCTION public.update_embeddings_updated_at();
CREATE TRIGGER embeddings_updated_at BEFORE UPDATE ON public.embeddings FOR EACH ROW EXECUTE FUNCTION public.update_embeddings_updated_at();
CREATE TRIGGER master_registry_updated_at BEFORE UPDATE ON public.master_zmanim_registry FOR EACH ROW EXECUTE FUNCTION public.update_master_registry_updated_at();
CREATE TRIGGER prune_versions_trigger AFTER INSERT ON public.publisher_zman_versions FOR EACH ROW EXECUTE FUNCTION public.prune_zman_versions();
CREATE TRIGGER publisher_zman_day_types_updated_at BEFORE UPDATE ON public.publisher_zman_day_types FOR EACH ROW EXECUTE FUNCTION public.update_publisher_zman_day_types_updated_at();
CREATE TRIGGER publisher_zman_events_updated_at BEFORE UPDATE ON public.publisher_zman_events FOR EACH ROW EXECUTE FUNCTION public.update_publisher_zman_events_updated_at();
CREATE TRIGGER publisher_zmanim_updated_at BEFORE UPDATE ON public.publisher_zmanim FOR EACH ROW EXECUTE FUNCTION public.update_publisher_zmanim_updated_at();
CREATE TRIGGER update_algorithms_updated_at BEFORE UPDATE ON public.algorithms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_publisher_coverage_updated_at BEFORE UPDATE ON public.publisher_coverage FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_publisher_zman_aliases_updated_at BEFORE UPDATE ON public.publisher_zman_aliases FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_publishers_updated_at BEFORE UPDATE ON public.publishers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON public.system_config FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER update_zman_definitions_updated_at BEFORE UPDATE ON public.zman_definitions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ============================================================================
-- FOREIGN KEYS
-- ============================================================================

ALTER TABLE ONLY public.ai_audit_logs ADD CONSTRAINT ai_audit_logs_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.algorithms ADD CONSTRAINT algorithms_forked_from_fkey FOREIGN KEY (forked_from) REFERENCES public.algorithms(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.algorithms ADD CONSTRAINT algorithms_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.cities ADD CONSTRAINT cities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id);
ALTER TABLE ONLY public.cities ADD CONSTRAINT cities_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.geo_regions(id);
ALTER TABLE ONLY public.geo_countries ADD CONSTRAINT geo_countries_continent_id_fkey FOREIGN KEY (continent_id) REFERENCES public.geo_continents(id);
ALTER TABLE ONLY public.geo_regions ADD CONSTRAINT geo_regions_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id);
ALTER TABLE ONLY public.master_zman_day_types ADD CONSTRAINT master_zman_day_types_day_type_id_fkey FOREIGN KEY (day_type_id) REFERENCES public.day_types(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.master_zman_day_types ADD CONSTRAINT master_zman_day_types_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.master_zman_events ADD CONSTRAINT master_zman_events_jewish_event_id_fkey FOREIGN KEY (jewish_event_id) REFERENCES public.jewish_events(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.master_zman_events ADD CONSTRAINT master_zman_events_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.master_zman_tags ADD CONSTRAINT master_zman_tags_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.master_zman_tags ADD CONSTRAINT master_zman_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.zman_tags(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_coverage ADD CONSTRAINT publisher_coverage_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_coverage ADD CONSTRAINT publisher_coverage_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_invitations ADD CONSTRAINT publisher_invitations_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_onboarding ADD CONSTRAINT publisher_onboarding_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_aliases ADD CONSTRAINT publisher_zman_aliases_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_aliases ADD CONSTRAINT publisher_zman_aliases_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_day_types ADD CONSTRAINT publisher_zman_day_types_day_type_id_fkey FOREIGN KEY (day_type_id) REFERENCES public.day_types(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_day_types ADD CONSTRAINT publisher_zman_day_types_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_events ADD CONSTRAINT publisher_zman_events_jewish_event_id_fkey FOREIGN KEY (jewish_event_id) REFERENCES public.jewish_events(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_events ADD CONSTRAINT publisher_zman_events_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zman_versions ADD CONSTRAINT publisher_zman_versions_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.publisher_zmanim ADD CONSTRAINT publisher_zmanim_linked_publisher_zman_id_fkey FOREIGN KEY (linked_publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE SET NULL;
ALTER TABLE ONLY public.publisher_zmanim ADD CONSTRAINT publisher_zmanim_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id);
ALTER TABLE ONLY public.publisher_zmanim ADD CONSTRAINT publisher_zmanim_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.zman_display_contexts ADD CONSTRAINT zman_display_contexts_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.zman_registry_requests ADD CONSTRAINT zman_registry_requests_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.zman_request_tags ADD CONSTRAINT zman_request_tags_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.zman_registry_requests(id) ON DELETE CASCADE;
ALTER TABLE ONLY public.zman_request_tags ADD CONSTRAINT zman_request_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.zman_tags(id) ON DELETE SET NULL;
