-- ============================================
-- SEARCH PERFORMANCE OPTIMIZATION
-- ============================================
-- This migration adds indexes to optimize common search patterns
-- identified in the codebase query analysis.
--
-- Key Optimizations:
-- 1. Trigram (pg_trgm) indexes for fast ILIKE '%pattern%' searches
-- 2. Composite indexes for common filter combinations
-- 3. Covering indexes to avoid table lookups
--
-- Performance Impact:
-- - City name searches: 10-100x faster for partial matches
-- - Master zmanim searches: 5-50x faster for text searches
-- - Publisher zmanim queries: 2-5x faster for filtered lists
-- - Coverage count queries: Improved with better statistics
--
-- Note: pg_trgm extension already enabled in initial_schema.sql

-- ============================================
-- 1. CITIES TABLE - TEXT SEARCH OPTIMIZATION
-- ============================================

-- Trigram GIN index for fast ILIKE searches on city names
-- Supports queries like: WHERE name ILIKE '%york%'
-- Also enables similarity searches: ORDER BY similarity(name, 'new york')
CREATE INDEX IF NOT EXISTS idx_cities_name_trgm
    ON cities USING gin (name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_cities_name_ascii_trgm
    ON cities USING gin (name_ascii gin_trgm_ops);

-- Composite index for common country + population sorting pattern
-- Optimizes: WHERE country_id = X ORDER BY population DESC, name
CREATE INDEX IF NOT EXISTS idx_cities_country_population
    ON cities (country_id, population DESC NULLS LAST, name);

-- Composite index for region queries with sorting
-- Optimizes: WHERE region_id = X ORDER BY population DESC, name
CREATE INDEX IF NOT EXISTS idx_cities_region_population
    ON cities (region_id, population DESC NULLS LAST, name)
    WHERE region_id IS NOT NULL;

-- Covering index for city lookups with geo joins
-- Avoids heap lookups when selecting city + country + region
-- Optimizes the common pattern in GetCityByID, GetCityByName
CREATE INDEX IF NOT EXISTS idx_cities_covering
    ON cities (id) INCLUDE (name, hebrew_name, country_id, region_id,
                            latitude, longitude, timezone, population, elevation, geonameid);

COMMENT ON INDEX idx_cities_name_trgm IS
    'Trigram index for fast partial city name searches (ILIKE patterns)';
COMMENT ON INDEX idx_cities_country_population IS
    'Composite index for country-filtered city lists sorted by population';

-- ============================================
-- 2. MASTER ZMANIM REGISTRY - TEXT SEARCH
-- ============================================

-- Trigram indexes for fuzzy searching on zmanim names
-- Optimizes SearchMasterZmanim query (master_registry.sql:45-64)
CREATE INDEX IF NOT EXISTS idx_master_registry_hebrew_name_trgm
    ON master_zmanim_registry USING gin (canonical_hebrew_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_master_registry_english_name_trgm
    ON master_zmanim_registry USING gin (canonical_english_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_master_registry_transliteration_trgm
    ON master_zmanim_registry USING gin (transliteration gin_trgm_ops);

-- Composite index for visible (non-hidden) zmanim grouped by category
-- Optimizes queries filtering out hidden zmanim
CREATE INDEX IF NOT EXISTS idx_master_registry_visible_by_category
    ON master_zmanim_registry (time_category, sort_order, canonical_hebrew_name)
    WHERE is_hidden = false;

COMMENT ON INDEX idx_master_registry_hebrew_name_trgm IS
    'Trigram index for Hebrew name fuzzy search in master zmanim registry';
COMMENT ON INDEX idx_master_registry_english_name_trgm IS
    'Trigram index for English name fuzzy search in master zmanim registry';

-- ============================================
-- 3. PUBLISHER ZMANIM - COMPOSITE INDEXES
-- ============================================

-- Composite index for active zmanim queries
-- Optimizes GetPublisherZmanim (zmanim.sql:6-45)
-- Common pattern: WHERE publisher_id = X AND deleted_at IS NULL AND is_enabled = true
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_active_enabled
    ON publisher_zmanim (publisher_id, is_enabled)
    WHERE deleted_at IS NULL;

-- Index for published zmanim browsing
-- Optimizes BrowsePublicZmanim (zmanim.sql:168-181)
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_public_search
    ON publisher_zmanim (is_published, is_visible, category)
    WHERE is_published = true AND is_visible = true;

-- Trigram indexes for zman name searches (if browsing by name becomes common)
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_hebrew_name_trgm
    ON publisher_zmanim USING gin (hebrew_name gin_trgm_ops)
    WHERE is_published = true AND is_visible = true;

CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_english_name_trgm
    ON publisher_zmanim USING gin (english_name gin_trgm_ops)
    WHERE is_published = true AND is_visible = true;

-- Composite index for linked zmanim queries
-- Optimizes queries checking link status and source
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_linked_source
    ON publisher_zmanim (publisher_id, source_type, linked_publisher_zman_id)
    WHERE source_type = 'linked';

COMMENT ON INDEX idx_publisher_zmanim_active_enabled IS
    'Composite index for common publisher zmanim filtered queries';
COMMENT ON INDEX idx_publisher_zmanim_public_search IS
    'Index optimizing public zmanim browsing and search';

-- ============================================
-- 4. PUBLISHER COVERAGE - QUERY OPTIMIZATION
-- ============================================

-- Composite index for coverage counting queries
-- Optimizes GetCitiesCoveredCount (coverage.sql:49-68)
CREATE INDEX IF NOT EXISTS idx_publisher_coverage_calc
    ON publisher_coverage (publisher_id, is_active, coverage_level, country_code, region)
    WHERE is_active = true;

-- Index for finding publishers by geographic area
CREATE INDEX IF NOT EXISTS idx_publisher_coverage_geo_lookup
    ON publisher_coverage (country_code, region, coverage_level, priority DESC)
    WHERE is_active = true;

COMMENT ON INDEX idx_publisher_coverage_calc IS
    'Optimizes coverage count calculations for publishers';
COMMENT ON INDEX idx_publisher_coverage_geo_lookup IS
    'Optimizes finding publishers by geographic area with priority ordering';

-- ============================================
-- 5. ZMAN TAGS - JOIN OPTIMIZATION
-- ============================================

-- Covering index for tag lookups in publisher zmanim queries
-- Avoids heap lookups when joining tags
CREATE INDEX IF NOT EXISTS idx_zman_tags_covering
    ON zman_tags (id) INCLUDE (tag_key, name, display_name_hebrew,
                                display_name_english, tag_type, sort_order);

-- Index for filtering tags by type and searching
CREATE INDEX IF NOT EXISTS idx_zman_tags_type_name_trgm
    ON zman_tags USING gin (name gin_trgm_ops);

COMMENT ON INDEX idx_zman_tags_covering IS
    'Covering index to speed up tag joins in zmanim queries';

-- ============================================
-- 6. GEO LOOKUP TABLES - COMPOSITE INDEXES
-- ============================================

-- Covering index for country lookups with continent info
-- Optimizes GetCountriesByContinent (cities.sql:127-134)
CREATE INDEX IF NOT EXISTS idx_geo_countries_covering
    ON geo_countries (continent_id, name)
    INCLUDE (id, code);

-- Covering index for region lookups by country
-- Optimizes GetRegionsByCountry (cities.sql:136-141)
CREATE INDEX IF NOT EXISTS idx_geo_regions_covering
    ON geo_regions (country_id, name)
    INCLUDE (id, code);

COMMENT ON INDEX idx_geo_countries_covering IS
    'Covering index for country queries with continent filtering';
COMMENT ON INDEX idx_geo_regions_covering IS
    'Covering index for region queries by country';

-- ============================================
-- 7. STATISTICS UPDATE
-- ============================================

-- Update table statistics to help query planner make better decisions
-- Run ANALYZE on tables with new indexes
ANALYZE cities;
ANALYZE master_zmanim_registry;
ANALYZE publisher_zmanim;
ANALYZE publisher_coverage;
ANALYZE zman_tags;
ANALYZE geo_countries;
ANALYZE geo_regions;

-- ============================================
-- 8. QUERY HINTS (Comments for developers)
-- ============================================

COMMENT ON TABLE cities IS
    'Cities table - use idx_cities_name_trgm for ILIKE searches, idx_cities_country_population for country listings';

COMMENT ON TABLE master_zmanim_registry IS
    'Master zmanim registry - trigram indexes available for fuzzy Hebrew/English/transliteration searches';

COMMENT ON TABLE publisher_zmanim IS
    'Publisher zmanim - filtered queries should use publisher_id + deleted_at + is_enabled for best performance';

-- ============================================
-- PERFORMANCE NOTES
-- ============================================
/*
INDEX SIZE ESTIMATES:
- Trigram GIN indexes: ~2-5x larger than B-tree indexes
- Covering indexes: Larger but eliminate heap fetches
- Partial indexes (WHERE clauses): Much smaller, very fast

EXPECTED QUERY IMPROVEMENTS:
1. City name search: 10-100x faster (full table scan → index scan)
2. Master zmanim search: 5-50x faster (sequential scan → GIN index scan)
3. Publisher zmanim list: 2-5x faster (better index coverage)
4. Coverage queries: 2-3x faster (composite index helps subqueries)

MAINTENANCE:
- GIN indexes auto-update on INSERT/UPDATE (slight write overhead)
- Run VACUUM ANALYZE periodically to keep statistics fresh
- Monitor index usage with pg_stat_user_indexes
*/
