--
-- PostgreSQL database dump
--

\restrict PkCpT10fz9uHHn1DGb7rafi0s79kEQjh4hI2PI8d0dq6JJ8ytkz3qauZGXVksOR

-- Dumped from database version 17.5 (Debian 17.5-1.pgdg110+1)
-- Dumped by pg_dump version 17.7 (Ubuntu 17.7-3.pgdg24.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: assign_all_city_hierarchy(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.assign_all_city_hierarchy() RETURNS TABLE(level text, updated_count integer, unmatched_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_country_updated integer;
    v_country_unmatched integer;
    v_region_updated integer;
    v_region_unmatched integer;
    v_district_updated integer;
    v_district_unmatched integer;
BEGIN
    RAISE NOTICE 'Starting city hierarchy assignment via point-in-polygon...';

    -- Step 1: Assign countries
    RAISE NOTICE 'Step 1/3: Assigning cities to countries...';
    SELECT * INTO v_country_updated, v_country_unmatched FROM assign_cities_to_countries();
    RAISE NOTICE 'Countries: % updated, % unmatched', v_country_updated, v_country_unmatched;

    -- Step 2: Assign regions (depends on country being set)
    RAISE NOTICE 'Step 2/3: Assigning cities to regions...';
    SELECT * INTO v_region_updated, v_region_unmatched FROM assign_cities_to_regions();
    RAISE NOTICE 'Regions: % updated, % unmatched', v_region_updated, v_region_unmatched;

    -- Step 3: Assign districts (depends on region being set)
    RAISE NOTICE 'Step 3/3: Assigning cities to districts...';
    SELECT * INTO v_district_updated, v_district_unmatched FROM assign_cities_to_districts();
    RAISE NOTICE 'Districts: % updated, % unmatched', v_district_updated, v_district_unmatched;

    RAISE NOTICE 'City hierarchy assignment complete.';

    RETURN QUERY VALUES
        ('country'::text, v_country_updated, v_country_unmatched),
        ('region'::text, v_region_updated, v_region_unmatched),
        ('district'::text, v_district_updated, v_district_unmatched);
END;
$$;


ALTER FUNCTION public.assign_all_city_hierarchy() OWNER TO zmanim;

--
-- Name: FUNCTION assign_all_city_hierarchy(); Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON FUNCTION public.assign_all_city_hierarchy() IS 'Assigns all cities to countries/regions/districts based on point-in-polygon. Run after importing boundaries.';


--
-- Name: assign_cities_to_countries(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.assign_cities_to_countries() RETURNS TABLE(updated_count integer, unmatched_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_updated integer := 0;
    v_unmatched integer := 0;
BEGIN
    -- Temporarily disable the hierarchy trigger for bulk updates
    ALTER TABLE cities DISABLE TRIGGER validate_city_hierarchy_trigger;

    -- Update cities where coordinates fall within a country boundary
    WITH matches AS (
        UPDATE cities c
        SET country_id = cb.country_id,
            updated_at = now()
        FROM geo_country_boundaries cb
        WHERE ST_Contains(cb.boundary::geometry, c.location::geometry)
          AND c.country_id != cb.country_id
        RETURNING c.id
    )
    SELECT COUNT(*) INTO v_updated FROM matches;

    -- Count cities that don't fall within any country boundary
    SELECT COUNT(*) INTO v_unmatched
    FROM cities c
    WHERE NOT EXISTS (
        SELECT 1 FROM geo_country_boundaries cb
        WHERE ST_Contains(cb.boundary::geometry, c.location::geometry)
    );

    ALTER TABLE cities ENABLE TRIGGER validate_city_hierarchy_trigger;

    RETURN QUERY SELECT v_updated, v_unmatched;
END;
$$;


ALTER FUNCTION public.assign_cities_to_countries() OWNER TO zmanim;

--
-- Name: assign_cities_to_districts(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.assign_cities_to_districts() RETURNS TABLE(updated_count integer, unmatched_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_updated integer := 0;
    v_unmatched integer := 0;
BEGIN
    -- Temporarily disable the hierarchy trigger for bulk updates
    ALTER TABLE cities DISABLE TRIGGER validate_city_hierarchy_trigger;

    -- Update cities where coordinates fall within a district boundary
    -- Only match districts that belong to the city's region
    WITH matches AS (
        UPDATE cities c
        SET district_id = d.id,
            updated_at = now()
        FROM geo_district_boundaries db
        JOIN geo_districts d ON db.district_id = d.id
        WHERE ST_Contains(db.boundary::geometry, c.location::geometry)
          AND d.region_id = c.region_id
          AND c.region_id IS NOT NULL
          AND (c.district_id IS NULL OR c.district_id != d.id)
        RETURNING c.id
    )
    SELECT COUNT(*) INTO v_updated FROM matches;

    -- Count cities in countries with districts that don't fall within any district boundary
    SELECT COUNT(*) INTO v_unmatched
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm2 = true
      AND c.region_id IS NOT NULL
      AND c.district_id IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM geo_district_boundaries db
        JOIN geo_districts d ON db.district_id = d.id
        WHERE ST_Contains(db.boundary::geometry, c.location::geometry)
          AND d.region_id = c.region_id
    );

    ALTER TABLE cities ENABLE TRIGGER validate_city_hierarchy_trigger;

    RETURN QUERY SELECT v_updated, v_unmatched;
END;
$$;


ALTER FUNCTION public.assign_cities_to_districts() OWNER TO zmanim;

--
-- Name: assign_cities_to_regions(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.assign_cities_to_regions() RETURNS TABLE(updated_count integer, unmatched_count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_updated integer := 0;
    v_unmatched integer := 0;
BEGIN
    -- Temporarily disable the hierarchy trigger for bulk updates
    ALTER TABLE cities DISABLE TRIGGER validate_city_hierarchy_trigger;

    -- Update cities where coordinates fall within a region boundary
    -- Only match regions that belong to the city's country
    WITH matches AS (
        UPDATE cities c
        SET region_id = r.id,
            updated_at = now()
        FROM geo_region_boundaries rb
        JOIN geo_regions r ON rb.region_id = r.id
        WHERE ST_Contains(rb.boundary::geometry, c.location::geometry)
          AND r.country_id = c.country_id
          AND (c.region_id IS NULL OR c.region_id != r.id)
        RETURNING c.id
    )
    SELECT COUNT(*) INTO v_updated FROM matches;

    -- Count cities in countries with regions that don't fall within any region boundary
    SELECT COUNT(*) INTO v_unmatched
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm1 = true
      AND c.region_id IS NULL
      AND NOT EXISTS (
        SELECT 1 FROM geo_region_boundaries rb
        JOIN geo_regions r ON rb.region_id = r.id
        WHERE ST_Contains(rb.boundary::geometry, c.location::geometry)
          AND r.country_id = c.country_id
    );

    ALTER TABLE cities ENABLE TRIGGER validate_city_hierarchy_trigger;

    RETURN QUERY SELECT v_updated, v_unmatched;
END;
$$;


ALTER FUNCTION public.assign_cities_to_regions() OWNER TO zmanim;

--
-- Name: cleanup_expired_explanations(); Type: FUNCTION; Schema: public; Owner: zmanim
--

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


ALTER FUNCTION public.cleanup_expired_explanations() OWNER TO zmanim;

--
-- Name: get_next_zman_version(uuid); Type: FUNCTION; Schema: public; Owner: zmanim
--

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


ALTER FUNCTION public.get_next_zman_version(p_publisher_zman_id uuid) OWNER TO zmanim;

--
-- Name: get_publishers_for_city(uuid); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.get_publishers_for_city(p_city_id uuid) RETURNS TABLE(publisher_id uuid, publisher_name text, coverage_level text, priority integer, match_type text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_city RECORD;
BEGIN
    -- Get city's geographic hierarchy
    SELECT
        c.id,
        c.country_id,
        c.region_id,
        c.district_id,
        co.continent_id,
        cont.code as continent_code
    INTO v_city
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    JOIN geo_continents cont ON co.continent_id = cont.id
    WHERE c.id = p_city_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Return publishers with coverage matching this city
    -- Priority: city > district > region > country > continent
    RETURN QUERY
    SELECT DISTINCT ON (pc.publisher_id)
        pc.publisher_id,
        p.name::TEXT as publisher_name,
        pc.coverage_level,
        pc.priority,
        CASE pc.coverage_level
            WHEN 'city' THEN 'exact_city'
            WHEN 'district' THEN 'district_match'
            WHEN 'region' THEN 'region_match'
            WHEN 'country' THEN 'country_match'
            WHEN 'continent' THEN 'continent_match'
        END as match_type
    FROM publisher_coverage pc
    JOIN publishers p ON p.id = pc.publisher_id
    WHERE pc.is_active = TRUE
      AND p.status = 'active'
      AND (
        (pc.coverage_level = 'city' AND pc.city_id = p_city_id)
        OR (pc.coverage_level = 'district' AND pc.district_id = v_city.district_id AND v_city.district_id IS NOT NULL)
        OR (pc.coverage_level = 'region' AND pc.region_id = v_city.region_id AND v_city.region_id IS NOT NULL)
        OR (pc.coverage_level = 'country' AND pc.country_id = v_city.country_id)
        OR (pc.coverage_level = 'continent' AND pc.continent_code = v_city.continent_code)
      )
    ORDER BY pc.publisher_id,
             CASE pc.coverage_level
                 WHEN 'city' THEN 1
                 WHEN 'district' THEN 2
                 WHEN 'region' THEN 3
                 WHEN 'country' THEN 4
                 WHEN 'continent' THEN 5
             END,
             pc.priority DESC;
END;
$$;


ALTER FUNCTION public.get_publishers_for_city(p_city_id uuid) OWNER TO zmanim;

--
-- Name: FUNCTION get_publishers_for_city(p_city_id uuid); Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON FUNCTION public.get_publishers_for_city(p_city_id uuid) IS 'Find publishers serving a city based on geographic hierarchy (city > district > region > country > continent)';


--
-- Name: prune_publisher_snapshots(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.prune_publisher_snapshots() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM publisher_snapshots
    WHERE id IN (
        SELECT id FROM publisher_snapshots
        WHERE publisher_id = NEW.publisher_id
        ORDER BY created_at DESC
        OFFSET 20
    );
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.prune_publisher_snapshots() OWNER TO zmanim;

--
-- Name: prune_zman_versions(); Type: FUNCTION; Schema: public; Owner: zmanim
--

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


ALTER FUNCTION public.prune_zman_versions() OWNER TO zmanim;

--
-- Name: update_embeddings_updated_at(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_embeddings_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_embeddings_updated_at() OWNER TO zmanim;

--
-- Name: update_geo_updated_at(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_geo_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_geo_updated_at() OWNER TO zmanim;

--
-- Name: update_master_registry_updated_at(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_master_registry_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_master_registry_updated_at() OWNER TO zmanim;

--
-- Name: update_publisher_zman_day_types_updated_at(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_publisher_zman_day_types_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_publisher_zman_day_types_updated_at() OWNER TO zmanim;

--
-- Name: update_publisher_zman_events_updated_at(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_publisher_zman_events_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_publisher_zman_events_updated_at() OWNER TO zmanim;

--
-- Name: update_publisher_zmanim_updated_at(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_publisher_zmanim_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_publisher_zmanim_updated_at() OWNER TO zmanim;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO zmanim;

--
-- Name: validate_all_city_hierarchies(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_all_city_hierarchies() RETURNS TABLE(city_id bigint, city_name text, error_type text, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Find cities where country doesn't belong to city's continent
    RETURN QUERY
    SELECT c.id, c.name::text, 'country_continent_mismatch'::text,
           format('Country %s belongs to continent %s, not %s', c.country_id, gc.continent_id, c.continent_id)
    FROM cities c
    JOIN geo_countries gc ON c.country_id = gc.id
    WHERE c.country_id IS NOT NULL AND gc.continent_id != c.continent_id;

    -- Find cities where region's continent doesn't match
    RETURN QUERY
    SELECT c.id, c.name::text, 'region_continent_mismatch'::text,
           format('Region %s belongs to continent %s, not %s', c.region_id, r.continent_id, c.continent_id)
    FROM cities c
    JOIN geo_regions r ON c.region_id = r.id
    WHERE c.region_id IS NOT NULL AND r.continent_id != c.continent_id;

    -- Find cities where region has country but city has different/no country
    RETURN QUERY
    SELECT c.id, c.name::text, 'region_country_mismatch'::text,
           format('Region %s has country %s, city has country %s', c.region_id, r.country_id, c.country_id)
    FROM cities c
    JOIN geo_regions r ON c.region_id = r.id
    WHERE c.region_id IS NOT NULL
      AND r.country_id IS NOT NULL
      AND (c.country_id IS NULL OR c.country_id != r.country_id);

    -- Find cities where district's continent doesn't match
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_continent_mismatch'::text,
           format('District %s belongs to continent %s, not %s', c.district_id, d.continent_id, c.continent_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL AND d.continent_id != c.continent_id;

    -- Find cities where district has region but city has different/no region
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_region_mismatch'::text,
           format('District %s has region %s, city has region %s', c.district_id, d.region_id, c.region_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL
      AND d.region_id IS NOT NULL
      AND (c.region_id IS NULL OR c.region_id != d.region_id);

    -- Find cities where district has country but city has different/no country
    RETURN QUERY
    SELECT c.id, c.name::text, 'district_country_mismatch'::text,
           format('District %s has country %s, city has country %s', c.district_id, d.country_id, c.country_id)
    FROM cities c
    JOIN geo_districts d ON c.district_id = d.id
    WHERE c.district_id IS NOT NULL
      AND d.country_id IS NOT NULL
      AND (c.country_id IS NULL OR c.country_id != d.country_id);
END;
$$;


ALTER FUNCTION public.validate_all_city_hierarchies() OWNER TO zmanim;

--
-- Name: validate_all_city_hierarchy(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_all_city_hierarchy() RETURNS TABLE(issue_type text, city_id uuid, city_name text, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check for cities where assigned region doesn't match point-in-polygon result
    RETURN QUERY
    SELECT
        'region_mismatch'::text,
        c.id,
        c.name,
        format('Assigned to region %s (%s) but coordinates are in region %s (%s)',
               c.region_id, r1.name, r2.id, r2.name)
    FROM cities c
    JOIN geo_regions r1 ON c.region_id = r1.id
    JOIN geo_region_boundaries rb ON ST_Contains(rb.boundary::geometry, c.location::geometry)
    JOIN geo_regions r2 ON rb.region_id = r2.id AND r2.country_id = c.country_id
    WHERE c.region_id != r2.id;

    -- Check for cities where assigned district doesn't match point-in-polygon result
    RETURN QUERY
    SELECT
        'district_mismatch'::text,
        c.id,
        c.name,
        format('Assigned to district %s (%s) but coordinates are in district %s (%s)',
               c.district_id, d1.name, d2.id, d2.name)
    FROM cities c
    JOIN geo_districts d1 ON c.district_id = d1.id
    JOIN geo_district_boundaries db ON ST_Contains(db.boundary::geometry, c.location::geometry)
    JOIN geo_districts d2 ON db.district_id = d2.id AND d2.region_id = c.region_id
    WHERE c.district_id != d2.id;

    -- Check for cities missing region assignment in countries that have regions
    RETURN QUERY
    SELECT
        'missing_region'::text,
        c.id,
        c.name,
        format('In country %s which has_adm1=true but no region assigned', co.name)
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm1 = true
      AND c.region_id IS NULL;

    -- Check for cities missing district assignment in countries that have districts
    RETURN QUERY
    SELECT
        'missing_district'::text,
        c.id,
        c.name,
        format('In country %s which has_adm2=true but no district assigned', co.name)
    FROM cities c
    JOIN geo_countries co ON c.country_id = co.id
    WHERE co.has_adm2 = true
      AND c.region_id IS NOT NULL
      AND c.district_id IS NULL;
END;
$$;


ALTER FUNCTION public.validate_all_city_hierarchy() OWNER TO zmanim;

--
-- Name: FUNCTION validate_all_city_hierarchy(); Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON FUNCTION public.validate_all_city_hierarchy() IS 'Validates that all city hierarchy assignments match point-in-polygon results';


--
-- Name: validate_all_district_hierarchies(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_all_district_hierarchies() RETURNS TABLE(district_id integer, district_name text, error_type text, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Find districts where country doesn't belong to district's continent
    RETURN QUERY
    SELECT d.id, d.name::text, 'country_continent_mismatch'::text,
           format('Country %s belongs to continent %s, not %s', d.country_id, c.continent_id, d.continent_id)
    FROM geo_districts d
    JOIN geo_countries c ON d.country_id = c.id
    WHERE d.country_id IS NOT NULL AND c.continent_id != d.continent_id;

    -- Find districts where region's continent doesn't match district's continent
    RETURN QUERY
    SELECT d.id, d.name::text, 'region_continent_mismatch'::text,
           format('Region %s belongs to continent %s, not %s', d.region_id, r.continent_id, d.continent_id)
    FROM geo_districts d
    JOIN geo_regions r ON d.region_id = r.id
    WHERE d.region_id IS NOT NULL AND r.continent_id != d.continent_id;

    -- Find districts where region has country but district has different/no country
    RETURN QUERY
    SELECT d.id, d.name::text, 'region_country_mismatch'::text,
           format('Region %s has country %s, district has country %s', d.region_id, r.country_id, d.country_id)
    FROM geo_districts d
    JOIN geo_regions r ON d.region_id = r.id
    WHERE d.region_id IS NOT NULL
      AND r.country_id IS NOT NULL
      AND (d.country_id IS NULL OR d.country_id != r.country_id);
END;
$$;


ALTER FUNCTION public.validate_all_district_hierarchies() OWNER TO zmanim;

--
-- Name: validate_all_region_hierarchies(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_all_region_hierarchies() RETURNS TABLE(region_id integer, region_name text, error_type text, details text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Find regions where country doesn't belong to region's continent
    RETURN QUERY
    SELECT r.id, r.name::text, 'country_continent_mismatch'::text,
           format('Country %s belongs to continent %s, not %s', r.country_id, c.continent_id, r.continent_id)
    FROM geo_regions r
    JOIN geo_countries c ON r.country_id = c.id
    WHERE r.country_id IS NOT NULL AND c.continent_id != r.continent_id;
END;
$$;


ALTER FUNCTION public.validate_all_region_hierarchies() OWNER TO zmanim;

--
-- Name: validate_city_hierarchy(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_city_hierarchy() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    country_continent_id smallint;
    region_rec RECORD;
    district_rec RECORD;
BEGIN
    -- If country_id is set, verify it belongs to the city's continent
    IF NEW.country_id IS NOT NULL THEN
        SELECT continent_id INTO country_continent_id
        FROM geo_countries WHERE id = NEW.country_id;

        IF country_continent_id IS NULL THEN
            RAISE EXCEPTION 'Country % does not exist', NEW.country_id;
        END IF;

        IF country_continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Country % belongs to continent %, not continent %',
                NEW.country_id, country_continent_id, NEW.continent_id;
        END IF;
    END IF;

    -- If region_id is set, verify region exists and belongs to same continent
    IF NEW.region_id IS NOT NULL THEN
        SELECT continent_id, country_id INTO region_rec
        FROM geo_regions WHERE id = NEW.region_id;

        IF region_rec IS NULL THEN
            RAISE EXCEPTION 'Region % does not exist', NEW.region_id;
        END IF;

        IF region_rec.continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Region % belongs to continent %, not continent %',
                NEW.region_id, region_rec.continent_id, NEW.continent_id;
        END IF;

        -- If region has a country, city must have same country
        IF region_rec.country_id IS NOT NULL THEN
            IF NEW.country_id IS NULL THEN
                RAISE EXCEPTION 'Region % has country %, city must have same country_id',
                    NEW.region_id, region_rec.country_id;
            ELSIF NEW.country_id != region_rec.country_id THEN
                RAISE EXCEPTION 'Region % belongs to country %, not country %',
                    NEW.region_id, region_rec.country_id, NEW.country_id;
            END IF;
        END IF;
    END IF;

    -- If district_id is set, verify district exists and belongs to same continent
    IF NEW.district_id IS NOT NULL THEN
        SELECT continent_id, country_id, region_id INTO district_rec
        FROM geo_districts WHERE id = NEW.district_id;

        IF district_rec IS NULL THEN
            RAISE EXCEPTION 'District % does not exist', NEW.district_id;
        END IF;

        IF district_rec.continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'District % belongs to continent %, not continent %',
                NEW.district_id, district_rec.continent_id, NEW.continent_id;
        END IF;

        -- If district has a region, city must have same region
        IF district_rec.region_id IS NOT NULL THEN
            IF NEW.region_id IS NULL THEN
                RAISE EXCEPTION 'District % has region %, city must have same region_id',
                    NEW.district_id, district_rec.region_id;
            ELSIF NEW.region_id != district_rec.region_id THEN
                RAISE EXCEPTION 'District % belongs to region %, not region %',
                    NEW.district_id, district_rec.region_id, NEW.region_id;
            END IF;
        END IF;

        -- If district has a country, city must have same country
        IF district_rec.country_id IS NOT NULL THEN
            IF NEW.country_id IS NULL THEN
                RAISE EXCEPTION 'District % has country %, city must have same country_id',
                    NEW.district_id, district_rec.country_id;
            ELSIF NEW.country_id != district_rec.country_id THEN
                RAISE EXCEPTION 'District % belongs to country %, not country %',
                    NEW.district_id, district_rec.country_id, NEW.country_id;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_city_hierarchy() OWNER TO zmanim;

--
-- Name: validate_district_hierarchy(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_district_hierarchy() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    country_continent_id smallint;
    region_rec RECORD;
BEGIN
    -- If country_id is set, verify it belongs to the district's continent
    IF NEW.country_id IS NOT NULL THEN
        SELECT continent_id INTO country_continent_id
        FROM geo_countries WHERE id = NEW.country_id;

        IF country_continent_id IS NULL THEN
            RAISE EXCEPTION 'Country % does not exist', NEW.country_id;
        END IF;

        IF country_continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Country % belongs to continent %, not continent %',
                NEW.country_id, country_continent_id, NEW.continent_id;
        END IF;
    END IF;

    -- If region_id is set, verify region exists and belongs to same continent
    -- If region has a country, district must have the same country (or NULL)
    IF NEW.region_id IS NOT NULL THEN
        SELECT continent_id, country_id INTO region_rec
        FROM geo_regions WHERE id = NEW.region_id;

        IF region_rec IS NULL THEN
            RAISE EXCEPTION 'Region % does not exist', NEW.region_id;
        END IF;

        IF region_rec.continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Region % belongs to continent %, not continent %',
                NEW.region_id, region_rec.continent_id, NEW.continent_id;
        END IF;

        -- If region has a country, district must have same country
        IF region_rec.country_id IS NOT NULL THEN
            IF NEW.country_id IS NULL THEN
                RAISE EXCEPTION 'Region % has country %, district must have same country_id',
                    NEW.region_id, region_rec.country_id;
            ELSIF NEW.country_id != region_rec.country_id THEN
                RAISE EXCEPTION 'Region % belongs to country %, not country %',
                    NEW.region_id, region_rec.country_id, NEW.country_id;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_district_hierarchy() OWNER TO zmanim;

--
-- Name: validate_region_hierarchy(); Type: FUNCTION; Schema: public; Owner: zmanim
--

CREATE FUNCTION public.validate_region_hierarchy() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    country_continent_id smallint;
BEGIN
    -- If country_id is set, verify it belongs to the region's continent
    IF NEW.country_id IS NOT NULL THEN
        SELECT continent_id INTO country_continent_id
        FROM geo_countries WHERE id = NEW.country_id;

        IF country_continent_id IS NULL THEN
            RAISE EXCEPTION 'Country % does not exist', NEW.country_id;
        END IF;

        IF country_continent_id != NEW.continent_id THEN
            RAISE EXCEPTION 'Country % belongs to continent %, not continent %',
                NEW.country_id, country_continent_id, NEW.continent_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_region_hierarchy() OWNER TO zmanim;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_audit_logs; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.ai_audit_logs OWNER TO zmanim;

--
-- Name: TABLE ai_audit_logs; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.ai_audit_logs IS 'Audit log for all AI-powered formula generation and explanation requests';


--
-- Name: COLUMN ai_audit_logs.request_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.ai_audit_logs.request_type IS 'Type of AI request: generate_formula or explain_formula';


--
-- Name: COLUMN ai_audit_logs.confidence; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.ai_audit_logs.confidence IS 'AI confidence score for generated output (0.0 to 1.0)';


--
-- Name: COLUMN ai_audit_logs.rag_context_used; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.ai_audit_logs.rag_context_used IS 'Whether RAG context was included in the prompt';


--
-- Name: ai_index_status; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.ai_index_status (
    id integer NOT NULL,
    source character varying(255) NOT NULL,
    total_chunks integer DEFAULT 0 NOT NULL,
    last_indexed_at timestamp without time zone,
    status character varying(50) DEFAULT 'pending'::character varying,
    error_message text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.ai_index_status OWNER TO zmanim;

--
-- Name: TABLE ai_index_status; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.ai_index_status IS 'Tracks indexing status for each knowledge source. After migrations, run: cd api && go run cmd/indexer/main.go';


--
-- Name: ai_index_status_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

ALTER TABLE public.ai_index_status ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ai_index_status_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: algorithm_templates; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.algorithm_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_key text NOT NULL,
    name text NOT NULL,
    description text,
    configuration jsonb NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.algorithm_templates OWNER TO zmanim;

--
-- Name: TABLE algorithm_templates; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.algorithm_templates IS 'System-wide algorithm templates that publishers can use as starting points';


--
-- Name: COLUMN algorithm_templates.template_key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithm_templates.template_key IS 'Unique identifier (e.g., gra, mga, rabbeinu_tam, custom)';


--
-- Name: COLUMN algorithm_templates.configuration; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithm_templates.configuration IS 'Full algorithm JSON configuration with name, description, and zmanim map';


--
-- Name: COLUMN algorithm_templates.sort_order; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithm_templates.sort_order IS 'Display order in the template picker';


--
-- Name: COLUMN algorithm_templates.is_active; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithm_templates.is_active IS 'Whether this template is available for selection';


--
-- Name: algorithms; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.algorithms OWNER TO zmanim;

--
-- Name: TABLE algorithms; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.algorithms IS 'Algorithm configurations for publishers';


--
-- Name: COLUMN algorithms.is_public; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithms.is_public IS 'Whether this algorithm is visible and can be copied/forked by other publishers';


--
-- Name: COLUMN algorithms.forked_from; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithms.forked_from IS 'Reference to the source algorithm if this was forked';


--
-- Name: COLUMN algorithms.attribution_text; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithms.attribution_text IS 'Attribution text shown for forked algorithms';


--
-- Name: COLUMN algorithms.fork_count; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.algorithms.fork_count IS 'Number of times this algorithm has been forked';


--
-- Name: astronomical_primitives; Type: TABLE; Schema: public; Owner: zmanim
--

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
    CONSTRAINT chk_calculation_type CHECK (((calculation_type)::text = ANY (ARRAY[('horizon'::character varying)::text, ('solar_angle'::character varying)::text, ('transit'::character varying)::text]))),
    CONSTRAINT chk_category CHECK (((category)::text = ANY (ARRAY[('horizon'::character varying)::text, ('civil_twilight'::character varying)::text, ('nautical_twilight'::character varying)::text, ('astronomical_twilight'::character varying)::text, ('solar_position'::character varying)::text]))),
    CONSTRAINT chk_edge_type CHECK (((edge_type)::text = ANY (ARRAY[('center'::character varying)::text, ('top_edge'::character varying)::text, ('bottom_edge'::character varying)::text]))),
    CONSTRAINT chk_solar_angle CHECK (((((calculation_type)::text = 'solar_angle'::text) AND (solar_angle IS NOT NULL)) OR ((calculation_type)::text <> 'solar_angle'::text)))
);


ALTER TABLE public.astronomical_primitives OWNER TO zmanim;

--
-- Name: TABLE astronomical_primitives; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.astronomical_primitives IS 'Canonical registry of astronomical times that can be referenced in DSL formulas. These are pure astronomical calculations with no halachic interpretation.';


--
-- Name: COLUMN astronomical_primitives.variable_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.astronomical_primitives.variable_name IS 'The unique identifier used in DSL formulas (e.g., sunrise, nautical_dawn). Must be snake_case.';


--
-- Name: COLUMN astronomical_primitives.formula_dsl; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.astronomical_primitives.formula_dsl IS 'The DSL formula that calculates this time. Base primitives use their own name, derived use solar() function.';


--
-- Name: COLUMN astronomical_primitives.calculation_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.astronomical_primitives.calculation_type IS 'How to compute: horizon (0° crossing), solar_angle (degrees below horizon), transit (noon/midnight)';


--
-- Name: COLUMN astronomical_primitives.solar_angle; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.astronomical_primitives.solar_angle IS 'Degrees below horizon for solar_angle calculations (6° civil, 12° nautical, 18° astronomical)';


--
-- Name: COLUMN astronomical_primitives.is_dawn; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.astronomical_primitives.is_dawn IS 'True for morning events (dawn/sunrise), false for evening events (dusk/sunset), NULL for position events (noon/midnight)';


--
-- Name: COLUMN astronomical_primitives.edge_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.astronomical_primitives.edge_type IS 'Which part of the sun: center (geometric), top_edge (visible sunrise/sunset), bottom_edge';


--
-- Name: cities; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.cities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    region_id integer,
    district_id integer,
    name text NOT NULL,
    name_ascii text,
    name_local text,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    location public.geography(Point,4326) GENERATED ALWAYS AS ((public.st_setsrid(public.st_makepoint(longitude, latitude), 4326))::public.geography) STORED,
    timezone text NOT NULL,
    elevation_m integer DEFAULT 0,
    population integer,
    geonameid integer,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    wof_id bigint,
    continent_id smallint,
    country_id integer
);


ALTER TABLE public.cities OWNER TO zmanim;

--
-- Name: TABLE cities; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.cities IS 'Level 4: Cities with coordinates, timezone, and elevation for zmanim calculations';


--
-- Name: COLUMN cities.region_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.cities.region_id IS 'Region is optional - some WOF localities link directly to country. If set, must belong to country_id';


--
-- Name: COLUMN cities.district_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.cities.district_id IS 'District is optional - requires region_id to be set, must belong to same region';


--
-- Name: COLUMN cities.elevation_m; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.cities.elevation_m IS 'Elevation in meters above sea level, used for zmanim calculations';


--
-- Name: COLUMN cities.geonameid; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.cities.geonameid IS 'GeoNames ID for data source reference and deduplication';


--
-- Name: day_types; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.day_types OWNER TO zmanim;

--
-- Name: TABLE day_types; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.day_types IS 'DEPRECATED: Use jewish_events instead. Types of days for which zmanim can be configured.';


--
-- Name: COLUMN day_types.parent_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.day_types.parent_type IS 'Parent type name for hierarchical day types';


--
-- Name: display_groups; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.display_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(50) NOT NULL,
    display_name_hebrew character varying(100) NOT NULL,
    display_name_english character varying(100) NOT NULL,
    description character varying(255),
    icon_name character varying(50),
    color character varying(50),
    sort_order integer NOT NULL,
    time_categories text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.display_groups OWNER TO zmanim;

--
-- Name: TABLE display_groups; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.display_groups IS 'UI display groups that aggregate multiple time_categories for visual presentation';


--
-- Name: COLUMN display_groups.key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.display_groups.key IS 'Unique identifier for the display group (dawn, morning, midday, evening)';


--
-- Name: COLUMN display_groups.icon_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.display_groups.icon_name IS 'Lucide icon name (e.g., Moon, Sun, Clock, Sunset)';


--
-- Name: COLUMN display_groups.time_categories; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.display_groups.time_categories IS 'Array of time_category keys that belong to this display group';


--
-- Name: embeddings; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.embeddings OWNER TO zmanim;

--
-- Name: TABLE embeddings; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.embeddings IS 'Vector embeddings for RAG semantic search';


--
-- Name: COLUMN embeddings.source; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.embeddings.source IS 'Source document identifier (dsl-spec, kosher-java, halacha)';


--
-- Name: COLUMN embeddings.content_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.embeddings.content_type IS 'Type of content (documentation, example, source)';


--
-- Name: COLUMN embeddings.embedding; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.embeddings.embedding IS 'OpenAI text-embedding-3-small 1536-dimensional vector';


--
-- Name: event_categories; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.event_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(50) NOT NULL,
    display_name_hebrew character varying(100) NOT NULL,
    display_name_english character varying(100) NOT NULL,
    description character varying(255),
    icon_name character varying(50),
    color character varying(50),
    sort_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.event_categories OWNER TO zmanim;

--
-- Name: TABLE event_categories; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.event_categories IS 'Event-based categories for special zmanim (candles, havdalah, fasts, etc.)';


--
-- Name: COLUMN event_categories.key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.event_categories.key IS 'Unique identifier for the event category';


--
-- Name: COLUMN event_categories.icon_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.event_categories.icon_name IS 'Lucide icon name';


--
-- Name: COLUMN event_categories.color; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.event_categories.color IS 'Tailwind color class';


--
-- Name: explanation_cache; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.explanation_cache (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    formula_hash character varying(64) NOT NULL,
    language character varying(10) NOT NULL,
    explanation text NOT NULL,
    source character varying(20) DEFAULT 'ai'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone NOT NULL
);


ALTER TABLE public.explanation_cache OWNER TO zmanim;

--
-- Name: TABLE explanation_cache; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.explanation_cache IS 'Cache for AI-generated formula explanations';


--
-- Name: COLUMN explanation_cache.formula_hash; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.explanation_cache.formula_hash IS 'SHA-256 hash of the formula text';


--
-- Name: COLUMN explanation_cache.expires_at; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.explanation_cache.expires_at IS 'TTL is typically 7 days';


--
-- Name: geo_boundary_imports; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_boundary_imports (
    id integer NOT NULL,
    source text NOT NULL,
    level text NOT NULL,
    country_code character varying(2),
    version text,
    records_imported integer DEFAULT 0,
    records_matched integer DEFAULT 0,
    records_unmatched integer DEFAULT 0,
    imported_at timestamp with time zone DEFAULT now(),
    notes text
);


ALTER TABLE public.geo_boundary_imports OWNER TO zmanim;

--
-- Name: TABLE geo_boundary_imports; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_boundary_imports IS 'Tracks boundary data imports for reproducibility';


--
-- Name: geo_boundary_imports_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

CREATE SEQUENCE public.geo_boundary_imports_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.geo_boundary_imports_id_seq OWNER TO zmanim;

--
-- Name: geo_boundary_imports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zmanim
--

ALTER SEQUENCE public.geo_boundary_imports_id_seq OWNED BY public.geo_boundary_imports.id;


--
-- Name: geo_continents; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_continents (
    id smallint NOT NULL,
    code character varying(2) NOT NULL,
    name text NOT NULL,
    wof_id bigint
);


ALTER TABLE public.geo_continents OWNER TO zmanim;

--
-- Name: TABLE geo_continents; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_continents IS 'Level 0: 7 continents with ISO codes';


--
-- Name: geo_continents_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

CREATE SEQUENCE public.geo_continents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.geo_continents_id_seq OWNER TO zmanim;

--
-- Name: geo_continents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zmanim
--

ALTER SEQUENCE public.geo_continents_id_seq OWNED BY public.geo_continents.id;


--
-- Name: geo_countries; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_countries (
    id smallint NOT NULL,
    code character varying(2) NOT NULL,
    code_iso3 character varying(3),
    name text NOT NULL,
    name_local text,
    continent_id smallint NOT NULL,
    adm1_label text DEFAULT 'Region'::text,
    adm2_label text DEFAULT 'District'::text,
    has_adm1 boolean DEFAULT true,
    has_adm2 boolean DEFAULT false,
    is_city_state boolean DEFAULT false,
    population bigint,
    area_km2 double precision,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    wof_id bigint
);


ALTER TABLE public.geo_countries OWNER TO zmanim;

--
-- Name: TABLE geo_countries; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_countries IS 'Level 1 (ADM0): Countries with ISO 3166-1 codes and subdivision metadata';


--
-- Name: COLUMN geo_countries.adm1_label; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_countries.adm1_label IS 'Display label for ADM1 level: State (US), Province (CA), Constituent Country (GB)';


--
-- Name: COLUMN geo_countries.adm2_label; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_countries.adm2_label IS 'Display label for ADM2 level: County (US), Borough (GB), Département (FR)';


--
-- Name: COLUMN geo_countries.is_city_state; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_countries.is_city_state IS 'True for city-states like Singapore, Monaco, Vatican';


--
-- Name: geo_countries_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

ALTER TABLE public.geo_countries ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.geo_countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: geo_country_boundaries; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_country_boundaries (
    country_id smallint NOT NULL,
    boundary public.geography(MultiPolygon,4326) NOT NULL,
    boundary_simplified public.geography(MultiPolygon,4326),
    area_km2 double precision,
    centroid public.geography(Point,4326),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.geo_country_boundaries OWNER TO zmanim;

--
-- Name: TABLE geo_country_boundaries; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_country_boundaries IS 'Polygon boundaries for countries';


--
-- Name: COLUMN geo_country_boundaries.boundary_simplified; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_country_boundaries.boundary_simplified IS 'Simplified boundary for faster web rendering';


--
-- Name: geo_district_boundaries; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_district_boundaries (
    district_id integer NOT NULL,
    boundary public.geography(MultiPolygon,4326) NOT NULL,
    boundary_simplified public.geography(MultiPolygon,4326),
    area_km2 double precision,
    centroid public.geography(Point,4326),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.geo_district_boundaries OWNER TO zmanim;

--
-- Name: TABLE geo_district_boundaries; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_district_boundaries IS 'Polygon boundaries for districts/counties (ADM2)';


--
-- Name: geo_districts; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_districts (
    id integer NOT NULL,
    region_id integer,
    code text NOT NULL,
    name text NOT NULL,
    name_local text,
    population bigint,
    area_km2 double precision,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    wof_id bigint,
    continent_id smallint NOT NULL,
    country_id smallint
);


ALTER TABLE public.geo_districts OWNER TO zmanim;

--
-- Name: TABLE geo_districts; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_districts IS 'Level 3 (ADM2): Counties, boroughs, départements, local authorities';


--
-- Name: COLUMN geo_districts.region_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_districts.region_id IS 'Region is optional - requires country_id. If set, must belong to country_id';


--
-- Name: COLUMN geo_districts.code; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_districts.code IS 'Local administrative code (e.g., E08000003 for Manchester)';


--
-- Name: COLUMN geo_districts.continent_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_districts.continent_id IS 'Continent is required - every district belongs to exactly one continent (anchor point)';


--
-- Name: COLUMN geo_districts.country_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_districts.country_id IS 'Country is optional - some WOF districts link directly to continent. If set, must belong to continent_id';


--
-- Name: geo_districts_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

ALTER TABLE public.geo_districts ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.geo_districts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: geo_name_mappings; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_name_mappings (
    id integer NOT NULL,
    level text NOT NULL,
    source text NOT NULL,
    source_name text NOT NULL,
    source_country_code character varying(2),
    target_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    notes text,
    CONSTRAINT geo_name_mappings_level_check CHECK ((level = ANY (ARRAY['country'::text, 'region'::text, 'district'::text, 'city'::text])))
);


ALTER TABLE public.geo_name_mappings OWNER TO zmanim;

--
-- Name: TABLE geo_name_mappings; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_name_mappings IS 'Manual name mappings between data sources';


--
-- Name: geo_name_mappings_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

CREATE SEQUENCE public.geo_name_mappings_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.geo_name_mappings_id_seq OWNER TO zmanim;

--
-- Name: geo_name_mappings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: zmanim
--

ALTER SEQUENCE public.geo_name_mappings_id_seq OWNED BY public.geo_name_mappings.id;


--
-- Name: geo_region_boundaries; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_region_boundaries (
    region_id integer NOT NULL,
    boundary public.geography(MultiPolygon,4326) NOT NULL,
    boundary_simplified public.geography(MultiPolygon,4326),
    area_km2 double precision,
    centroid public.geography(Point,4326),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.geo_region_boundaries OWNER TO zmanim;

--
-- Name: TABLE geo_region_boundaries; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_region_boundaries IS 'Polygon boundaries for regions/states (ADM1)';


--
-- Name: geo_regions; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.geo_regions (
    id integer NOT NULL,
    country_id smallint,
    code text NOT NULL,
    name text NOT NULL,
    name_local text,
    population bigint,
    area_km2 double precision,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    wof_id bigint,
    continent_id smallint NOT NULL
);


ALTER TABLE public.geo_regions OWNER TO zmanim;

--
-- Name: TABLE geo_regions; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.geo_regions IS 'Level 2 (ADM1): States, provinces, constituent countries, regions';


--
-- Name: COLUMN geo_regions.country_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_regions.country_id IS 'Country is optional - some WOF regions link directly to continent (territories). If set, must belong to continent_id';


--
-- Name: COLUMN geo_regions.code; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_regions.code IS 'ISO 3166-2 subdivision code (e.g., US-CA for California)';


--
-- Name: COLUMN geo_regions.continent_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.geo_regions.continent_id IS 'Continent is required - every region belongs to exactly one continent (anchor point)';


--
-- Name: geo_regions_id_seq; Type: SEQUENCE; Schema: public; Owner: zmanim
--

ALTER TABLE public.geo_regions ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.geo_regions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: jewish_events; Type: TABLE; Schema: public; Owner: zmanim
--

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
    CONSTRAINT chk_event_type CHECK (((event_type)::text = ANY (ARRAY[('weekly'::character varying)::text, ('yom_tov'::character varying)::text, ('fast'::character varying)::text, ('informational'::character varying)::text]))),
    CONSTRAINT chk_fast_start_type CHECK (((fast_start_type IS NULL) OR ((fast_start_type)::text = ANY (ARRAY[('dawn'::character varying)::text, ('sunset'::character varying)::text]))))
);


ALTER TABLE public.jewish_events OWNER TO zmanim;

--
-- Name: TABLE jewish_events; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.jewish_events IS 'Canonical list of Jewish events (Shabbos, Yom Tov, fasts, etc.) with Israel/Diaspora duration differences';


--
-- Name: COLUMN jewish_events.event_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.jewish_events.event_type IS 'Type of event: weekly (Shabbos), yom_tov, fast, or informational (no linked zmanim)';


--
-- Name: COLUMN jewish_events.duration_days_israel; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.jewish_events.duration_days_israel IS 'Number of days this event lasts in Israel';


--
-- Name: COLUMN jewish_events.duration_days_diaspora; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.jewish_events.duration_days_diaspora IS 'Number of days this event lasts in the Diaspora';


--
-- Name: COLUMN jewish_events.fast_start_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.jewish_events.fast_start_type IS 'For fasts: dawn (regular fasts) or sunset (Yom Kippur, Tisha B''Av)';


--
-- Name: master_zman_day_types; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.master_zman_day_types (
    master_zman_id uuid NOT NULL,
    day_type_id uuid NOT NULL,
    is_default boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.master_zman_day_types OWNER TO zmanim;

--
-- Name: TABLE master_zman_day_types; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.master_zman_day_types IS 'DEPRECATED: Use master_zman_events instead.';


--
-- Name: master_zman_events; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.master_zman_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    master_zman_id uuid NOT NULL,
    jewish_event_id uuid NOT NULL,
    is_default boolean DEFAULT true,
    applies_to_day integer,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.master_zman_events OWNER TO zmanim;

--
-- Name: TABLE master_zman_events; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.master_zman_events IS 'Links zmanim to the Jewish events they apply to';


--
-- Name: COLUMN master_zman_events.applies_to_day; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zman_events.applies_to_day IS 'NULL = all days of event, 1 = day 1 only, 2 = day 2 only (for 2-day Yom Tov in Diaspora)';


--
-- Name: master_zman_tags; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.master_zman_tags (
    master_zman_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_negated boolean DEFAULT false NOT NULL
);


ALTER TABLE public.master_zman_tags OWNER TO zmanim;

--
-- Name: TABLE master_zman_tags; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.master_zman_tags IS 'Many-to-many relationship between zmanim and tags';


--
-- Name: COLUMN master_zman_tags.is_negated; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zman_tags.is_negated IS 'When true, this zman should NOT appear on days matching this tag';


--
-- Name: master_zmanim_registry; Type: TABLE; Schema: public; Owner: zmanim
--

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
    created_by character varying(255),
    updated_by character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_time_category CHECK (((time_category)::text = ANY (ARRAY[('dawn'::character varying)::text, ('sunrise'::character varying)::text, ('morning'::character varying)::text, ('midday'::character varying)::text, ('afternoon'::character varying)::text, ('sunset'::character varying)::text, ('nightfall'::character varying)::text, ('midnight'::character varying)::text])))
);


ALTER TABLE public.master_zmanim_registry OWNER TO zmanim;

--
-- Name: TABLE master_zmanim_registry; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.master_zmanim_registry IS 'Master zmanim registry - trigram indexes available for fuzzy Hebrew/English/transliteration searches';


--
-- Name: COLUMN master_zmanim_registry.zman_key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.zman_key IS 'Unique identifier for this zman type';


--
-- Name: COLUMN master_zmanim_registry.halachic_notes; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.halachic_notes IS 'Halachic background and reasoning for this zman';


--
-- Name: COLUMN master_zmanim_registry.time_category; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.time_category IS 'Time of day grouping for UI display';


--
-- Name: COLUMN master_zmanim_registry.is_core; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.is_core IS 'If true, this zman is a core/essential zman that cannot be removed from the registry';


--
-- Name: COLUMN master_zmanim_registry.is_hidden; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.is_hidden IS 'When true, this zman is hidden from public registry queries but visible to admins. Useful for deprecated or experimental zmanim.';


--
-- Name: COLUMN master_zmanim_registry.created_by; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.created_by IS 'Clerk user ID of the admin who created this zman';


--
-- Name: COLUMN master_zmanim_registry.updated_by; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.master_zmanim_registry.updated_by IS 'Clerk user ID of the admin who last updated this zman';


--
-- Name: zman_tags; Type: TABLE; Schema: public; Owner: zmanim
--

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
    CONSTRAINT zman_tags_tag_type_check CHECK (((tag_type)::text = ANY (ARRAY['event'::text, 'timing'::text, 'behavior'::text, 'shita'::text, 'calculation'::text, 'category'::text, 'jewish_day'::text])))
);


ALTER TABLE public.zman_tags OWNER TO zmanim;

--
-- Name: TABLE zman_tags; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.zman_tags IS 'Tags for categorizing zmanim by event type, timing, and behavior';


--
-- Name: COLUMN zman_tags.tag_key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_tags.tag_key IS 'Unique key identifier for the tag (e.g., shabbos, yom_tov)';


--
-- Name: master_zmanim_with_tags; Type: VIEW; Schema: public; Owner: zmanim
--

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
    created_by,
    updated_by,
    created_at,
    updated_at,
    COALESCE(( SELECT json_agg(json_build_object('tag_key', t.tag_key, 'display_name_hebrew', t.display_name_hebrew, 'display_name_english', t.display_name_english, 'tag_type', t.tag_type) ORDER BY t.sort_order) AS json_agg
           FROM (public.master_zman_tags mzt
             JOIN public.zman_tags t ON ((mzt.tag_id = t.id)))
          WHERE (mzt.master_zman_id = mz.id)), '[]'::json) AS tags
   FROM public.master_zmanim_registry mz;


ALTER VIEW public.master_zmanim_with_tags OWNER TO zmanim;

--
-- Name: VIEW master_zmanim_with_tags; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON VIEW public.master_zmanim_with_tags IS 'Master zmanim registry with their associated tags';


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.password_reset_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    token text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.password_reset_tokens OWNER TO zmanim;

--
-- Name: publisher_coverage; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.publisher_coverage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    coverage_level text NOT NULL,
    continent_code character varying(2),
    country_id smallint,
    region_id integer,
    district_id integer,
    city_id uuid,
    priority integer DEFAULT 5,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT publisher_coverage_coverage_level_check CHECK ((coverage_level = ANY (ARRAY['continent'::text, 'country'::text, 'region'::text, 'district'::text, 'city'::text]))),
    CONSTRAINT publisher_coverage_priority_check CHECK (((priority >= 1) AND (priority <= 10))),
    CONSTRAINT valid_coverage_data CHECK ((((coverage_level = 'continent'::text) AND (continent_code IS NOT NULL) AND (country_id IS NULL) AND (region_id IS NULL) AND (district_id IS NULL) AND (city_id IS NULL)) OR ((coverage_level = 'country'::text) AND (country_id IS NOT NULL) AND (region_id IS NULL) AND (district_id IS NULL) AND (city_id IS NULL)) OR ((coverage_level = 'region'::text) AND (region_id IS NOT NULL) AND (district_id IS NULL) AND (city_id IS NULL)) OR ((coverage_level = 'district'::text) AND (district_id IS NOT NULL) AND (city_id IS NULL)) OR ((coverage_level = 'city'::text) AND (city_id IS NOT NULL))))
);


ALTER TABLE public.publisher_coverage OWNER TO zmanim;

--
-- Name: TABLE publisher_coverage; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_coverage IS 'Publisher geographic coverage at continent, country, region, district, or city level';


--
-- Name: COLUMN publisher_coverage.coverage_level; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_coverage.coverage_level IS 'Granularity: continent > country > region > district > city';


--
-- Name: COLUMN publisher_coverage.priority; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_coverage.priority IS 'Priority for this coverage (1-10, higher = more prominent)';


--
-- Name: publisher_invitations; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.publisher_invitations OWNER TO zmanim;

--
-- Name: TABLE publisher_invitations; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_invitations IS 'DEPRECATED: This table is no longer used. User management now creates users directly via Clerk instead of using invitations. Table kept for historical reference but will be empty.';


--
-- Name: publisher_onboarding; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.publisher_onboarding OWNER TO zmanim;

--
-- Name: TABLE publisher_onboarding; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_onboarding IS 'Tracks onboarding wizard state for publishers';


--
-- Name: COLUMN publisher_onboarding.wizard_data; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_onboarding.wizard_data IS 'JSON data containing template selection, customizations, and coverage';


--
-- Name: COLUMN publisher_onboarding.skipped; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_onboarding.skipped IS 'True if publisher skipped the wizard';


--
-- Name: publisher_requests; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.publisher_requests OWNER TO zmanim;

--
-- Name: TABLE publisher_requests; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_requests IS 'Requests from users to become publishers. Publisher name IS the organization name.';


--
-- Name: publisher_snapshots; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.publisher_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_id uuid NOT NULL,
    description text NOT NULL,
    snapshot_data jsonb NOT NULL,
    created_by text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.publisher_snapshots OWNER TO zmanim;

--
-- Name: publisher_zman_aliases; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.publisher_zman_aliases OWNER TO zmanim;

--
-- Name: TABLE publisher_zman_aliases; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_zman_aliases IS 'Custom display names for zmanim per publisher. Original master registry names remain accessible via master_zmanim_registry.';


--
-- Name: COLUMN publisher_zman_aliases.custom_hebrew_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zman_aliases.custom_hebrew_name IS 'Publisher-specific Hebrew display name';


--
-- Name: COLUMN publisher_zman_aliases.custom_english_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zman_aliases.custom_english_name IS 'Publisher-specific English display name';


--
-- Name: COLUMN publisher_zman_aliases.custom_transliteration; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zman_aliases.custom_transliteration IS 'Optional publisher-specific transliteration';


--
-- Name: COLUMN publisher_zman_aliases.is_active; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zman_aliases.is_active IS 'Whether this alias is currently in use';


--
-- Name: publisher_zman_day_types; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.publisher_zman_day_types (
    publisher_zman_id uuid NOT NULL,
    day_type_id uuid NOT NULL,
    is_visible boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.publisher_zman_day_types OWNER TO zmanim;

--
-- Name: TABLE publisher_zman_day_types; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_zman_day_types IS 'DEPRECATED: Use publisher_zman_events instead.';


--
-- Name: publisher_zman_events; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.publisher_zman_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_zman_id uuid NOT NULL,
    jewish_event_id uuid NOT NULL,
    is_enabled boolean DEFAULT true,
    applies_to_day integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.publisher_zman_events OWNER TO zmanim;

--
-- Name: TABLE publisher_zman_events; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_zman_events IS 'Publisher overrides for which events their zmanim apply to';


--
-- Name: publisher_zman_tags; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.publisher_zman_tags (
    publisher_zman_id uuid NOT NULL,
    tag_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_negated boolean DEFAULT false NOT NULL
);


ALTER TABLE public.publisher_zman_tags OWNER TO zmanim;

--
-- Name: TABLE publisher_zman_tags; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_zman_tags IS 'Publisher-specific tags for zmanim. These override/supplement the master registry tags.';


--
-- Name: COLUMN publisher_zman_tags.is_negated; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zman_tags.is_negated IS 'When true, this zman should NOT appear on days matching this tag';


--
-- Name: publisher_zman_versions; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.publisher_zman_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    publisher_zman_id uuid NOT NULL,
    version_number integer NOT NULL,
    formula_dsl text NOT NULL,
    created_by character varying(255),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.publisher_zman_versions OWNER TO zmanim;

--
-- Name: TABLE publisher_zman_versions; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_zman_versions IS 'Version history for each publisher zman (max 7 versions, formula changes only)';


--
-- Name: publisher_zmanim; Type: TABLE; Schema: public; Owner: zmanim
--

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
    CONSTRAINT publisher_zmanim_source_type_check CHECK (((source_type)::text = ANY (ARRAY[('registry'::character varying)::text, ('copied'::character varying)::text, ('linked'::character varying)::text, ('custom'::character varying)::text])))
);


ALTER TABLE public.publisher_zmanim OWNER TO zmanim;

--
-- Name: TABLE publisher_zmanim; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publisher_zmanim IS 'Publisher zmanim - filtered queries should use publisher_id + deleted_at + is_enabled for best performance';


--
-- Name: COLUMN publisher_zmanim.formula_dsl; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.formula_dsl IS 'DSL formula string. Examples: "proportional_hours(3, gra)" for 3 hours after sunrise, "solar(16.1, before_sunrise)" for dawn';


--
-- Name: COLUMN publisher_zmanim.publisher_comment; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.publisher_comment IS 'Publisher''s personal notes, minhag, or halachic source';


--
-- Name: COLUMN publisher_zmanim.is_enabled; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.is_enabled IS 'Whether this zman is active in the algorithm (for preview/calculation)';


--
-- Name: COLUMN publisher_zmanim.is_published; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.is_published IS 'Whether this zman is publicly visible to end users';


--
-- Name: COLUMN publisher_zmanim.category; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.category IS 'essential = always enabled, optional = can toggle, custom = user created';


--
-- Name: COLUMN publisher_zmanim.dependencies; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.dependencies IS 'Auto-extracted @references from formula_dsl';


--
-- Name: COLUMN publisher_zmanim.linked_publisher_zman_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.linked_publisher_zman_id IS 'For linked zmanim, points to the source zman from another publisher';


--
-- Name: COLUMN publisher_zmanim.source_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.source_type IS 'How this zman was created: registry, copied, linked, or custom';


--
-- Name: COLUMN publisher_zmanim.is_beta; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.is_beta IS 'When true, this zman is in beta mode and displayed with a warning to users. Publishers use beta mode to gather feedback before certifying a zman as stable.';


--
-- Name: COLUMN publisher_zmanim.certified_at; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.certified_at IS 'Timestamp when is_beta was changed from true to false, indicating publisher certification';


--
-- Name: COLUMN publisher_zmanim.transliteration; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.transliteration IS 'Publisher''s custom transliteration (can differ from registry)';


--
-- Name: COLUMN publisher_zmanim.description; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publisher_zmanim.description IS 'Publisher''s description of what this zman represents (can differ from registry)';


--
-- Name: publishers; Type: TABLE; Schema: public; Owner: zmanim
--

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
    is_certified boolean DEFAULT false NOT NULL,
    suspension_reason text,
    deleted_at timestamp with time zone,
    deleted_by text,
    CONSTRAINT publishers_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text])))
);


ALTER TABLE public.publishers OWNER TO zmanim;

--
-- Name: TABLE publishers; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.publishers IS 'Publishers who provide zmanim calculations. Publisher name IS the organization name.';


--
-- Name: COLUMN publishers.is_published; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.is_published IS 'Whether the publisher profile and zmanim are publicly visible';


--
-- Name: COLUMN publishers.bio; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.bio IS 'Short biography or about text for the publisher';


--
-- Name: COLUMN publishers.slug; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.slug IS 'URL-friendly unique identifier for the publisher';


--
-- Name: COLUMN publishers.is_verified; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.is_verified IS 'Verified publishers can have their zmanim linked to by other publishers';


--
-- Name: COLUMN publishers.logo_data; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.logo_data IS 'Base64 encoded logo image (PNG format, data:image/png;base64,...)';


--
-- Name: COLUMN publishers.is_certified; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.is_certified IS 'Whether this publisher is a certified/authoritative source for zmanim calculations. Non-certified publishers are community-contributed.';


--
-- Name: COLUMN publishers.suspension_reason; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.suspension_reason IS 'The reason provided when this publisher was suspended. Cleared when reactivated.';


--
-- Name: COLUMN publishers.deleted_at; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.deleted_at IS 'Timestamp when the publisher was soft-deleted. NULL means active.';


--
-- Name: COLUMN publishers.deleted_by; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.publishers.deleted_by IS 'The admin user ID who performed the soft delete.';


--
-- Name: publisher_zmanim_resolved; Type: VIEW; Schema: public; Owner: zmanim
--

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


ALTER VIEW public.publisher_zmanim_resolved OWNER TO zmanim;

--
-- Name: VIEW publisher_zmanim_resolved; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON VIEW public.publisher_zmanim_resolved IS 'Resolves linked zmanim to their source formulas at query time';


--
-- Name: publisher_zmanim_with_registry; Type: VIEW; Schema: public; Owner: zmanim
--

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


ALTER VIEW public.publisher_zmanim_with_registry OWNER TO zmanim;

--
-- Name: VIEW publisher_zmanim_with_registry; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON VIEW public.publisher_zmanim_with_registry IS 'Convenience view that joins publisher_zmanim with master registry data';


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.schema_migrations (
    version text NOT NULL,
    applied_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.schema_migrations OWNER TO zmanim;

--
-- Name: system_config; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.system_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key text NOT NULL,
    value jsonb NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.system_config OWNER TO zmanim;

--
-- Name: tag_event_mappings; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.tag_event_mappings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tag_id uuid NOT NULL,
    hebcal_event_pattern character varying(100),
    hebrew_month integer,
    hebrew_day_start integer,
    hebrew_day_end integer,
    priority integer DEFAULT 100,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT valid_mapping CHECK (((hebcal_event_pattern IS NOT NULL) OR ((hebrew_month IS NOT NULL) AND (hebrew_day_start IS NOT NULL))))
);


ALTER TABLE public.tag_event_mappings OWNER TO zmanim;

--
-- Name: TABLE tag_event_mappings; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.tag_event_mappings IS 'Maps zman_tags to HebCal events or Hebrew dates for calendar-based filtering';


--
-- Name: COLUMN tag_event_mappings.hebcal_event_pattern; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.tag_event_mappings.hebcal_event_pattern IS 'HebCal event pattern. Use % as wildcard. E.g., "Chanukah%" matches all Chanukah days.';


--
-- Name: COLUMN tag_event_mappings.hebrew_month; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.tag_event_mappings.hebrew_month IS 'Hebrew month number: 1=Nisan...12=Adar, 13=Adar II in leap year';


--
-- Name: COLUMN tag_event_mappings.priority; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.tag_event_mappings.priority IS 'Higher priority patterns are matched first for overlapping dates';


--
-- Name: tag_types; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.tag_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(50) NOT NULL,
    display_name_hebrew character varying(100) NOT NULL,
    display_name_english character varying(100) NOT NULL,
    color character varying(255),
    sort_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.tag_types OWNER TO zmanim;

--
-- Name: TABLE tag_types; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.tag_types IS 'Types of tags used to categorize zmanim (timing, event, shita, method, behavior)';


--
-- Name: COLUMN tag_types.key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.tag_types.key IS 'Unique identifier matching zman_tags.tag_type';


--
-- Name: COLUMN tag_types.color; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.tag_types.color IS 'Tailwind CSS classes for badge styling';


--
-- Name: time_categories; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.time_categories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    key character varying(50) NOT NULL,
    display_name_hebrew character varying(100) NOT NULL,
    display_name_english character varying(100) NOT NULL,
    description character varying(255),
    icon_name character varying(50),
    color character varying(50),
    sort_order integer NOT NULL,
    is_everyday boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.time_categories OWNER TO zmanim;

--
-- Name: TABLE time_categories; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.time_categories IS 'Time of day categories for grouping zmanim (dawn, sunrise, morning, etc.)';


--
-- Name: COLUMN time_categories.key; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.time_categories.key IS 'Unique identifier matching master_zmanim_registry.time_category';


--
-- Name: COLUMN time_categories.icon_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.time_categories.icon_name IS 'Lucide icon name (e.g., Sunrise, Moon, Clock)';


--
-- Name: COLUMN time_categories.color; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.time_categories.color IS 'Tailwind color class (e.g., purple, amber, indigo)';


--
-- Name: COLUMN time_categories.is_everyday; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.time_categories.is_everyday IS 'True if this category applies to everyday zmanim';


--
-- Name: zman_display_contexts; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.zman_display_contexts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    master_zman_id uuid NOT NULL,
    context_code character varying(50) NOT NULL,
    display_name_hebrew text NOT NULL,
    display_name_english text NOT NULL,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.zman_display_contexts OWNER TO zmanim;

--
-- Name: TABLE zman_display_contexts; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.zman_display_contexts IS 'Context-specific display names for zmanim with the same calculation but different labels';


--
-- Name: COLUMN zman_display_contexts.context_code; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_display_contexts.context_code IS 'Context identifier - matches jewish_events.code or special values';


--
-- Name: zman_registry_requests; Type: TABLE; Schema: public; Owner: zmanim
--

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
    CONSTRAINT chk_request_status CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('approved'::character varying)::text, ('rejected'::character varying)::text])))
);


ALTER TABLE public.zman_registry_requests OWNER TO zmanim;

--
-- Name: TABLE zman_registry_requests; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.zman_registry_requests IS 'Requests from publishers to add new zmanim to the master registry';


--
-- Name: COLUMN zman_registry_requests.transliteration; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.transliteration IS 'Transliteration of the Hebrew name';


--
-- Name: COLUMN zman_registry_requests.description; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.description IS 'Brief description of the zman';


--
-- Name: COLUMN zman_registry_requests.halachic_notes; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.halachic_notes IS 'Halachic context or notes';


--
-- Name: COLUMN zman_registry_requests.halachic_source; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.halachic_source IS 'Source references (seforim, poskim)';


--
-- Name: COLUMN zman_registry_requests.publisher_email; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.publisher_email IS 'Contact email for the requesting publisher';


--
-- Name: COLUMN zman_registry_requests.publisher_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.publisher_name IS 'Display name of the requesting publisher';


--
-- Name: COLUMN zman_registry_requests.auto_add_on_approval; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_registry_requests.auto_add_on_approval IS 'If true, automatically add this zman to publisher''s list when approved';


--
-- Name: zman_request_tags; Type: TABLE; Schema: public; Owner: zmanim
--

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


ALTER TABLE public.zman_request_tags OWNER TO zmanim;

--
-- Name: TABLE zman_request_tags; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.zman_request_tags IS 'Tags associated with zman registry requests. Supports both existing tag references and new tag requests.';


--
-- Name: COLUMN zman_request_tags.tag_id; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_request_tags.tag_id IS 'Reference to existing tag (if using existing tag)';


--
-- Name: COLUMN zman_request_tags.requested_tag_name; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_request_tags.requested_tag_name IS 'Name of requested new tag (if requesting new tag)';


--
-- Name: COLUMN zman_request_tags.requested_tag_type; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_request_tags.requested_tag_type IS 'Type of requested new tag: event, timing, behavior, shita, method';


--
-- Name: COLUMN zman_request_tags.is_new_tag_request; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zman_request_tags.is_new_tag_request IS 'True if this is a request for a new tag to be created';


--
-- Name: zmanim_templates; Type: TABLE; Schema: public; Owner: zmanim
--

CREATE TABLE public.zmanim_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    zman_key text NOT NULL,
    hebrew_name text NOT NULL,
    english_name text NOT NULL,
    formula_dsl text NOT NULL,
    category text NOT NULL,
    description text,
    is_required boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT zmanim_templates_category_check CHECK ((category = ANY (ARRAY['essential'::text, 'optional'::text])))
);


ALTER TABLE public.zmanim_templates OWNER TO zmanim;

--
-- Name: TABLE zmanim_templates; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON TABLE public.zmanim_templates IS 'System-wide default zmanim formulas that publishers can copy from';


--
-- Name: COLUMN zmanim_templates.formula_dsl; Type: COMMENT; Schema: public; Owner: zmanim
--

COMMENT ON COLUMN public.zmanim_templates.formula_dsl IS 'DSL formula string. proportional_hours(N, gra) returns absolute time N hours after sunrise. proportional_hours(N, mga) returns N hours after dawn (72min before sunrise).';


--
-- Name: geo_boundary_imports id; Type: DEFAULT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_boundary_imports ALTER COLUMN id SET DEFAULT nextval('public.geo_boundary_imports_id_seq'::regclass);


--
-- Name: geo_continents id; Type: DEFAULT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_continents ALTER COLUMN id SET DEFAULT nextval('public.geo_continents_id_seq'::regclass);


--
-- Name: geo_name_mappings id; Type: DEFAULT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_name_mappings ALTER COLUMN id SET DEFAULT nextval('public.geo_name_mappings_id_seq'::regclass);


--
-- Data for Name: ai_audit_logs; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.ai_audit_logs (id, publisher_id, user_id, request_type, input_text, output_text, tokens_used, model, confidence, success, error_message, duration_ms, rag_context_used, created_at) FROM stdin;
be788be6-67e0-42c8-afc6-7c35f5b8026b	6c85458d-2225-4f55-bc15-5c9844bcf362	user_35yX6LKszGc7misNhjGdU0eMeyQ	explain_formula	proportional_hours(3, gra)	Three proportional hours after נץ according to the גר"א. This calculates שעות זמניות by dividing the day from נץ to שקיעה into 12 equal parts, then adding 3 of those parts to נץ. This is typically used for the latest time for קריאת שמע (שו"ע או"ח נ"ח א').	0	claude-3-5-sonnet-20241022	1.000	t		5636	f	2025-12-03 18:46:58.697054+00
0cb12c8b-605d-43ee-b49c-1dfa63d60d0b	6c85458d-2225-4f55-bc15-5c9844bcf362	user_35yX6LKszGc7misNhjGdU0eMeyQ	explain_formula	sunrise	זמן הנץ החמה is calculated as the moment when the sun's upper edge first appears above the visible horizon. Most contemporary פוסקים follow the שו"ע או"ח רל"ג that uses the apparent/visual horizon rather than sea level, accounting for local elevation and geographical features. This serves as the baseline for calculating other זמנים like סוף זמן קריאת שמע and תפלה according to both the מג"א and גר"א.	0	claude-3-5-sonnet-20241022	1.000	t		6789	f	2025-12-04 15:54:53.764493+00
cec7ddfd-3c5b-4673-ba24-f15a130ca796	6c85458d-2225-4f55-bc15-5c9844bcf362	user_35yX6LKszGc7misNhjGdU0eMeyQ	explain_formula	solar(8, after_sunset)	This calculates 8° below the horizon after שקיעה (geometric sunset). This corresponds to the opinion that צאת הכוכבים occurs when the sun reaches 8° below the horizon, which is approximately 36 minutes after שקיעה in Jerusalem year-round. This follows certain פוסקים who hold that three medium stars become visible at this depression angle, marking the end of בין השמשות.	0	claude-3-5-sonnet-20241022	1.000	t		5567	f	2025-12-04 16:04:33.649225+00
\.


--
-- Data for Name: ai_index_status; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.ai_index_status (id, source, total_chunks, last_indexed_at, status, error_message, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: algorithm_templates; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.algorithm_templates (id, template_key, name, description, configuration, sort_order, is_active, created_at, updated_at) FROM stdin;
8bd80e4d-727e-4632-a485-7a9ef7a1a4f4	gra	GRA (Vilna Gaon)	Standard calculation based on the Vilna Gaon. Uses sunrise to sunset for proportional hours.	{"name": "GRA", "zmanim": {"tzais": {"method": "solar_angle", "params": {"degrees": 8.5}}, "sunset": {"method": "sunset", "params": {}}, "chatzos": {"method": "midpoint", "params": {"end": "sunset", "start": "sunrise"}}, "sunrise": {"method": "sunrise", "params": {}}, "misheyakir": {"method": "solar_angle", "params": {"degrees": 11.5}}, "mincha_gedola": {"method": "proportional", "params": {"base": "gra", "hours": 6.5}}, "mincha_ketana": {"method": "proportional", "params": {"base": "gra", "hours": 9.5}}, "plag_hamincha": {"method": "proportional", "params": {"base": "gra", "hours": 10.75}}, "alos_hashachar": {"method": "solar_angle", "params": {"degrees": 16.1}}, "sof_zman_shma_gra": {"method": "proportional", "params": {"base": "gra", "hours": 3.0}}, "sof_zman_tfila_gra": {"method": "proportional", "params": {"base": "gra", "hours": 4.0}}}, "description": "Vilna Gaon standard calculation"}	1	t	2025-12-03 21:03:48.752923+00	2025-12-03 21:03:48.752923+00
f6ee7167-7c94-41f9-9565-acf592d0c212	mga	MGA (Magen Avraham)	Magen Avraham calculation. Uses 72 minutes before sunrise to 72 minutes after sunset for proportional hours.	{"name": "MGA", "zmanim": {"sunset": {"method": "sunset", "params": {}}, "chatzos": {"method": "midpoint", "params": {"end": "sunset", "start": "sunrise"}}, "sunrise": {"method": "sunrise", "params": {}}, "tzeis_72": {"method": "fixed_minutes", "params": {"from": "sunset", "minutes": 72.0}}, "misheyakir": {"method": "solar_angle", "params": {"degrees": 11.5}}, "mincha_gedola": {"method": "proportional", "params": {"base": "mga", "hours": 6.5}}, "mincha_ketana": {"method": "proportional", "params": {"base": "mga", "hours": 9.5}}, "plag_hamincha": {"method": "proportional", "params": {"base": "mga", "hours": 10.75}}, "alos_hashachar": {"method": "fixed_minutes", "params": {"from": "sunrise", "minutes": -72.0}}, "sof_zman_shma_mga": {"method": "proportional", "params": {"base": "mga", "hours": 3.0}}, "sof_zman_tfila_mga": {"method": "proportional", "params": {"base": "mga", "hours": 4.0}}}, "description": "Magen Avraham calculation"}	2	t	2025-12-03 21:03:48.752923+00	2025-12-03 21:03:48.752923+00
ef5d28b3-e8f9-4d56-a1a3-93d1c6eea8ce	rabbeinu_tam	Rabbeinu Tam	Uses 72 minutes after sunset for tzeis based on Rabbeinu Tam's opinion.	{"name": "Rabbeinu Tam", "zmanim": {"tzais": {"method": "solar_angle", "params": {"degrees": 8.5}}, "sunset": {"method": "sunset", "params": {}}, "chatzos": {"method": "midpoint", "params": {"end": "sunset", "start": "sunrise"}}, "sunrise": {"method": "sunrise", "params": {}}, "tzeis_72": {"method": "fixed_minutes", "params": {"from": "sunset", "minutes": 72.0}}, "misheyakir": {"method": "solar_angle", "params": {"degrees": 11.5}}, "mincha_gedola": {"method": "proportional", "params": {"base": "gra", "hours": 6.5}}, "mincha_ketana": {"method": "proportional", "params": {"base": "gra", "hours": 9.5}}, "plag_hamincha": {"method": "proportional", "params": {"base": "gra", "hours": 10.75}}, "alos_hashachar": {"method": "solar_angle", "params": {"degrees": 16.1}}, "sof_zman_shma_gra": {"method": "proportional", "params": {"base": "gra", "hours": 3.0}}, "sof_zman_tfila_gra": {"method": "proportional", "params": {"base": "gra", "hours": 4.0}}}, "description": "Rabbeinu Tam calculation for tzeis"}	3	t	2025-12-03 21:03:48.752923+00	2025-12-03 21:03:48.752923+00
d235c40d-adb2-4f9d-af4b-c8c0fde18216	custom	Custom	Start with basic times and customize each zman according to your minhag.	{"name": "Custom", "zmanim": {"sunset": {"method": "sunset", "params": {}}, "chatzos": {"method": "midpoint", "params": {"end": "sunset", "start": "sunrise"}}, "sunrise": {"method": "sunrise", "params": {}}}, "description": "Custom algorithm"}	4	t	2025-12-03 21:03:48.752923+00	2025-12-03 21:03:48.752923+00
\.


--
-- Data for Name: algorithms; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.algorithms (id, publisher_id, name, description, configuration, status, is_public, forked_from, attribution_text, fork_count, created_at, updated_at) FROM stdin;
ac0fcfb7-58cd-4e35-9ca4-1a36f4289687	6c85458d-2225-4f55-bc15-5c9844bcf362	Manchester Machzikei Hadass Standard	Official zmanim calculation method for Machzikei Hadass Manchester community. Based on nearly 80 years of community practice, following Minchas Yitzchak 9:9 for Dawn at 12° and custom MGA calculations.	{"notes": "Per Minchas Yitzchak, 12° dawn corresponds with reality in Northern Europe. Candle lighting 15 min before sunset is ancient custom.", "mga_base": {"end": "7.08_degrees", "start": "12_degrees"}, "nightfall": "7.08_degrees", "misheyakir": "11.5_degrees", "primary_dawn": "12_degrees", "shabbos_ends": "8_degrees", "secondary_dawn": "16.1_degrees", "candle_lighting_offset": 15}	published	t	\N	\N	0	2025-12-04 12:50:30.617612+00	2025-12-04 12:50:30.617612+00
\.


--
-- Data for Name: astronomical_primitives; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.astronomical_primitives (id, variable_name, display_name, description, formula_dsl, category, calculation_type, solar_angle, is_dawn, edge_type, sort_order, created_at, updated_at) FROM stdin;
0321a89a-0bd3-44a1-9353-993cc97b35ea	sunrise	Sunrise	Geometric sunrise - sun center crosses the horizon (0°)	sunrise	horizon	horizon	\N	t	center	100	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
d9e48271-ae23-4340-add7-953011a84f6e	sunset	Sunset	Geometric sunset - sun center crosses the horizon (0°)	sunset	horizon	horizon	\N	f	center	101	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
bc54c077-fa5c-4eea-8d38-ee5991db43dc	sunrise_visible	Sunrise (Visible)	First visible edge of sun appears above horizon (accounting for refraction)	visible_sunrise	horizon	horizon	\N	t	top_edge	102	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
ce459996-0bc4-465a-8488-1f7aed1abcde	sunset_visible	Sunset (Visible)	Last visible edge of sun disappears below horizon (accounting for refraction)	visible_sunset	horizon	horizon	\N	f	top_edge	103	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
d035938b-8a66-46a3-a212-bea0e1cac378	civil_dawn	Civil Dawn	Sun 6° below horizon - enough light for outdoor activities without artificial light	solar(6, before_sunrise)	civil_twilight	solar_angle	6.00	t	center	200	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
bed4d0bb-2593-4085-9793-437f630bda81	civil_dusk	Civil Dusk	Sun 6° below horizon - artificial light needed for outdoor activities	solar(6, after_sunset)	civil_twilight	solar_angle	6.00	f	center	201	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
c4fe4542-ebb5-4641-aab0-a3e96696f410	nautical_dawn	Nautical Dawn	Sun 12° below horizon - horizon visible at sea for navigation	solar(12, before_sunrise)	nautical_twilight	solar_angle	12.00	t	center	300	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
35dedb70-b2c3-4355-a507-cedbf3927091	nautical_dusk	Nautical Dusk	Sun 12° below horizon - horizon no longer visible at sea	solar(12, after_sunset)	nautical_twilight	solar_angle	12.00	f	center	301	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
5ed694f0-32f6-4b46-8227-0948eac4cc3c	astronomical_dawn	Astronomical Dawn	Sun 18° below horizon - sky completely dark before this, first hint of light	solar(18, before_sunrise)	astronomical_twilight	solar_angle	18.00	t	center	400	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
98d890e2-6931-4e07-94c7-009ea4398fdf	astronomical_dusk	Astronomical Dusk	Sun 18° below horizon - sky becomes completely dark after this	solar(18, after_sunset)	astronomical_twilight	solar_angle	18.00	f	center	401	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
baa5e9be-ac0e-4b57-9493-b52a7cebe08c	solar_noon	Solar Noon	Sun at highest point in the sky (transit/meridian crossing)	solar_noon	solar_position	transit	\N	\N	center	500	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
409372fe-3ff2-4a22-9890-ee2fa1978646	solar_midnight	Solar Midnight	Sun at lowest point (anti-transit) - opposite side of Earth	solar_midnight	solar_position	transit	\N	\N	center	501	2025-12-03 16:12:57.928935+00	2025-12-03 16:12:57.928935+00
\.


--
-- Data for Name: cities; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.cities (id, region_id, district_id, name, name_ascii, name_local, latitude, longitude, timezone, elevation_m, population, geonameid, created_at, updated_at, wof_id, continent_id, country_id) FROM stdin;
\.


--
-- Data for Name: day_types; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.day_types (id, name, display_name_hebrew, display_name_english, description, parent_type, sort_order, created_at) FROM stdin;
827a57ba-81b4-49ec-a244-cd1c5455e6b6	weekday	יום חול	Weekday	Regular weekday (Sunday-Thursday)	\N	10	2025-12-03 16:12:57.925596+00
9bcc31da-94f2-4353-ac37-cedf4af14249	friday	יום שישי	Friday	Friday (Erev Shabbos)	weekday	15	2025-12-03 16:12:57.925596+00
8db25bcc-2d32-4c29-9e9a-d33730e420cf	erev_shabbos	ערב שבת	Erev Shabbos	Friday afternoon before Shabbos	\N	20	2025-12-03 16:12:57.925596+00
19839ebc-e2d9-49bc-8482-be7d6ace2456	shabbos	שבת	Shabbos	Shabbat day	\N	25	2025-12-03 16:12:57.925596+00
7004052c-1337-46d3-8bc8-38481da2f7c4	motzei_shabbos	מוצאי שבת	Motzei Shabbos	Saturday night after Shabbos	\N	30	2025-12-03 16:12:57.925596+00
8b902cc1-96be-491d-af54-8702aa833768	erev_yom_tov	ערב יום טוב	Erev Yom Tov	Day before Yom Tov	\N	40	2025-12-03 16:12:57.925596+00
b4cf3d17-4a26-471d-a672-ff2a17651993	yom_tov	יום טוב	Yom Tov	Festival day (Pesach, Shavuos, Sukkos, etc.)	\N	45	2025-12-03 16:12:57.925596+00
96913326-3b01-4c64-945d-e45fe86d8f10	motzei_yom_tov	מוצאי יום טוב	Motzei Yom Tov	Night after Yom Tov	\N	50	2025-12-03 16:12:57.925596+00
4bf88b63-2b13-403b-b4c6-b269619ec39c	chol_hamoed	חול המועד	Chol HaMoed	Intermediate festival days	\N	55	2025-12-03 16:12:57.925596+00
68509553-7a7c-4cb3-ae2a-a3e69497604e	erev_pesach	ערב פסח	Erev Pesach	Day before Pesach	erev_yom_tov	60	2025-12-03 16:12:57.925596+00
93a6a6b7-f228-499a-92c5-2d2a8f570e08	pesach	פסח	Pesach	Passover (first and last days)	yom_tov	61	2025-12-03 16:12:57.925596+00
6f1a2e8c-f551-4f50-bb4d-8777704972e3	erev_shavuos	ערב שבועות	Erev Shavuos	Day before Shavuos	erev_yom_tov	65	2025-12-03 16:12:57.925596+00
3af7a036-675f-4a74-a343-d91f64903448	shavuos	שבועות	Shavuos	Feast of Weeks	yom_tov	66	2025-12-03 16:12:57.925596+00
f53a331d-8e20-45f4-a591-a36517ad08d9	erev_rosh_hashanah	ערב ראש השנה	Erev Rosh Hashanah	Day before Rosh Hashanah	erev_yom_tov	70	2025-12-03 16:12:57.925596+00
49fc433f-fc18-43ce-9f03-c74d60d88e94	rosh_hashanah	ראש השנה	Rosh Hashanah	Jewish New Year	yom_tov	71	2025-12-03 16:12:57.925596+00
db11bf2c-ff8a-4df0-9dc8-346f0d40f869	erev_yom_kippur	ערב יום כיפור	Erev Yom Kippur	Day before Yom Kippur	erev_yom_tov	75	2025-12-03 16:12:57.925596+00
09cbc643-2d18-4bd3-b5e9-7507390d7cc5	yom_kippur	יום כיפור	Yom Kippur	Day of Atonement	yom_tov	76	2025-12-03 16:12:57.925596+00
e4f6a20b-5192-49e9-b0f5-6db06a8736a6	erev_sukkos	ערב סוכות	Erev Sukkos	Day before Sukkos	erev_yom_tov	80	2025-12-03 16:12:57.925596+00
a35192be-1755-4818-9dad-27d835beda0c	sukkos	סוכות	Sukkos	Feast of Tabernacles	yom_tov	81	2025-12-03 16:12:57.925596+00
2b545007-b93c-4408-b4ea-1a7927d6422a	hoshanah_rabbah	הושענא רבה	Hoshanah Rabbah	7th day of Sukkos	chol_hamoed	82	2025-12-03 16:12:57.925596+00
b18d718b-cb6d-4c66-b733-574612034c3d	shemini_atzeres	שמיני עצרת	Shemini Atzeres	8th day of Sukkos	yom_tov	83	2025-12-03 16:12:57.925596+00
099faed5-4afc-4c07-a271-29d9e87f44b5	simchas_torah	שמחת תורה	Simchas Torah	Rejoicing of the Torah	yom_tov	84	2025-12-03 16:12:57.925596+00
721bce1d-42ca-4d89-bfc2-d480c2be10d2	taanis	תענית	Fast Day	General fast day	\N	100	2025-12-03 16:12:57.925596+00
b808187f-e004-45a6-adbc-929cd8c8a045	taanis_start	תחילת תענית	Beginning of Fast	Start of a fast day	taanis	101	2025-12-03 16:12:57.925596+00
f58a6b40-95d7-4d4a-9bba-d01a5962eb71	taanis_end	סוף תענית	End of Fast	End of a fast day	taanis	102	2025-12-03 16:12:57.925596+00
fb97a26b-6f03-41cd-82ca-f3b57c05e3a2	tzom_gedaliah	צום גדליה	Tzom Gedaliah	Fast of Gedaliah	taanis	110	2025-12-03 16:12:57.925596+00
1eecad76-c9ca-4f70-9fd2-675cc6b96dc0	asarah_bteves	עשרה בטבת	Asarah B'Teves	10th of Teves	taanis	111	2025-12-03 16:12:57.925596+00
5b20382c-e8db-472b-b3a6-ebb8d289824a	taanis_esther	תענית אסתר	Taanis Esther	Fast of Esther	taanis	112	2025-12-03 16:12:57.925596+00
e37a2a0c-334b-4aba-8a6d-c340b73e2b7a	shiva_asar_btamuz	שבעה עשר בתמוז	Shiva Asar B'Tamuz	17th of Tamuz	taanis	113	2025-12-03 16:12:57.925596+00
e5e570c4-2efd-4dc0-8c42-eab66f254008	tisha_bav	תשעה באב	Tisha B'Av	9th of Av	taanis	114	2025-12-03 16:12:57.925596+00
f8f1c070-97ff-4f78-b4a3-b187e2a56adc	erev_tisha_bav	ערב תשעה באב	Erev Tisha B'Av	Evening before Tisha B'Av when the fast begins at sunset	taanis	115	2025-12-03 16:12:57.925596+00
120b8448-8a83-437f-ae28-4634fe5ca8f5	rosh_chodesh	ראש חודש	Rosh Chodesh	New month	\N	120	2025-12-03 16:12:57.925596+00
2a11e6f7-6a4e-41ba-9b69-dd9762a2f674	chanukah	חנוכה	Chanukah	Festival of Lights	\N	130	2025-12-03 16:12:57.925596+00
b67c2fba-0f5f-424a-b0a5-0ecfbbcf5f24	purim	פורים	Purim	Feast of Lots	\N	135	2025-12-03 16:12:57.925596+00
91bd98fc-a3e9-4b33-9639-432a5e81e360	shushan_purim	שושן פורים	Shushan Purim	Purim in walled cities	\N	136	2025-12-03 16:12:57.925596+00
cf2f182d-efab-4451-93ee-00231a9ec6c1	lag_baomer	ל"ג בעומר	Lag BaOmer	33rd day of Omer	\N	140	2025-12-03 16:12:57.925596+00
e40c7369-a8ef-4e71-82d1-98f6f6098340	tu_bshvat	ט"ו בשבט	Tu B'Shvat	New Year of Trees	\N	145	2025-12-03 16:12:57.925596+00
7fb38b40-8b9f-42f7-9128-1838427e85bc	yom_haatzmaut	יום העצמאות	Yom HaAtzmaut	Israel Independence Day	\N	150	2025-12-03 16:12:57.925596+00
e8a1d82c-6344-4d55-b3cf-884abaf9a9a4	yom_yerushalayim	יום ירושלים	Yom Yerushalayim	Jerusalem Day	\N	151	2025-12-03 16:12:57.925596+00
4ec64456-7b10-4a3b-9435-4b7b34b686e1	yom_hazikaron	יום הזיכרון	Yom HaZikaron	Memorial Day	\N	152	2025-12-03 16:12:57.925596+00
3e5a2a6e-de81-4832-a86b-aa90733a745b	yom_hashoah	יום השואה	Yom HaShoah	Holocaust Remembrance Day	\N	153	2025-12-03 16:12:57.925596+00
\.


--
-- Data for Name: display_groups; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.display_groups (id, key, display_name_hebrew, display_name_english, description, icon_name, color, sort_order, time_categories, created_at) FROM stdin;
0dd75197-9fad-4d7f-8244-50a57321b71e	dawn	שחר	Dawn	Pre-sunrise zmanim	Moon	purple	1	{dawn}	2025-12-03 20:49:33.318992+00
006c073c-8c57-456e-854f-8a2389d272b8	morning	בוקר	Morning	Sunrise through late morning zmanim	Sun	amber	2	{sunrise,morning}	2025-12-03 20:49:33.318992+00
e654deb8-7c91-4246-81f3-e890ee772983	midday	צהריים	Midday	Midday and afternoon zmanim	Clock	orange	3	{midday,afternoon}	2025-12-03 20:49:33.318992+00
8596de98-4cd9-4588-8f1f-dd57680ad495	evening	ערב	Evening	Sunset through nightfall zmanim	Sunset	rose	4	{sunset,nightfall,midnight}	2025-12-03 20:49:33.318992+00
\.


--
-- Data for Name: embeddings; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.embeddings (id, source, content_type, chunk_index, content, metadata, embedding, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: event_categories; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.event_categories (id, key, display_name_hebrew, display_name_english, description, icon_name, color, sort_order, created_at) FROM stdin;
176f4f87-4ed9-4b19-a49d-1e5539321965	candles	הדלקת נרות	Candle Lighting	Shabbos, Yom Tov, and Yom Kippur	Flame	amber	1	2025-12-03 20:01:03.057913+00
1598cea6-9bf1-4c80-a06d-066f76850c7b	havdalah	הבדלה	Havdalah	End of Shabbos and Yom Tov	Flame	purple	2	2025-12-03 20:01:03.057913+00
e412b990-18c2-4444-96e6-3cdbc61ee78b	yom_kippur	יום כיפור	Yom Kippur	Fast start and end times	Moon	slate	3	2025-12-03 20:01:03.057913+00
b9320a2f-dc59-4493-a6ce-eb4d67d8c076	fast_day	תענית	Fast Days	Fast end times (regular fasts)	Timer	gray	4	2025-12-03 20:01:03.057913+00
be81f9c3-1b2c-4e7b-994e-3edafea99a7f	tisha_bav	תשעה באב	Tisha B'Av	Fast starts at sunset, ends at nightfall	Moon	slate	5	2025-12-03 20:01:03.057913+00
9796dce4-88f2-4292-bf0b-6f94456a0da7	pesach	פסח	Pesach	Chametz eating and burning times	Utensils	green	6	2025-12-03 20:01:03.057913+00
\.


--
-- Data for Name: explanation_cache; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.explanation_cache (id, formula_hash, language, explanation, source, created_at, expires_at) FROM stdin;
d4b52f50-86cf-4d29-9dd9-6f74814e9ff4	b01bf780367b4df4	mixed	Three proportional hours after נץ according to the גר"א. This calculates שעות זמניות by dividing the day from נץ to שקיעה into 12 equal parts, then adding 3 of those parts to נץ. This is typically used for the latest time for קריאת שמע (שו"ע או"ח נ"ח א').	ai	2025-12-03 18:46:58.703213+00	2025-12-10 18:46:58.703213+00
e11aa94c-84de-41ba-861e-c2e5f63150d7	0000001893299778	mixed	זמן הנץ החמה is calculated as the moment when the sun's upper edge first appears above the visible horizon. Most contemporary פוסקים follow the שו"ע או"ח רל"ג that uses the apparent/visual horizon rather than sea level, accounting for local elevation and geographical features. This serves as the baseline for calculating other זמנים like סוף זמן קריאת שמע and תפלה according to both the מג"א and גר"א.	ai	2025-12-04 15:54:53.768788+00	2025-12-11 15:54:53.768788+00
12bcc688-2c88-4b9e-b3f7-f5e01d9a82c5	14874946cca89956	mixed	This calculates 8° below the horizon after שקיעה (geometric sunset). This corresponds to the opinion that צאת הכוכבים occurs when the sun reaches 8° below the horizon, which is approximately 36 minutes after שקיעה in Jerusalem year-round. This follows certain פוסקים who hold that three medium stars become visible at this depression angle, marking the end of בין השמשות.	ai	2025-12-04 16:04:33.651765+00	2025-12-11 16:04:33.651765+00
\.


--
-- Data for Name: geo_boundary_imports; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_boundary_imports (id, source, level, country_code, version, records_imported, records_matched, records_unmatched, imported_at, notes) FROM stdin;
\.


--
-- Data for Name: geo_continents; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_continents (id, code, name, wof_id) FROM stdin;
\.


--
-- Data for Name: geo_countries; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_countries (id, code, code_iso3, name, name_local, continent_id, adm1_label, adm2_label, has_adm1, has_adm2, is_city_state, population, area_km2, created_at, updated_at, wof_id) FROM stdin;
\.


--
-- Data for Name: geo_country_boundaries; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_country_boundaries (country_id, boundary, boundary_simplified, area_km2, centroid, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: geo_district_boundaries; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_district_boundaries (district_id, boundary, boundary_simplified, area_km2, centroid, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: geo_districts; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_districts (id, region_id, code, name, name_local, population, area_km2, created_at, updated_at, wof_id, continent_id, country_id) FROM stdin;
\.


--
-- Data for Name: geo_name_mappings; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_name_mappings (id, level, source, source_name, source_country_code, target_id, created_at, notes) FROM stdin;
\.


--
-- Data for Name: geo_region_boundaries; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_region_boundaries (region_id, boundary, boundary_simplified, area_km2, centroid, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: geo_regions; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.geo_regions (id, country_id, code, name, name_local, population, area_km2, created_at, updated_at, wof_id, continent_id) FROM stdin;
\.


--
-- Data for Name: jewish_events; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.jewish_events (id, code, name_hebrew, name_english, event_type, duration_days_israel, duration_days_diaspora, fast_start_type, parent_event_code, sort_order, created_at) FROM stdin;
20a2e8d5-7462-471a-b8ea-f47757cad6c2	shabbos	שבת	Shabbos	weekly	1	1	\N	\N	10	2025-12-03 16:12:57.927208+00
53fcba17-8db2-4355-aaf7-6f75a48cd6d6	yom_kippur	יום כיפור	Yom Kippur	fast	1	1	sunset	\N	20	2025-12-03 16:12:57.927208+00
d1283681-58e3-46cb-8c13-8cc22bc42228	tisha_bav	תשעה באב	Tisha B'Av	fast	1	1	sunset	\N	21	2025-12-03 16:12:57.927208+00
e72351c4-b2e0-4325-a4b0-6251ffdbf137	tzom_gedaliah	צום גדליה	Tzom Gedaliah	fast	1	1	dawn	\N	30	2025-12-03 16:12:57.927208+00
28d8d191-1ef3-4214-97d9-c1f0a6313956	asarah_bteves	עשרה בטבת	Asarah B'Teves	fast	1	1	dawn	\N	31	2025-12-03 16:12:57.927208+00
23235ac3-3c66-4d9f-a63a-769e1f3ebb7d	shiva_asar_btamuz	שבעה עשר בתמוז	Shiva Asar B'Tamuz	fast	1	1	dawn	\N	32	2025-12-03 16:12:57.927208+00
77664e4c-a0a4-458b-b30f-f735c31df243	taanis_esther	תענית אסתר	Taanis Esther	fast	1	1	dawn	\N	33	2025-12-03 16:12:57.927208+00
621e3fb7-bbbb-4e5b-bc4f-0d4be8ba082e	rosh_hashanah	ראש השנה	Rosh Hashanah	yom_tov	2	2	\N	\N	40	2025-12-03 16:12:57.927208+00
b6b8237c-2b9a-4782-8869-12f2a551ccb1	sukkos	סוכות	Sukkos	yom_tov	1	2	\N	\N	50	2025-12-03 16:12:57.927208+00
9c86866a-5a90-4cb1-a248-d317b783dcc2	shemini_atzeres	שמיני עצרת	Shemini Atzeres	yom_tov	1	2	\N	\N	51	2025-12-03 16:12:57.927208+00
b153da61-3924-4082-ac5c-1643205fd4c6	pesach_first	פסח (ראשון)	Pesach (First Days)	yom_tov	1	2	\N	\N	60	2025-12-03 16:12:57.927208+00
76fefedc-7eff-4b11-a9eb-4d9df7e28acd	pesach_last	פסח (אחרון)	Pesach (Last Days)	yom_tov	1	2	\N	\N	61	2025-12-03 16:12:57.927208+00
743f800b-d374-4e31-b3e0-b6cd011c11fb	shavuos	שבועות	Shavuos	yom_tov	1	2	\N	\N	70	2025-12-03 16:12:57.927208+00
4fa4456c-db83-4b9b-ac91-4ea4b0a8acf1	rosh_chodesh	ראש חודש	Rosh Chodesh	informational	1	1	\N	\N	100	2025-12-03 16:12:57.927208+00
771787f8-3cd3-431a-8604-624912953ab0	chanukah	חנוכה	Chanukah	informational	8	8	\N	\N	110	2025-12-03 16:12:57.927208+00
f9fbed84-9199-4531-8fa7-70c2dd385766	purim	פורים	Purim	informational	1	1	\N	\N	120	2025-12-03 16:12:57.927208+00
7363bad8-8c67-44a9-bd91-6e9cb1226d95	shushan_purim	שושן פורים	Shushan Purim	informational	1	1	\N	\N	121	2025-12-03 16:12:57.927208+00
5f8ef1e0-7e96-462e-8213-a54e62483423	lag_baomer	ל"ג בעומר	Lag BaOmer	informational	1	1	\N	\N	130	2025-12-03 16:12:57.927208+00
f614de0a-4f35-4243-9c8b-686381b2cdbb	tu_bshvat	ט"ו בשבט	Tu B'Shvat	informational	1	1	\N	\N	140	2025-12-03 16:12:57.927208+00
84bc0e7c-9d68-46ea-b759-377a2a1ce165	yom_haatzmaut	יום העצמאות	Yom HaAtzmaut	informational	1	1	\N	\N	150	2025-12-03 16:12:57.927208+00
ccaacc09-1122-4ea6-a77f-c8ebc07a7b22	yom_yerushalayim	יום ירושלים	Yom Yerushalayim	informational	1	1	\N	\N	151	2025-12-03 16:12:57.927208+00
096426f4-d9d0-4a8e-b73d-e6203ffed2e0	yom_hazikaron	יום הזיכרון	Yom HaZikaron	informational	1	1	\N	\N	152	2025-12-03 16:12:57.927208+00
f0c3e82b-a187-426f-a6fd-69d0b2b36667	yom_hashoah	יום השואה	Yom HaShoah	informational	1	1	\N	\N	153	2025-12-03 16:12:57.927208+00
\.


--
-- Data for Name: master_zman_day_types; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.master_zman_day_types (master_zman_id, day_type_id, is_default, created_at) FROM stdin;
\.


--
-- Data for Name: master_zman_events; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.master_zman_events (id, master_zman_id, jewish_event_id, is_default, applies_to_day, notes, created_at) FROM stdin;
\.


--
-- Data for Name: master_zman_tags; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.master_zman_tags (master_zman_id, tag_id, created_at, is_negated) FROM stdin;
8b861617-e264-4542-a8db-01f7512cab7d	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
8b861617-e264-4542-a8db-01f7512cab7d	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
8b861617-e264-4542-a8db-01f7512cab7d	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
8b861617-e264-4542-a8db-01f7512cab7d	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
8b861617-e264-4542-a8db-01f7512cab7d	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
2e51a9f7-98b2-4916-89f8-374a508ca84e	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
2e51a9f7-98b2-4916-89f8-374a508ca84e	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
2e51a9f7-98b2-4916-89f8-374a508ca84e	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
2e51a9f7-98b2-4916-89f8-374a508ca84e	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
2e51a9f7-98b2-4916-89f8-374a508ca84e	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
49004e69-b792-4ff0-9bae-b2f1c9602c45	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
49004e69-b792-4ff0-9bae-b2f1c9602c45	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
49004e69-b792-4ff0-9bae-b2f1c9602c45	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
49004e69-b792-4ff0-9bae-b2f1c9602c45	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
49004e69-b792-4ff0-9bae-b2f1c9602c45	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
acd2cfd4-c72a-42ce-9662-7e71462c72fd	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
acd2cfd4-c72a-42ce-9662-7e71462c72fd	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
acd2cfd4-c72a-42ce-9662-7e71462c72fd	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
acd2cfd4-c72a-42ce-9662-7e71462c72fd	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
acd2cfd4-c72a-42ce-9662-7e71462c72fd	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
f838eb44-3813-4f3c-afb8-e3608d82aaab	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
f838eb44-3813-4f3c-afb8-e3608d82aaab	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
f838eb44-3813-4f3c-afb8-e3608d82aaab	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.935321+00	f
f838eb44-3813-4f3c-afb8-e3608d82aaab	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-03 16:12:57.935321+00	f
f838eb44-3813-4f3c-afb8-e3608d82aaab	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
888f7113-4a77-44a1-aa1d-22cb297297a5	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
888f7113-4a77-44a1-aa1d-22cb297297a5	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
888f7113-4a77-44a1-aa1d-22cb297297a5	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
888f7113-4a77-44a1-aa1d-22cb297297a5	84b9580e-7adf-4bc1-9d22-5d9eacf296fd	2025-12-03 16:12:57.935321+00	f
888f7113-4a77-44a1-aa1d-22cb297297a5	6c10a75d-ab64-46ee-b801-66fce7c75844	2025-12-03 16:12:57.935321+00	f
4ebdc38e-e320-45a8-8b25-6642a3459c74	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
4ebdc38e-e320-45a8-8b25-6642a3459c74	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
4ebdc38e-e320-45a8-8b25-6642a3459c74	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
4ebdc38e-e320-45a8-8b25-6642a3459c74	84b9580e-7adf-4bc1-9d22-5d9eacf296fd	2025-12-03 16:12:57.935321+00	f
4ebdc38e-e320-45a8-8b25-6642a3459c74	6c10a75d-ab64-46ee-b801-66fce7c75844	2025-12-03 16:12:57.935321+00	f
249b4706-eda1-4a4b-85f1-cd6bfcac4088	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
249b4706-eda1-4a4b-85f1-cd6bfcac4088	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
249b4706-eda1-4a4b-85f1-cd6bfcac4088	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
249b4706-eda1-4a4b-85f1-cd6bfcac4088	84b9580e-7adf-4bc1-9d22-5d9eacf296fd	2025-12-03 16:12:57.935321+00	f
249b4706-eda1-4a4b-85f1-cd6bfcac4088	6c10a75d-ab64-46ee-b801-66fce7c75844	2025-12-03 16:12:57.935321+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-03 16:12:57.935321+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-03 16:12:57.935321+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.935321+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	84b9580e-7adf-4bc1-9d22-5d9eacf296fd	2025-12-03 16:12:57.935321+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	6c10a75d-ab64-46ee-b801-66fce7c75844	2025-12-03 16:12:57.935321+00	f
5873dd70-0a42-44e7-aba4-d0eeec0457a0	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.935321+00	f
5873dd70-0a42-44e7-aba4-d0eeec0457a0	191e5b1f-7183-43b2-93f8-c8c7dea23332	2025-12-03 16:12:57.935321+00	f
5873dd70-0a42-44e7-aba4-d0eeec0457a0	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
5873dd70-0a42-44e7-aba4-d0eeec0457a0	5059e4c2-2ccd-4a8c-9696-dc77de8bd4dd	2025-12-03 16:12:57.935321+00	f
19e9cf01-7db7-42e5-b6fb-eb6081d9a4fd	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.935321+00	f
19e9cf01-7db7-42e5-b6fb-eb6081d9a4fd	191e5b1f-7183-43b2-93f8-c8c7dea23332	2025-12-03 16:12:57.935321+00	f
19e9cf01-7db7-42e5-b6fb-eb6081d9a4fd	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
19e9cf01-7db7-42e5-b6fb-eb6081d9a4fd	5059e4c2-2ccd-4a8c-9696-dc77de8bd4dd	2025-12-03 16:12:57.935321+00	f
73e14767-7d8e-4205-8ce1-d6d172d6dec5	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.935321+00	f
73e14767-7d8e-4205-8ce1-d6d172d6dec5	191e5b1f-7183-43b2-93f8-c8c7dea23332	2025-12-03 16:12:57.935321+00	f
73e14767-7d8e-4205-8ce1-d6d172d6dec5	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
73e14767-7d8e-4205-8ce1-d6d172d6dec5	5059e4c2-2ccd-4a8c-9696-dc77de8bd4dd	2025-12-03 16:12:57.935321+00	f
1c26151e-9056-4c5a-9cfb-48b430db8ee6	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.935321+00	f
1c26151e-9056-4c5a-9cfb-48b430db8ee6	191e5b1f-7183-43b2-93f8-c8c7dea23332	2025-12-03 16:12:57.935321+00	f
1c26151e-9056-4c5a-9cfb-48b430db8ee6	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
1c26151e-9056-4c5a-9cfb-48b430db8ee6	5059e4c2-2ccd-4a8c-9696-dc77de8bd4dd	2025-12-03 16:12:57.935321+00	f
b3793fb9-2ed5-489f-8865-eb423d66f860	ac00968d-5d85-461f-bdf4-43705cae56e5	2025-12-03 16:12:57.935321+00	f
b3793fb9-2ed5-489f-8865-eb423d66f860	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
efcc1554-e707-40f8-8f57-afaca4fd691a	ac00968d-5d85-461f-bdf4-43705cae56e5	2025-12-03 16:12:57.935321+00	f
efcc1554-e707-40f8-8f57-afaca4fd691a	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
ab0350ad-f992-45b3-b65b-18b6574e11a4	ac00968d-5d85-461f-bdf4-43705cae56e5	2025-12-03 16:12:57.935321+00	f
ab0350ad-f992-45b3-b65b-18b6574e11a4	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
6e276ba5-229b-428f-8599-fe252e4f0f68	ac00968d-5d85-461f-bdf4-43705cae56e5	2025-12-03 16:12:57.935321+00	f
6e276ba5-229b-428f-8599-fe252e4f0f68	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.935321+00	f
b3793fb9-2ed5-489f-8865-eb423d66f860	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
ab0350ad-f992-45b3-b65b-18b6574e11a4	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
c86c3980-0873-4677-a5b8-ec827a77f05e	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
a03df06c-8cca-4115-9ff1-4bc04e759ffc	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
31ef5cc3-e541-4750-b78b-99840dc7a372	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
a56cc3c5-2210-4945-8c48-85cd0b48d936	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
8506c62a-2f48-42b4-a02f-0b18b8e8478c	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
b4e6778c-cb14-4fe5-b3e8-99c85a19606c	a1000001-0001-0001-0001-000000000001	2025-12-03 16:12:57.962933+00	f
e6f6f1a6-dd4e-4a52-b0fc-bfa5796fae25	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
c2b8088d-da9f-4753-a245-eb2ba2346870	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
f797e554-2bbc-4097-9266-94a8cb8966c4	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
1db212a4-6d0a-4e77-95db-b8bd04593c87	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
d7f0cbbe-504f-4841-9884-6260c01ea200	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
ab71cdb8-4d56-490a-9ff8-34eee1595700	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
0ea7da60-6add-4cb7-a868-6bfdf384d6dd	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
efcc1554-e707-40f8-8f57-afaca4fd691a	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
6e276ba5-229b-428f-8599-fe252e4f0f68	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
40fd024f-d517-495c-9862-4f49a785d6be	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
f2e0bf91-99e7-4268-b8a9-6382e7ecc2ac	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
12677fd6-5f30-413a-9ab9-90bf3a784dad	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
9366c0e4-fc7a-49d6-ab29-d6396be9aafb	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
cfbd81d7-dbc7-4108-b71e-2d9e33dd1a7e	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
7faef612-5f93-4cb0-bf4d-b6ad67f22583	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
b32f320e-4fe5-4ba1-99db-78ad7b65cb66	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
55673471-b6ac-444c-bd01-1547b59b4fe2	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
3e35fcd2-81bc-47c0-ae0d-8b7aa2b8ab0b	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
407f48f4-54ca-48f2-8e39-edd7119625cf	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
82ef4acd-1690-4f21-9fa2-6b28dcff026c	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
faeb4daf-6206-4279-b3e2-89a6a2931a5a	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
c8da9dc6-aadc-4855-ae49-80c498cdd72e	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
d9b44ac8-ea5a-4729-8557-46690402ec9b	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
58651776-4bc2-4c9a-b7af-97f460d23659	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
6e4789ee-1a3f-4f32-bef7-0bc954ffdada	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
19c58a69-9d63-4df2-89b4-581c2cc37624	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
2d79cb42-bf89-43de-8cf4-2f4fa02b8e01	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
cfdd92ae-c43e-44f3-b225-034ef7c3a56d	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
9079cdd5-36ae-4292-abb2-2ab661fabad4	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
5cf379a0-cf2e-4b0f-b385-2e19c90f376a	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
38206df8-dc29-4d92-aded-5ca304fc2d8d	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
701bdd6b-18b3-47f7-845e-58c75c136ef8	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
895d262f-b940-4b97-aa7f-c046b764f415	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
4a73201d-7eba-41d6-b274-0a15beb48638	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
5735207d-df9f-4074-b266-20ca3084a038	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
2768a6a5-7abe-49b1-ba4e-1a7116ea68ac	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
bd7b8cfd-96a3-445a-904a-58ab4305a6e5	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
8cee05ee-944a-4571-9069-951ed4b7e20f	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
d012bc77-c558-4b14-9ed2-8974afe57325	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
5aef5f32-79d8-450c-948c-19afd7cefe32	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
3f31f108-2cc5-4d60-be0a-217dbf56c39b	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
1b06c275-c1c1-4dd3-8ebd-e5f3135ac66d	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
14ab0597-f946-4e7c-9f80-91ca128d5b55	a1000001-0001-0001-0001-000000000002	2025-12-03 16:12:57.964511+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	a1000001-0001-0001-0001-000000000003	2025-12-03 16:12:57.966016+00	f
d156b928-3c35-4360-acc9-f767fe425f18	a1000001-0001-0001-0001-000000000003	2025-12-03 16:12:57.966016+00	f
74e4cf91-e7c2-40e3-8747-cd3549c2d448	a1000001-0001-0001-0001-000000000003	2025-12-03 16:12:57.966016+00	f
6dcafe7c-0a32-4b43-8ff2-7123f927e97a	a1000001-0001-0001-0001-000000000003	2025-12-03 16:12:57.966016+00	f
251f1f13-c2a3-4d7e-a9f3-4539ba3bbbca	a1000001-0001-0001-0001-000000000003	2025-12-03 16:12:57.966016+00	f
3bdce920-b2f5-44a5-87b4-3983644ad7b3	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
7c3c2d01-f0e9-4737-a1cc-ecc9f3d40c0f	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
d42078b3-46f3-434b-940e-a56f25cf7202	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
83e5da70-b7db-4ada-8adc-e23f36a247c9	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
e5dd8193-aa6c-4018-9bd2-a56546d34865	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
87535f85-f45f-4050-9247-965c957a6d66	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
a3099b42-7053-4b64-982b-6f5487e63876	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
eb8ce802-47c1-44d5-8508-8bd1260c8fc8	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
d526930d-ead4-4de5-aebe-9998696695f6	a1000001-0001-0001-0001-000000000004	2025-12-03 16:12:57.967575+00	f
8352186e-f209-47eb-837b-cba001e1d9aa	a1000001-0001-0001-0001-000000000005	2025-12-03 16:12:57.968724+00	f
c81163f7-57df-45ec-a3f6-ef84b468fa56	a1000001-0001-0001-0001-000000000005	2025-12-03 16:12:57.968724+00	f
de476e34-0be1-468c-9872-59d9f0935fde	a1000001-0001-0001-0001-000000000005	2025-12-03 16:12:57.968724+00	f
4ac6e802-e80c-4af8-a9ae-08c9d9cc5dc1	a1000001-0001-0001-0001-000000000005	2025-12-03 16:12:57.968724+00	f
b43c1e7c-1f5a-4d21-987b-2944e3ba0237	a1000001-0001-0001-0001-000000000005	2025-12-03 16:12:57.968724+00	f
a579993e-409c-40e9-8af0-937584847be7	a1000001-0001-0001-0001-000000000005	2025-12-03 16:12:57.968724+00	f
2f515728-469d-43f2-8b3d-c3276560d602	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
c5fadaac-0fdc-4564-b1b6-93edb43fd636	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
f07d6bf6-5f7d-4cf8-abd1-e6e3cc760a6f	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
0513c887-bfe3-465c-b386-cd61e718fe71	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
8a1bae87-a9be-4875-9625-d312e7f7aa32	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
8bf5f3a5-f878-4cb3-a9f6-88ce08cdd33a	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
eb3565bc-87e7-45bc-be54-f9417c16fbe5	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
713c0a24-95dc-4ab2-9502-8ae3a1952173	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
98e3be75-fbf6-4886-ba61-7177b4b83639	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
def31724-8b34-4274-88f2-c25b73f1c96d	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
0c47b292-ce2f-4d02-9dc3-210f8271730e	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
3c246eb3-50a0-4d7e-82c0-a82e2a63d74a	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
c8ded284-da56-4dc0-a822-1f5907ac7f6c	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
9e71f57a-0ebe-49ed-96d7-c8efeba45bfa	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
b54d037d-e9c8-48d2-8990-4f783929013c	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
70fe606c-1027-47ab-b425-a2946e327f80	a1000001-0001-0001-0001-000000000006	2025-12-03 16:12:57.970182+00	f
bfa42ca2-1c34-4f1c-a634-c7c681ea774e	a1000001-0001-0001-0001-000000000007	2025-12-03 16:12:57.971443+00	f
1ac9f5f7-d25c-45a5-84e9-b665bbdd739f	a1000001-0001-0001-0001-000000000007	2025-12-03 16:12:57.971443+00	f
7696b4f4-51a3-4e2c-a08e-4c09b7943d15	a1000001-0001-0001-0001-000000000007	2025-12-03 16:12:57.971443+00	f
3bafd17f-9f9d-4fe7-8278-eb64e492f0c9	a1000001-0001-0001-0001-000000000007	2025-12-03 16:12:57.971443+00	f
bd12d1a8-59e1-4904-94c8-b991a39094d3	a1000001-0001-0001-0001-000000000007	2025-12-03 16:12:57.971443+00	f
0486b97d-6ace-41e9-a92a-c5c79aae8b3f	a1000001-0001-0001-0001-000000000007	2025-12-03 16:12:57.971443+00	f
c2b8088d-da9f-4753-a245-eb2ba2346870	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
ad46eeac-4a01-43f6-bb59-2e99c0c39824	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
3eab123f-400e-4b22-85a4-fd6637e635bd	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
11ea57e7-473c-4589-bd9e-2e431864f2e7	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
325eda19-591a-4c52-ae01-8f80beeab800	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
2e51a9f7-98b2-4916-89f8-374a508ca84e	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
49004e69-b792-4ff0-9bae-b2f1c9602c45	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
acd2cfd4-c72a-42ce-9662-7e71462c72fd	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
f838eb44-3813-4f3c-afb8-e3608d82aaab	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
e306f849-4655-4cf6-bcd6-57e1ff7e8255	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
278b6e09-5be4-4f37-b77b-ef1d92d59b40	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
09ddda57-be56-4fc9-9866-a9e98f61a366	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
a0267f7f-732e-4984-a0e4-ab6c87c37f5b	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
869e55f1-c6c0-4d02-8d26-0996c588c3b7	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
46bc5af0-dedb-4de4-8377-0347db2f9c09	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
556ca911-2a17-4bae-afe7-8d544b426285	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
d87301a5-c1f7-4fd0-8099-110be8681d7c	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
4ebdc38e-e320-45a8-8b25-6642a3459c74	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
249b4706-eda1-4a4b-85f1-cd6bfcac4088	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
19e9cf01-7db7-42e5-b6fb-eb6081d9a4fd	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
73e14767-7d8e-4205-8ce1-d6d172d6dec5	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
1c26151e-9056-4c5a-9cfb-48b430db8ee6	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
8b861617-e264-4542-a8db-01f7512cab7d	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
d156b928-3c35-4360-acc9-f767fe425f18	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
335f6c20-4702-41ae-babe-bf5e21527b75	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
6dcafe7c-0a32-4b43-8ff2-7123f927e97a	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
3bafd17f-9f9d-4fe7-8278-eb64e492f0c9	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
bd12d1a8-59e1-4904-94c8-b991a39094d3	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
0486b97d-6ace-41e9-a92a-c5c79aae8b3f	a1000001-0001-0001-0001-000000000010	2025-12-03 16:12:57.972879+00	f
b3793fb9-2ed5-489f-8865-eb423d66f860	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
efcc1554-e707-40f8-8f57-afaca4fd691a	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
ab0350ad-f992-45b3-b65b-18b6574e11a4	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
6e276ba5-229b-428f-8599-fe252e4f0f68	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
a03df06c-8cca-4115-9ff1-4bc04e759ffc	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
7faef612-5f93-4cb0-bf4d-b6ad67f22583	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
31ef5cc3-e541-4750-b78b-99840dc7a372	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
b32f320e-4fe5-4ba1-99db-78ad7b65cb66	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
a56cc3c5-2210-4945-8c48-85cd0b48d936	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
8506c62a-2f48-42b4-a02f-0b18b8e8478c	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
b4e6778c-cb14-4fe5-b3e8-99c85a19606c	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
55673471-b6ac-444c-bd01-1547b59b4fe2	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
a75e4bfb-5432-4530-93f0-05d8cdc621e7	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
f260134d-f772-496c-9378-4a47c80e70ab	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
785d571e-2de8-416c-87e1-9c8461cac4d9	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
3e35fcd2-81bc-47c0-ae0d-8b7aa2b8ab0b	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
407f48f4-54ca-48f2-8e39-edd7119625cf	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
faeb4daf-6206-4279-b3e2-89a6a2931a5a	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
58651776-4bc2-4c9a-b7af-97f460d23659	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
6e4789ee-1a3f-4f32-bef7-0bc954ffdada	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
2d79cb42-bf89-43de-8cf4-2f4fa02b8e01	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
4deba1b9-fb56-4ac9-87e6-0445fd84b169	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
d9d93e34-3673-4486-ba7e-8f1d0a088253	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
a421da2d-bd4d-4431-b571-020fe5c88305	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
2441331b-178e-439e-8ce7-b3d547a9683a	a1000001-0001-0001-0001-000000000011	2025-12-03 16:12:57.974456+00	f
e6f6f1a6-dd4e-4a52-b0fc-bfa5796fae25	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
4674b885-df4c-4f8a-878e-f513e1bf7d09	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
abd5e6eb-b56c-4f82-91c5-e649d1874bbf	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
b5f13561-2202-4b6e-aca7-554a2f841b86	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
ac45041d-31bb-4587-99e9-29e2402a1e07	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
82086ba5-11c7-47cd-83cd-d95e454515b7	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
5b1ba043-d0ff-4a73-8b39-056f60fc9314	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
a51e6c5a-b4f0-4a6b-8247-a696617be0f8	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
8fd3c6e9-7367-46ac-b730-932a54f89e86	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
2f515728-469d-43f2-8b3d-c3276560d602	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
c5fadaac-0fdc-4564-b1b6-93edb43fd636	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
f07d6bf6-5f7d-4cf8-abd1-e6e3cc760a6f	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
0513c887-bfe3-465c-b386-cd61e718fe71	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
8a1bae87-a9be-4875-9625-d312e7f7aa32	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
8bf5f3a5-f878-4cb3-a9f6-88ce08cdd33a	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
eb3565bc-87e7-45bc-be54-f9417c16fbe5	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
713c0a24-95dc-4ab2-9502-8ae3a1952173	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
98e3be75-fbf6-4886-ba61-7177b4b83639	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
def31724-8b34-4274-88f2-c25b73f1c96d	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
ba46cc7a-5a5d-429a-ba14-214401fa863c	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
b07aeb4a-3617-4a17-ab44-4c4f22e3adb7	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
39c785f9-f1d8-403e-9922-ff0ab39637d2	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
b661a9a5-3238-4da2-9834-80f23441a276	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
ada9beca-6052-4150-9d22-6a875582e3dc	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
fee6ae15-91bb-401d-be34-4a7256ed32cb	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
319dfba5-0cf0-4479-b0c5-16ae0218fef0	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
f4866e28-79b9-4d36-b612-567cccd07594	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
3bdce920-b2f5-44a5-87b4-3983644ad7b3	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
e80f84f1-0bbb-41fc-856c-ed4bb88fd16c	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
30f36124-a8a9-4c80-b81e-e8c303f8702c	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
0c47b292-ce2f-4d02-9dc3-210f8271730e	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
3c246eb3-50a0-4d7e-82c0-a82e2a63d74a	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
c8ded284-da56-4dc0-a822-1f5907ac7f6c	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
9e71f57a-0ebe-49ed-96d7-c8efeba45bfa	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
b54d037d-e9c8-48d2-8990-4f783929013c	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
70fe606c-1027-47ab-b425-a2946e327f80	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
a3099b42-7053-4b64-982b-6f5487e63876	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
74e4cf91-e7c2-40e3-8747-cd3549c2d448	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
251f1f13-c2a3-4d7e-a9f3-4539ba3bbbca	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
bfa42ca2-1c34-4f1c-a634-c7c681ea774e	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
1ac9f5f7-d25c-45a5-84e9-b665bbdd739f	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
7696b4f4-51a3-4e2c-a08e-4c09b7943d15	a1000001-0001-0001-0001-000000000012	2025-12-03 16:12:57.976044+00	f
f797e554-2bbc-4097-9266-94a8cb8966c4	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
1db212a4-6d0a-4e77-95db-b8bd04593c87	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
d7f0cbbe-504f-4841-9884-6260c01ea200	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
a03df06c-8cca-4115-9ff1-4bc04e759ffc	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
7faef612-5f93-4cb0-bf4d-b6ad67f22583	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
3e35fcd2-81bc-47c0-ae0d-8b7aa2b8ab0b	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
407f48f4-54ca-48f2-8e39-edd7119625cf	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
82ef4acd-1690-4f21-9fa2-6b28dcff026c	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
faeb4daf-6206-4279-b3e2-89a6a2931a5a	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
c8da9dc6-aadc-4855-ae49-80c498cdd72e	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
d9b44ac8-ea5a-4729-8557-46690402ec9b	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
8352186e-f209-47eb-837b-cba001e1d9aa	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
7c3c2d01-f0e9-4737-a1cc-ecc9f3d40c0f	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
d746de0a-fbdb-40ba-b604-31e848b3b2c5	a1000001-0001-0001-0001-000000000020	2025-12-03 16:12:57.977671+00	f
ab71cdb8-4d56-490a-9ff8-34eee1595700	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
0ea7da60-6add-4cb7-a868-6bfdf384d6dd	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
31ef5cc3-e541-4750-b78b-99840dc7a372	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
b32f320e-4fe5-4ba1-99db-78ad7b65cb66	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
58651776-4bc2-4c9a-b7af-97f460d23659	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
6e4789ee-1a3f-4f32-bef7-0bc954ffdada	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
19c58a69-9d63-4df2-89b4-581c2cc37624	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
2d79cb42-bf89-43de-8cf4-2f4fa02b8e01	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
cfdd92ae-c43e-44f3-b225-034ef7c3a56d	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
9079cdd5-36ae-4292-abb2-2ab661fabad4	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
c81163f7-57df-45ec-a3f6-ef84b468fa56	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
d42078b3-46f3-434b-940e-a56f25cf7202	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
730f3739-4109-49b0-a75f-b14482acc564	a1000001-0001-0001-0001-000000000021	2025-12-03 16:12:57.97918+00	f
40fd024f-d517-495c-9862-4f49a785d6be	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
325eda19-591a-4c52-ae01-8f80beeab800	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
f2e0bf91-99e7-4268-b8a9-6382e7ecc2ac	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
12677fd6-5f30-413a-9ab9-90bf3a784dad	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
c86c3980-0873-4677-a5b8-ec827a77f05e	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
9366c0e4-fc7a-49d6-ab29-d6396be9aafb	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
cfbd81d7-dbc7-4108-b71e-2d9e33dd1a7e	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
a56cc3c5-2210-4945-8c48-85cd0b48d936	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
8506c62a-2f48-42b4-a02f-0b18b8e8478c	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
b4e6778c-cb14-4fe5-b3e8-99c85a19606c	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
5cf379a0-cf2e-4b0f-b385-2e19c90f376a	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
de476e34-0be1-468c-9872-59d9f0935fde	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
83e5da70-b7db-4ada-8adc-e23f36a247c9	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
4ac6e802-e80c-4af8-a9ae-08c9d9cc5dc1	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
e5dd8193-aa6c-4018-9bd2-a56546d34865	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
38206df8-dc29-4d92-aded-5ca304fc2d8d	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
701bdd6b-18b3-47f7-845e-58c75c136ef8	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
895d262f-b940-4b97-aa7f-c046b764f415	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
4a73201d-7eba-41d6-b274-0a15beb48638	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
5735207d-df9f-4074-b266-20ca3084a038	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
2768a6a5-7abe-49b1-ba4e-1a7116ea68ac	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
bd7b8cfd-96a3-445a-904a-58ab4305a6e5	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
8cee05ee-944a-4571-9069-951ed4b7e20f	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
b43c1e7c-1f5a-4d21-987b-2944e3ba0237	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
87535f85-f45f-4050-9247-965c957a6d66	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
14ab0597-f946-4e7c-9f80-91ca128d5b55	a1000001-0001-0001-0001-000000000022	2025-12-03 16:12:57.980377+00	f
b3793fb9-2ed5-489f-8865-eb423d66f860	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
efcc1554-e707-40f8-8f57-afaca4fd691a	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
ab0350ad-f992-45b3-b65b-18b6574e11a4	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
6e276ba5-229b-428f-8599-fe252e4f0f68	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
d012bc77-c558-4b14-9ed2-8974afe57325	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
5aef5f32-79d8-450c-948c-19afd7cefe32	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
eb8ce802-47c1-44d5-8508-8bd1260c8fc8	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
3f31f108-2cc5-4d60-be0a-217dbf56c39b	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
1b06c275-c1c1-4dd3-8ebd-e5f3135ac66d	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
d526930d-ead4-4de5-aebe-9998696695f6	a1000001-0001-0001-0001-000000000023	2025-12-03 16:12:57.981997+00	f
4489ea44-7c53-4c8b-b113-d54d48924265	a1000001-0001-0001-0001-000000000024	2025-12-03 16:12:57.983225+00	f
467dc923-d8f9-4924-9b38-ab97c41df1fd	a1000001-0001-0001-0001-000000000024	2025-12-03 16:12:57.983225+00	f
e8d3ea2d-c23e-4d91-9f5c-d18427b252c0	a1000001-0001-0001-0001-000000000024	2025-12-03 16:12:57.983225+00	f
a2dadd92-4a67-4db1-96bf-9cf8da4e057f	a1000001-0001-0001-0001-000000000024	2025-12-03 16:12:57.983225+00	f
a37ca4f4-a2a1-42d2-8d4e-4967e26707e8	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.98487+00	f
753cfe5d-5875-4b98-b92f-72e084cc7af5	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.98487+00	f
114b86e5-5579-406b-bf50-617dcb3533c5	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-03 16:12:57.98487+00	f
a37ca4f4-a2a1-42d2-8d4e-4967e26707e8	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.98602+00	f
753cfe5d-5875-4b98-b92f-72e084cc7af5	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.98602+00	f
114b86e5-5579-406b-bf50-617dcb3533c5	f5308ac8-cf95-4d73-9d44-f7e85fce6425	2025-12-03 16:12:57.98602+00	f
a37ca4f4-a2a1-42d2-8d4e-4967e26707e8	e9783be0-7610-4441-ad36-ba24e980fcbd	2025-12-03 16:12:57.987769+00	f
753cfe5d-5875-4b98-b92f-72e084cc7af5	e9783be0-7610-4441-ad36-ba24e980fcbd	2025-12-03 16:12:57.987769+00	f
114b86e5-5579-406b-bf50-617dcb3533c5	e9783be0-7610-4441-ad36-ba24e980fcbd	2025-12-03 16:12:57.987769+00	f
822c9e96-5fbf-4a1f-bc34-b13189b9d677	e9783be0-7610-4441-ad36-ba24e980fcbd	2025-12-03 16:12:57.987769+00	f
822c9e96-5fbf-4a1f-bc34-b13189b9d677	1feaa67a-0113-4930-86e0-eaaca1d070e1	2025-12-03 16:12:57.9897+00	f
822c9e96-5fbf-4a1f-bc34-b13189b9d677	191e5b1f-7183-43b2-93f8-c8c7dea23332	2025-12-03 16:12:57.991225+00	f
822c9e96-5fbf-4a1f-bc34-b13189b9d677	fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	2025-12-03 16:12:57.992713+00	f
\.


--
-- Data for Name: master_zmanim_registry; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.master_zmanim_registry (id, zman_key, canonical_hebrew_name, canonical_english_name, transliteration, description, halachic_notes, halachic_source, time_category, default_formula_dsl, is_core, is_hidden, created_by, updated_by, created_at, updated_at) FROM stdin;
e6f6f1a6-dd4e-4a52-b0fc-bfa5796fae25	alos_16_1	עלות השחר 16.1°	Dawn (16.1°)	Alos 16.1	Dawn calculated at 16.1° solar depression	\N	\N	dawn	solar(16.1, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
4674b885-df4c-4f8a-878e-f513e1bf7d09	alos_18	עלות השחר 18°	Dawn (18°)	Alos 18	Dawn at astronomical twilight (18°)	\N	\N	dawn	solar(18, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
abd5e6eb-b56c-4f82-91c5-e649d1874bbf	alos_19_8	עלות השחר 19.8°	Dawn (19.8°)	Alos 19.8	Dawn at 19.8° - stricter opinion	\N	\N	dawn	solar(19.8, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
b5f13561-2202-4b6e-aca7-554a2f841b86	alos_26	עלות השחר 26°	Dawn (26°)	Alos 26	Dawn at 26° - very stringent	\N	\N	dawn	solar(26, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
c2b8088d-da9f-4753-a245-eb2ba2346870	alos_72	עלות השחר 72 דקות	Dawn (72 minutes)	Alos 72	Dawn 72 fixed minutes before sunrise	\N	\N	dawn	sunrise - 72min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
ad46eeac-4a01-43f6-bb59-2e99c0c39824	alos_90	עלות השחר 90 דקות	Dawn (90 minutes)	Alos 90	Dawn 90 fixed minutes before sunrise	\N	\N	dawn	sunrise - 90min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
3eab123f-400e-4b22-85a4-fd6637e635bd	alos_96	עלות השחר 96 דקות	Dawn (96 minutes)	Alos 96	Dawn 96 fixed minutes before sunrise	\N	\N	dawn	sunrise - 96min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
11ea57e7-473c-4589-bd9e-2e431864f2e7	alos_120	עלות השחר 120 דקות	Dawn (120 minutes)	Alos 120	Dawn 120 fixed minutes before sunrise (2 hours)	\N	\N	dawn	sunrise - 120min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
ac45041d-31bb-4587-99e9-29e2402a1e07	misheyakir_10_2	משיכיר 10.2°	Misheyakir (10.2°)	Misheyakir 10.2	Misheyakir at 10.2° solar depression	\N	\N	sunrise	solar(10.2, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
82086ba5-11c7-47cd-83cd-d95e454515b7	misheyakir_11	משיכיר 11°	Misheyakir (11°)	Misheyakir 11	Misheyakir at 11° solar depression	\N	\N	sunrise	solar(11, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
5b1ba043-d0ff-4a73-8b39-056f60fc9314	misheyakir_7_65	משיכיר 7.65°	Misheyakir (7.65°)	Misheyakir 7.65	Misheyakir at 7.65° - lenient opinion	\N	\N	sunrise	solar(7.65, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
1eef41ea-2d2e-495d-8bd3-6aa05f44b6d9	visible_sunrise	הנץ הנראה	Visible Sunrise	Hanetz Hanireh	Actual visible sunrise accounting for refraction	\N	\N	sunrise	visible_sunrise	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
f797e554-2bbc-4097-9266-94a8cb8966c4	sof_zman_shma_mga_90	סוף זמן ק"ש מג"א 90	Latest Shema (MGA 90)	Sof Zman Shma MGA 90	Latest time for Shema (MGA from 90min dawn)	\N	\N	morning	proportional_hours(3, mga_90)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
1db212a4-6d0a-4e77-95db-b8bd04593c87	sof_zman_shma_mga_120	סוף זמן ק"ש מג"א 120	Latest Shema (MGA 120)	Sof Zman Shma MGA 120	Latest time for Shema (MGA from 120min dawn)	\N	\N	morning	proportional_hours(3, mga_120)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
d7f0cbbe-504f-4841-9884-6260c01ea200	sof_zman_shma_16_1	סוף זמן ק"ש 16.1°	Latest Shema (16.1°)	Sof Zman Shma 16.1	Latest Shema based on 16.1° alos	\N	\N	morning	proportional_hours(3, alos_16_1)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
ab71cdb8-4d56-490a-9ff8-34eee1595700	sof_zman_tfila_mga_90	סוף זמן תפילה מג"א 90	Latest Shacharit (MGA 90)	Sof Zman Tefilla MGA 90	Latest Shacharit (MGA from 90min dawn)	\N	\N	morning	proportional_hours(4, mga_90)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
0ea7da60-6add-4cb7-a868-6bfdf384d6dd	sof_zman_tfila_mga_120	סוף זמן תפילה מג"א 120	Latest Shacharit (MGA 120)	Sof Zman Tefilla MGA 120	Latest Shacharit (MGA from 120min dawn)	\N	\N	morning	proportional_hours(4, mga_120)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
b3793fb9-2ed5-489f-8865-eb423d66f860	sof_zman_achilas_chametz_gra	סוף זמן אכילת חמץ גר"א	Latest Eating Chametz (GRA)	Sof Achilat Chametz GRA	Latest time to eat chametz on Erev Pesach (GRA)	\N	\N	morning	proportional_hours(4, gra)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
efcc1554-e707-40f8-8f57-afaca4fd691a	sof_zman_achilas_chametz_mga	סוף זמן אכילת חמץ מג"א	Latest Eating Chametz (MGA)	Sof Achilat Chametz MGA	Latest time to eat chametz on Erev Pesach (MGA)	\N	\N	morning	proportional_hours(4, mga)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
ab0350ad-f992-45b3-b65b-18b6574e11a4	sof_zman_biur_chametz_gra	סוף זמן ביעור חמץ גר"א	Latest Burning Chametz (GRA)	Sof Biur Chametz GRA	Latest time to burn chametz on Erev Pesach (GRA)	\N	\N	morning	proportional_hours(5, gra)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
6e276ba5-229b-428f-8599-fe252e4f0f68	sof_zman_biur_chametz_mga	סוף זמן ביעור חמץ מג"א	Latest Burning Chametz (MGA)	Sof Biur Chametz MGA	Latest time to burn chametz on Erev Pesach (MGA)	\N	\N	morning	proportional_hours(5, mga)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
40fd024f-d517-495c-9862-4f49a785d6be	mincha_gedola_16_1	מנחה גדולה 16.1°	Earliest Mincha (16.1°)	Mincha Gedola 16.1	Earliest Mincha based on 16.1° calculation	\N	\N	midday	proportional_hours(6.5, alos_16_1)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
325eda19-591a-4c52-ae01-8f80beeab800	mincha_gedola_30	מנחה גדולה 30 דקות	Earliest Mincha (30 min)	Mincha Gedola 30	Earliest Mincha - exactly 30 minutes after chatzos	\N	\N	midday	solar_noon + 30min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
f2e0bf91-99e7-4268-b8a9-6382e7ecc2ac	mincha_ketana_16_1	מנחה קטנה 16.1°	Mincha Ketana (16.1°)	Mincha Ketana 16.1	Mincha Ketana based on 16.1° calculation	\N	\N	afternoon	proportional_hours(9.5, alos_16_1)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
12677fd6-5f30-413a-9ab9-90bf3a784dad	mincha_ketana_72	מנחה קטנה 72 דקות	Mincha Ketana (72 min)	Mincha Ketana 72	Mincha Ketana (MGA 72 minute day)	\N	\N	afternoon	proportional_hours(9.5, mga)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
c86c3980-0873-4677-a5b8-ec827a77f05e	samuch_lmincha_ketana	סמוך למנחה קטנה	Samuch L'Mincha Ketana	Samuch LMincha	Half hour before Mincha Ketana	\N	\N	afternoon	proportional_hours(9, gra)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
9366c0e4-fc7a-49d6-ab29-d6396be9aafb	plag_hamincha_16_1	פלג המנחה 16.1°	Plag HaMincha (16.1°)	Plag Hamincha 16.1	Plag HaMincha based on 16.1° calculation	\N	\N	afternoon	proportional_hours(10.75, alos_16_1)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
cfbd81d7-dbc7-4108-b71e-2d9e33dd1a7e	plag_hamincha_72	פלג המנחה 72 דקות	Plag HaMincha (72 min)	Plag Hamincha 72	Plag HaMincha (MGA 72 minute day)	\N	\N	afternoon	proportional_hours(10.75, mga)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
74fd91dc-963f-47f1-b4aa-595acfc7fb3c	candle_lighting_15	הדלקת נרות 15 דקות	Candle Lighting (15 min)	Hadlakas Neiros 15	Candle lighting 15 minutes before sunset	\N	\N	sunset	sunset - 15min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
2e51a9f7-98b2-4916-89f8-374a508ca84e	candle_lighting_18	הדלקת נרות 18 דקות	Candle Lighting (18 min)	Hadlakas Neiros 18	Candle lighting 18 minutes before sunset (standard)	\N	\N	sunset	sunset - 18min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
d08c0f98-e36c-4ac2-9bb2-b9fcfb82698f	candle_lighting_20	הדלקת נרות 20 דקות	Candle Lighting (20 min)	Hadlakas Neiros 20	Candle lighting 20 minutes before sunset (Jerusalem)	\N	\N	sunset	sunset - 20min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
49004e69-b792-4ff0-9bae-b2f1c9602c45	candle_lighting_22	הדלקת נרות 22 דקות	Candle Lighting (22 min)	Hadlakas Neiros 22	Candle lighting 22 minutes before sunset	\N	\N	sunset	sunset - 22min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
acd2cfd4-c72a-42ce-9662-7e71462c72fd	candle_lighting_30	הדלקת נרות 30 דקות	Candle Lighting (30 min)	Hadlakas Neiros 30	Candle lighting 30 minutes before sunset	\N	\N	sunset	sunset - 30min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
f838eb44-3813-4f3c-afb8-e3608d82aaab	candle_lighting_40	הדלקת נרות 40 דקות	Candle Lighting (40 min)	Hadlakas Neiros 40	Candle lighting 40 minutes before sunset (Jerusalem strict)	\N	\N	sunset	sunset - 40min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
12867ef6-594d-4ecd-86e3-2d9033dbbe83	visible_sunset	שקיעה נראית	Visible Sunset	Shkiah Nireis	Actual visible sunset	\N	\N	sunset	visible_sunset	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
37613cc9-9e05-4562-b453-40e91002f8a8	shkia_amitis	שקיעה אמיתית	True Sunset	Shkia Amitis	True sunset accounting for elevation	\N	\N	sunset	sunset	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
a51e6c5a-b4f0-4a6b-8247-a696617be0f8	bein_hashmashos_start	תחילת בין השמשות	Bein Hashmashos Start	Bein Hashmashos	Start of twilight period	\N	\N	sunset	sunset	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
8fd3c6e9-7367-46ac-b730-932a54f89e86	tzais_3_stars	צאת 3 כוכבים	Tzais 3 Stars	Tzais 3 Kochavim	Three stars visible - standard nightfall	\N	\N	nightfall	solar(8.5, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
2f515728-469d-43f2-8b3d-c3276560d602	tzais_4_37	צאת 4.37°	Tzais (4.37°)	Tzais 4.37	Nightfall at 4.37° - lenient	\N	\N	nightfall	solar(4.37, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
c5fadaac-0fdc-4564-b1b6-93edb43fd636	tzais_4_61	צאת 4.61°	Tzais (4.61°)	Tzais 4.61	Nightfall at 4.61°	\N	\N	nightfall	solar(4.61, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
f07d6bf6-5f7d-4cf8-abd1-e6e3cc760a6f	tzais_4_8	צאת 4.8°	Tzais (4.8°)	Tzais 4.8	Nightfall at 4.8°	\N	\N	nightfall	solar(4.8, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
0513c887-bfe3-465c-b386-cd61e718fe71	tzais_5_95	צאת 5.95°	Tzais (5.95°)	Tzais 5.95	Nightfall at 5.95°	\N	\N	nightfall	solar(5.95, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
8a1bae87-a9be-4875-9625-d312e7f7aa32	tzais_6	צאת 6°	Tzais (6°)	Tzais 6	Civil twilight end (6°)	\N	\N	nightfall	solar(6, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
8bf5f3a5-f878-4cb3-a9f6-88ce08cdd33a	tzais_7_083	צאת 7.083°	Tzais (7.083°)	Tzais 7.083	Nightfall at 7.083° (Rabbeinu Tam geometric)	\N	\N	nightfall	solar(7.083, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
eb3565bc-87e7-45bc-be54-f9417c16fbe5	tzais_7_67	צאת 7.67°	Tzais (7.67°)	Tzais 7.67	Nightfall at 7.67°	\N	\N	nightfall	solar(7.67, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
713c0a24-95dc-4ab2-9502-8ae3a1952173	tzais_8_5	צאת 8.5°	Tzais (8.5°)	Tzais 8.5	Standard nightfall at 8.5°	\N	\N	nightfall	solar(8.5, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
98e3be75-fbf6-4886-ba61-7177b4b83639	tzais_9_3	צאת 9.3°	Tzais (9.3°)	Tzais 9.3	Nightfall at 9.3°	\N	\N	nightfall	solar(9.3, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
def31724-8b34-4274-88f2-c25b73f1c96d	tzais_9_75	צאת 9.75°	Tzais (9.75°)	Tzais 9.75	Nightfall at 9.75°	\N	\N	nightfall	solar(9.75, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
ba46cc7a-5a5d-429a-ba14-214401fa863c	tzais_13_5	צאת 13.5°	Tzais (13.5°)	Tzais 13.5	Stringent nightfall at 13.5°	\N	\N	nightfall	solar(13.5, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
b07aeb4a-3617-4a17-ab44-4c4f22e3adb7	tzais_18	צאת 18°	Tzais (18°)	Tzais 18	Astronomical nightfall (18°)	\N	\N	nightfall	solar(18, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
39c785f9-f1d8-403e-9922-ff0ab39637d2	tzais_19_8	צאת 19.8°	Tzais (19.8°)	Tzais 19.8	Very stringent nightfall at 19.8°	\N	\N	nightfall	solar(19.8, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
b661a9a5-3238-4da2-9834-80f23441a276	tzais_26	צאת 26°	Tzais (26°)	Tzais 26	Extremely stringent nightfall	\N	\N	nightfall	solar(26, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
e306f849-4655-4cf6-bcd6-57e1ff7e8255	tzais_13_24	צאת 13.24°	Tzais (13.24 min)	Tzais 13.24	Fixed 13.24 minutes after sunset	\N	\N	nightfall	sunset + 13min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
278b6e09-5be4-4f37-b77b-ef1d92d59b40	tzais_20	צאת 20 דקות	Tzais (20 min)	Tzais 20	Fixed 20 minutes after sunset	\N	\N	nightfall	sunset + 20min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
09ddda57-be56-4fc9-9866-a9e98f61a366	tzais_42	צאת 42 דקות	Tzais (42 min)	Tzais 42	Fixed 42 minutes after sunset	\N	\N	nightfall	sunset + 42min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
a0267f7f-732e-4984-a0e4-ab6c87c37f5b	tzais_50	צאת 50 דקות	Tzais (50 min)	Tzais 50	Fixed 50 minutes after sunset	\N	\N	nightfall	sunset + 50min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
869e55f1-c6c0-4d02-8d26-0996c588c3b7	tzais_60	צאת 60 דקות	Tzais (60 min)	Tzais 60	Fixed 60 minutes after sunset	\N	\N	nightfall	sunset + 60min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
46bc5af0-dedb-4de4-8377-0347db2f9c09	tzais_90	צאת 90 דקות	Tzais (90 min)	Tzais 90	Fixed 90 minutes after sunset	\N	\N	nightfall	sunset + 90min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
556ca911-2a17-4bae-afe7-8d544b426285	tzais_96	צאת 96 דקות	Tzais (96 min)	Tzais 96	Fixed 96 minutes after sunset	\N	\N	nightfall	sunset + 96min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
d87301a5-c1f7-4fd0-8099-110be8681d7c	tzais_120	צאת 120 דקות	Tzais (120 min)	Tzais 120	Fixed 120 minutes after sunset	\N	\N	nightfall	sunset + 120min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
c92d8740-af5c-4298-a65d-ce5f64d76551	sunset	שקיעה	Sunset	Shkiah	Geometric/sea-level sunset	\N	\N	sunset	sunset	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
4ebdc38e-e320-45a8-8b25-6642a3459c74	shabbos_ends_42	מוצאי שבת 42 דקות	Shabbos Ends (42 min)	Motzei Shabbos 42	End of Shabbos - 42 minutes	\N	\N	nightfall	sunset + 42min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
249b4706-eda1-4a4b-85f1-cd6bfcac4088	shabbos_ends_50	מוצאי שבת 50 דקות	Shabbos Ends (50 min)	Motzei Shabbos 50	End of Shabbos - 50 minutes	\N	\N	nightfall	sunset + 50min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
8f6daeb7-b692-4e7d-88e7-e8b4724b81a6	shabbos_ends_72	מוצאי שבת 72 דקות	Shabbos Ends (72 min)	Motzei Shabbos 72	End of Shabbos - Rabbeinu Tam	\N	\N	nightfall	sunset + 72min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
19e9cf01-7db7-42e5-b6fb-eb6081d9a4fd	fast_ends_20	סוף הצום 20 דקות	Fast Ends (20 min)	Sof Hatzom 20	Fast ends 20 minutes after sunset	\N	\N	nightfall	sunset + 20min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
73e14767-7d8e-4205-8ce1-d6d172d6dec5	fast_ends_42	סוף הצום 42 דקות	Fast Ends (42 min)	Sof Hatzom 42	Fast ends 42 minutes after sunset	\N	\N	nightfall	sunset + 42min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
1c26151e-9056-4c5a-9cfb-48b430db8ee6	fast_ends_50	סוף הצום 50 דקות	Fast Ends (50 min)	Sof Hatzom 50	Fast ends 50 minutes after sunset	\N	\N	nightfall	sunset + 50min	f	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.932416+00
ada9beca-6052-4150-9d22-6a875582e3dc	alos_hashachar	עלות השחר	Dawn (Alos Hashachar)	Alos Hashachar	Dawn - when the first light appears on the eastern horizon (16.1° below horizon)	\N	\N	dawn	solar(16.1, before_sunrise)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
fee6ae15-91bb-401d-be34-4a7256ed32cb	misheyakir	משיכיר	Misheyakir	Misheyakir	Earliest time to put on tallit and tefillin	\N	\N	sunrise	solar(11.5, before_sunrise)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
10d89e97-e29b-4a0c-8775-04ccd6c15ba3	sunrise	הנץ החמה	Sunrise	Netz Hachama	Geometric/sea-level sunrise	\N	\N	sunrise	sunrise	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
a03df06c-8cca-4115-9ff1-4bc04e759ffc	sof_zman_shma_gra	סוף זמן ק"ש גר"א	Latest Shema (GRA)	Sof Zman Shma GRA	Latest time for Shema - 3 proportional hours (GRA)	\N	\N	morning	proportional_hours(3, gra)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
7faef612-5f93-4cb0-bf4d-b6ad67f22583	sof_zman_shma_mga	סוף זמן ק"ש מג"א	Latest Shema (MGA)	Sof Zman Shma MGA	Latest time for Shema - 3 proportional hours (MGA from 72min dawn)	\N	\N	morning	proportional_hours(3, mga)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
31ef5cc3-e541-4750-b78b-99840dc7a372	sof_zman_tfila_gra	סוף זמן תפילה גר"א	Latest Shacharit (GRA)	Sof Zman Tefilla GRA	Latest time for Shacharit - 4 proportional hours (GRA)	\N	\N	morning	proportional_hours(4, gra)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
b32f320e-4fe5-4ba1-99db-78ad7b65cb66	sof_zman_tfila_mga	סוף זמן תפילה מג"א	Latest Shacharit (MGA)	Sof Zman Tefilla MGA	Latest time for Shacharit - 4 proportional hours (MGA)	\N	\N	morning	proportional_hours(4, mga)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
5c1806a7-5c5f-4231-8ea6-f2821a3f74ff	chatzos	חצות היום	Midday (Chatzos)	Chatzos	Solar noon - midpoint between sunrise and sunset	\N	\N	midday	solar_noon	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
a56cc3c5-2210-4945-8c48-85cd0b48d936	mincha_gedola	מנחה גדולה	Earliest Mincha (GRA)	Mincha Gedola	Earliest time for Mincha - 6.5 proportional hours (half shaah zmanis after chatzos)	\N	\N	midday	proportional_hours(6.5, gra)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
8506c62a-2f48-42b4-a02f-0b18b8e8478c	mincha_ketana	מנחה קטנה	Mincha Ketana	Mincha Ketana	Mincha Ketana - 9.5 proportional hours	\N	\N	afternoon	proportional_hours(9.5, gra)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
b4e6778c-cb14-4fe5-b3e8-99c85a19606c	plag_hamincha	פלג המנחה	Plag HaMincha	Plag Hamincha	Plag HaMincha - 10.75 proportional hours (1.25 hours before sunset)	\N	\N	afternoon	proportional_hours(10.75, gra)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
8b861617-e264-4542-a8db-01f7512cab7d	candle_lighting	הדלקת נרות	Candle Lighting	Hadlakas Neiros	Shabbat candle lighting - 18 minutes before sunset	\N	\N	sunset	sunset - 18min	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
319dfba5-0cf0-4479-b0c5-16ae0218fef0	tzais	צאת הכוכבים	Nightfall (Tzais)	Tzais Hakochavim	Nightfall - when 3 medium stars are visible (8.5°)	\N	\N	nightfall	solar(8.5, after_sunset)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
d156b928-3c35-4360-acc9-f767fe425f18	tzais_72	צאת ר"ת 72 דקות	Tzais Rabbeinu Tam (72 min)	Tzais RT 72	Rabbeinu Tam - 72 fixed minutes after sunset	\N	\N	nightfall	sunset + 72min	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
888f7113-4a77-44a1-aa1d-22cb297297a5	shabbos_ends	מוצאי שבת	Shabbos Ends	Motzei Shabbos	End of Shabbos - standard tzais	\N	\N	nightfall	solar(8.5, after_sunset)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
5873dd70-0a42-44e7-aba4-d0eeec0457a0	fast_ends	סוף הצום	Fast Ends	Sof Hatzom	End of fast day	\N	\N	nightfall	solar(8.5, after_sunset)	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
6af15b21-1fd8-4958-89d0-8e8df94c059f	chatzos_layla	חצות לילה	Midnight (Chatzos Layla)	Chatzos Layla	Halachic midnight - 12 hours after solar noon	\N	\N	midnight	solar_noon + 12hr	t	f	\N	\N	2025-12-03 16:12:57.932416+00	2025-12-03 16:12:57.940949+00
335f6c20-4702-41ae-babe-bf5e21527b75	alos_60	עלות השחר 60 דקות	Dawn (60 minutes)	Alos 60	Dawn 60 fixed minutes before sunrise	\N	\N	dawn	sunrise - 60min	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
f4866e28-79b9-4d36-b612-567cccd07594	alos_19	עלות השחר 19°	Dawn (19°)	Alos 19	Dawn at 19° solar depression	\N	\N	dawn	solar(19, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
55673471-b6ac-444c-bd01-1547b59b4fe2	alos_72_zmanis	עלות השחר 72 דקות זמניות	Dawn (72 Zmaniyos)	Alos 72 Zmanis	Dawn 72 proportional minutes before sunrise	\N	\N	dawn	proportional_minutes(72, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
a75e4bfb-5432-4530-93f0-05d8cdc621e7	alos_90_zmanis	עלות השחר 90 דקות זמניות	Dawn (90 Zmaniyos)	Alos 90 Zmanis	Dawn 90 proportional minutes before sunrise	\N	\N	dawn	proportional_minutes(90, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
f260134d-f772-496c-9378-4a47c80e70ab	alos_96_zmanis	עלות השחר 96 דקות זמניות	Dawn (96 Zmaniyos)	Alos 96 Zmanis	Dawn 96 proportional minutes before sunrise	\N	\N	dawn	proportional_minutes(96, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
785d571e-2de8-416c-87e1-9c8461cac4d9	alos_120_zmanis	עלות השחר 120 דקות זמניות	Dawn (120 Zmaniyos)	Alos 120 Zmanis	Dawn 120 proportional minutes before sunrise	\N	\N	dawn	proportional_minutes(120, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
3bdce920-b2f5-44a5-87b4-3983644ad7b3	alos_baal_hatanya	עלות השחר בעל התניא	Dawn (Baal HaTanya)	Alos Baal HaTanya	Dawn according to Baal HaTanya (16.9° solar depression)	\N	\N	dawn	solar(16.9, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.942915+00	2025-12-03 16:12:57.942915+00
e80f84f1-0bbb-41fc-856c-ed4bb88fd16c	misheyakir_9_5	משיכיר 9.5°	Misheyakir (9.5°)	Misheyakir 9.5	Misheyakir at 9.5° solar depression - lenient opinion	\N	\N	sunrise	solar(9.5, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.944479+00	2025-12-03 16:12:57.944479+00
30f36124-a8a9-4c80-b81e-e8c303f8702c	misheyakir_11_5	משיכיר 11.5°	Misheyakir (11.5°)	Misheyakir 11.5	Misheyakir at 11.5° solar depression - standard opinion	\N	\N	sunrise	solar(11.5, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.944479+00	2025-12-03 16:12:57.944479+00
3e35fcd2-81bc-47c0-ae0d-8b7aa2b8ab0b	sof_zman_shma_mga_72_zmanis	סוף זמן ק"ש מג"א 72 זמניות	Latest Shema (MGA 72 Zmaniyos)	Sof Zman Shma MGA 72Z	Latest Shema MGA based on 72 proportional minute day	\N	\N	morning	proportional_hours(3, mga_72_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
407f48f4-54ca-48f2-8e39-edd7119625cf	sof_zman_shma_mga_90_zmanis	סוף זמן ק"ש מג"א 90 זמניות	Latest Shema (MGA 90 Zmaniyos)	Sof Zman Shma MGA 90Z	Latest Shema MGA based on 90 proportional minute day	\N	\N	morning	proportional_hours(3, mga_90_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
82ef4acd-1690-4f21-9fa2-6b28dcff026c	sof_zman_shma_mga_96	סוף זמן ק"ש מג"א 96	Latest Shema (MGA 96)	Sof Zman Shma MGA 96	Latest Shema MGA based on 96 minute day	\N	\N	morning	proportional_hours(3, mga_96)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
faeb4daf-6206-4279-b3e2-89a6a2931a5a	sof_zman_shma_mga_96_zmanis	סוף זמן ק"ש מג"א 96 זמניות	Latest Shema (MGA 96 Zmaniyos)	Sof Zman Shma MGA 96Z	Latest Shema MGA based on 96 proportional minute day	\N	\N	morning	proportional_hours(3, mga_96_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
c8da9dc6-aadc-4855-ae49-80c498cdd72e	sof_zman_shma_mga_18	סוף זמן ק"ש מג"א 18°	Latest Shema (MGA 18°)	Sof Zman Shma MGA 18	Latest Shema MGA based on 18° alos/tzais	\N	\N	morning	proportional_hours(3, mga_18)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
d9b44ac8-ea5a-4729-8557-46690402ec9b	sof_zman_shma_mga_19_8	סוף זמן ק"ש מג"א 19.8°	Latest Shema (MGA 19.8°)	Sof Zman Shma MGA 19.8	Latest Shema MGA based on 19.8° alos/tzais	\N	\N	morning	proportional_hours(3, mga_19_8)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
8352186e-f209-47eb-837b-cba001e1d9aa	sof_zman_shma_ateret_torah	סוף זמן ק"ש עטרת תורה	Latest Shema (Ateret Torah)	Sof Zman Shma AT	Latest Shema per Chacham Yosef Harari-Raful	\N	\N	morning	proportional_hours(3, ateret_torah)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
7c3c2d01-f0e9-4737-a1cc-ecc9f3d40c0f	sof_zman_shma_baal_hatanya	סוף זמן ק"ש בעל התניא	Latest Shema (Baal HaTanya)	Sof Zman Shma BH	Latest Shema according to Baal HaTanya	\N	\N	morning	proportional_hours(3, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
d746de0a-fbdb-40ba-b604-31e848b3b2c5	sof_zman_shma_3_hours	סוף זמן ק"ש 3 שעות לפני חצות	Latest Shema (3 Hours Before Chatzos)	Sof Zman Shma 3H	Latest Shema - fixed 3 hours before chatzos	\N	\N	morning	solar_noon - 3hr	f	f	\N	\N	2025-12-03 16:12:57.945639+00	2025-12-03 16:12:57.945639+00
58651776-4bc2-4c9a-b7af-97f460d23659	sof_zman_tfila_mga_72_zmanis	סוף זמן תפילה מג"א 72 זמניות	Latest Shacharit (MGA 72 Zmaniyos)	Sof Zman Tfila MGA 72Z	Latest Shacharit MGA based on 72 proportional minute day	\N	\N	morning	proportional_hours(4, mga_72_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
6e4789ee-1a3f-4f32-bef7-0bc954ffdada	sof_zman_tfila_mga_90_zmanis	סוף זמן תפילה מג"א 90 זמניות	Latest Shacharit (MGA 90 Zmaniyos)	Sof Zman Tfila MGA 90Z	Latest Shacharit MGA based on 90 proportional minute day	\N	\N	morning	proportional_hours(4, mga_90_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
19c58a69-9d63-4df2-89b4-581c2cc37624	sof_zman_tfila_mga_96	סוף זמן תפילה מג"א 96	Latest Shacharit (MGA 96)	Sof Zman Tfila MGA 96	Latest Shacharit MGA based on 96 minute day	\N	\N	morning	proportional_hours(4, mga_96)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
2d79cb42-bf89-43de-8cf4-2f4fa02b8e01	sof_zman_tfila_mga_96_zmanis	סוף זמן תפילה מג"א 96 זמניות	Latest Shacharit (MGA 96 Zmaniyos)	Sof Zman Tfila MGA 96Z	Latest Shacharit MGA based on 96 proportional minute day	\N	\N	morning	proportional_hours(4, mga_96_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
cfdd92ae-c43e-44f3-b225-034ef7c3a56d	sof_zman_tfila_mga_18	סוף זמן תפילה מג"א 18°	Latest Shacharit (MGA 18°)	Sof Zman Tfila MGA 18	Latest Shacharit MGA based on 18° alos/tzais	\N	\N	morning	proportional_hours(4, mga_18)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
9079cdd5-36ae-4292-abb2-2ab661fabad4	sof_zman_tfila_mga_19_8	סוף זמן תפילה מג"א 19.8°	Latest Shacharit (MGA 19.8°)	Sof Zman Tfila MGA 19.8	Latest Shacharit MGA based on 19.8° alos/tzais	\N	\N	morning	proportional_hours(4, mga_19_8)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
c81163f7-57df-45ec-a3f6-ef84b468fa56	sof_zman_tfila_ateret_torah	סוף זמן תפילה עטרת תורה	Latest Shacharit (Ateret Torah)	Sof Zman Tfila AT	Latest Shacharit per Chacham Yosef Harari-Raful	\N	\N	morning	proportional_hours(4, ateret_torah)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
d42078b3-46f3-434b-940e-a56f25cf7202	sof_zman_tfila_baal_hatanya	סוף זמן תפילה בעל התניא	Latest Shacharit (Baal HaTanya)	Sof Zman Tfila BH	Latest Shacharit according to Baal HaTanya	\N	\N	morning	proportional_hours(4, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
730f3739-4109-49b0-a75f-b14482acc564	sof_zman_tfila_2_hours	סוף זמן תפילה 2 שעות לפני חצות	Latest Shacharit (2 Hours Before Chatzos)	Sof Zman Tfila 2H	Latest Shacharit - fixed 2 hours before chatzos	\N	\N	morning	solar_noon - 2hr	f	f	\N	\N	2025-12-03 16:12:57.947274+00	2025-12-03 16:12:57.947274+00
5cf379a0-cf2e-4b0f-b385-2e19c90f376a	mincha_gedola_72	מנחה גדולה 72 דקות	Earliest Mincha (72 min)	Mincha Gedola 72	Earliest Mincha based on 72 minute day	\N	\N	midday	proportional_hours(6.5, mga)	f	f	\N	\N	2025-12-03 16:12:57.948523+00	2025-12-03 16:12:57.948523+00
de476e34-0be1-468c-9872-59d9f0935fde	mincha_gedola_ateret_torah	מנחה גדולה עטרת תורה	Earliest Mincha (Ateret Torah)	Mincha Gedola AT	Earliest Mincha per Chacham Yosef Harari-Raful	\N	\N	midday	proportional_hours(6.5, ateret_torah)	f	f	\N	\N	2025-12-03 16:12:57.948523+00	2025-12-03 16:12:57.948523+00
83e5da70-b7db-4ada-8adc-e23f36a247c9	mincha_gedola_baal_hatanya	מנחה גדולה בעל התניא	Earliest Mincha (Baal HaTanya)	Mincha Gedola BH	Earliest Mincha according to Baal HaTanya	\N	\N	midday	proportional_hours(6.5, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.948523+00	2025-12-03 16:12:57.948523+00
4ac6e802-e80c-4af8-a9ae-08c9d9cc5dc1	mincha_ketana_ateret_torah	מנחה קטנה עטרת תורה	Mincha Ketana (Ateret Torah)	Mincha Ketana AT	Mincha Ketana per Chacham Yosef Harari-Raful	\N	\N	afternoon	proportional_hours(9.5, ateret_torah)	f	f	\N	\N	2025-12-03 16:12:57.948523+00	2025-12-03 16:12:57.948523+00
e5dd8193-aa6c-4018-9bd2-a56546d34865	mincha_ketana_baal_hatanya	מנחה קטנה בעל התניא	Mincha Ketana (Baal HaTanya)	Mincha Ketana BH	Mincha Ketana according to Baal HaTanya	\N	\N	afternoon	proportional_hours(9.5, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.948523+00	2025-12-03 16:12:57.948523+00
38206df8-dc29-4d92-aded-5ca304fc2d8d	samuch_lmincha_ketana_72	סמוך למנחה קטנה 72	Samuch L'Mincha Ketana (72 min)	Samuch LMincha 72	Half hour before Mincha Ketana (72 min day)	\N	\N	afternoon	proportional_hours(9, mga)	f	f	\N	\N	2025-12-03 16:12:57.948523+00	2025-12-03 16:12:57.948523+00
701bdd6b-18b3-47f7-845e-58c75c136ef8	plag_hamincha_18	פלג המנחה 18°	Plag HaMincha (18°)	Plag Hamincha 18	Plag HaMincha based on 18° calculation	\N	\N	afternoon	proportional_hours(10.75, mga_18)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
895d262f-b940-4b97-aa7f-c046b764f415	plag_hamincha_19_8	פלג המנחה 19.8°	Plag HaMincha (19.8°)	Plag Hamincha 19.8	Plag HaMincha based on 19.8° calculation	\N	\N	afternoon	proportional_hours(10.75, mga_19_8)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
4a73201d-7eba-41d6-b274-0a15beb48638	plag_hamincha_26	פלג המנחה 26°	Plag HaMincha (26°)	Plag Hamincha 26	Plag HaMincha based on 26° calculation	\N	\N	afternoon	proportional_hours(10.75, mga_26)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
5735207d-df9f-4074-b266-20ca3084a038	plag_hamincha_60	פלג המנחה 60 דקות	Plag HaMincha (60 min)	Plag Hamincha 60	Plag HaMincha based on 60 minute day	\N	\N	afternoon	proportional_hours(10.75, mga_60)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
2768a6a5-7abe-49b1-ba4e-1a7116ea68ac	plag_hamincha_90	פלג המנחה 90 דקות	Plag HaMincha (90 min)	Plag Hamincha 90	Plag HaMincha based on 90 minute day	\N	\N	afternoon	proportional_hours(10.75, mga_90)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
bd7b8cfd-96a3-445a-904a-58ab4305a6e5	plag_hamincha_96	פלג המנחה 96 דקות	Plag HaMincha (96 min)	Plag Hamincha 96	Plag HaMincha based on 96 minute day	\N	\N	afternoon	proportional_hours(10.75, mga_96)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
8cee05ee-944a-4571-9069-951ed4b7e20f	plag_hamincha_120	פלג המנחה 120 דקות	Plag HaMincha (120 min)	Plag Hamincha 120	Plag HaMincha based on 120 minute day	\N	\N	afternoon	proportional_hours(10.75, mga_120)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
b43c1e7c-1f5a-4d21-987b-2944e3ba0237	plag_hamincha_ateret_torah	פלג המנחה עטרת תורה	Plag HaMincha (Ateret Torah)	Plag Hamincha AT	Plag HaMincha per Chacham Yosef Harari-Raful	\N	\N	afternoon	proportional_hours(10.75, ateret_torah)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
87535f85-f45f-4050-9247-965c957a6d66	plag_hamincha_baal_hatanya	פלג המנחה בעל התניא	Plag HaMincha (Baal HaTanya)	Plag Hamincha BH	Plag HaMincha according to Baal HaTanya	\N	\N	afternoon	proportional_hours(10.75, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.950977+00	2025-12-03 16:12:57.950977+00
0c47b292-ce2f-4d02-9dc3-210f8271730e	tzais_3_65	צאת 3.65°	Tzais (3.65°)	Tzais 3.65	Nightfall at 3.65° - Geonim opinion	\N	\N	nightfall	solar(3.65, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
3c246eb3-50a0-4d7e-82c0-a82e2a63d74a	tzais_3_676	צאת 3.676°	Tzais (3.676°)	Tzais 3.676	Nightfall at 3.676° - Geonim opinion	\N	\N	nightfall	solar(3.676, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
c8ded284-da56-4dc0-a822-1f5907ac7f6c	tzais_3_7	צאת 3.7°	Tzais (3.7°)	Tzais 3.7	Nightfall at 3.7° - Geonim opinion	\N	\N	nightfall	solar(3.7, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
9e71f57a-0ebe-49ed-96d7-c8efeba45bfa	tzais_3_8	צאת 3.8°	Tzais (3.8°)	Tzais 3.8	Nightfall at 3.8° - Geonim opinion	\N	\N	nightfall	solar(3.8, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
b54d037d-e9c8-48d2-8990-4f783929013c	tzais_5_88	צאת 5.88°	Tzais (5.88°)	Tzais 5.88	Nightfall at 5.88°	\N	\N	nightfall	solar(5.88, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
70fe606c-1027-47ab-b425-a2946e327f80	tzais_6_45	צאת 6.45°	Tzais (6.45°)	Tzais 6.45	Nightfall at 6.45°	\N	\N	nightfall	solar(6.45, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
4deba1b9-fb56-4ac9-87e6-0445fd84b169	tzais_72_zmanis	צאת 72 דקות זמניות	Tzais (72 Zmaniyos)	Tzais 72 Zmanis	Nightfall 72 proportional minutes after sunset	\N	\N	nightfall	proportional_minutes(72, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
d9d93e34-3673-4486-ba7e-8f1d0a088253	tzais_90_zmanis	צאת 90 דקות זמניות	Tzais (90 Zmaniyos)	Tzais 90 Zmanis	Nightfall 90 proportional minutes after sunset	\N	\N	nightfall	proportional_minutes(90, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
a421da2d-bd4d-4431-b571-020fe5c88305	tzais_96_zmanis	צאת 96 דקות זמניות	Tzais (96 Zmaniyos)	Tzais 96 Zmanis	Nightfall 96 proportional minutes after sunset	\N	\N	nightfall	proportional_minutes(96, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
2441331b-178e-439e-8ce7-b3d547a9683a	tzais_120_zmanis	צאת 120 דקות זמניות	Tzais (120 Zmaniyos)	Tzais 120 Zmanis	Nightfall 120 proportional minutes after sunset	\N	\N	nightfall	proportional_minutes(120, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
a3099b42-7053-4b64-982b-6f5487e63876	tzais_baal_hatanya	צאת בעל התניא	Tzais (Baal HaTanya)	Tzais BH	Nightfall according to Baal HaTanya	\N	\N	nightfall	solar(6.5, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
a579993e-409c-40e9-8af0-937584847be7	tzais_ateret_torah	צאת עטרת תורה	Tzais (Ateret Torah)	Tzais AT	Nightfall per Chacham Yosef Harari-Raful (sunset + 40 min)	\N	\N	nightfall	sunset + 40min	f	f	\N	\N	2025-12-03 16:12:57.952979+00	2025-12-03 16:12:57.952979+00
74e4cf91-e7c2-40e3-8747-cd3549c2d448	bein_hashmashos_rt_13_24	בין השמשות ר"ת 13.24°	Bein Hashmashos R"T (13.24°)	BH RT 13.24	Bein Hashmashos according to Rabbeinu Tam at 13.24°	\N	\N	sunset	solar(13.24, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
6dcafe7c-0a32-4b43-8ff2-7123f927e97a	bein_hashmashos_rt_58_5	בין השמשות ר"ת 58.5 דקות	Bein Hashmashos R"T (58.5 min)	BH RT 58.5	Bein Hashmashos 58.5 minutes after sunset	\N	\N	sunset	sunset + 58min	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
251f1f13-c2a3-4d7e-a9f3-4539ba3bbbca	bein_hashmashos_rt_2_stars	בין השמשות ר"ת 2 כוכבים	Bein Hashmashos R"T (2 Stars)	BH RT 2 Stars	Bein Hashmashos when 2 stars visible	\N	\N	sunset	solar(7.5, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
bfa42ca2-1c34-4f1c-a634-c7c681ea774e	bein_hashmashos_yereim_2_1	בין השמשות יראים 2.1°	Bein Hashmashos Yereim (2.1°)	BH Yereim 2.1	Bein Hashmashos per Yereim at 2.1°	\N	\N	sunset	solar(2.1, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
1ac9f5f7-d25c-45a5-84e9-b665bbdd739f	bein_hashmashos_yereim_2_8	בין השמשות יראים 2.8°	Bein Hashmashos Yereim (2.8°)	BH Yereim 2.8	Bein Hashmashos per Yereim at 2.8°	\N	\N	sunset	solar(2.8, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
7696b4f4-51a3-4e2c-a08e-4c09b7943d15	bein_hashmashos_yereim_3_05	בין השמשות יראים 3.05°	Bein Hashmashos Yereim (3.05°)	BH Yereim 3.05	Bein Hashmashos per Yereim at 3.05°	\N	\N	sunset	solar(3.05, after_sunset)	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
3bafd17f-9f9d-4fe7-8278-eb64e492f0c9	bein_hashmashos_yereim_13_5	בין השמשות יראים 13.5 דקות	Bein Hashmashos Yereim (13.5 min)	BH Yereim 13.5	Bein Hashmashos per Yereim 13.5 minutes after sunset	\N	\N	sunset	sunset + 13min	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
bd12d1a8-59e1-4904-94c8-b991a39094d3	bein_hashmashos_yereim_16_875	בין השמשות יראים 16.875 דקות	Bein Hashmashos Yereim (16.875 min)	BH Yereim 16.875	Bein Hashmashos per Yereim 16.875 minutes after sunset	\N	\N	sunset	sunset + 17min	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
0486b97d-6ace-41e9-a92a-c5c79aae8b3f	bein_hashmashos_yereim_18	בין השמשות יראים 18 דקות	Bein Hashmashos Yereim (18 min)	BH Yereim 18	Bein Hashmashos per Yereim 18 minutes after sunset	\N	\N	sunset	sunset + 18min	f	f	\N	\N	2025-12-03 16:12:57.954222+00	2025-12-03 16:12:57.954222+00
d012bc77-c558-4b14-9ed2-8974afe57325	sof_zman_achilas_chametz_mga_72_zmanis	סוף זמן אכילת חמץ מג"א 72 זמניות	Latest Eating Chametz (MGA 72 Zmaniyos)	Sof Achilat Chametz MGA 72Z	Latest time to eat chametz based on 72 zmaniyos day	\N	\N	morning	proportional_hours(4, mga_72_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.955919+00	2025-12-03 16:12:57.955919+00
5aef5f32-79d8-450c-948c-19afd7cefe32	sof_zman_achilas_chametz_mga_16_1	סוף זמן אכילת חמץ מג"א 16.1°	Latest Eating Chametz (MGA 16.1°)	Sof Achilat Chametz MGA 16.1	Latest time to eat chametz based on 16.1° day	\N	\N	morning	proportional_hours(4, mga_16_1)	f	f	\N	\N	2025-12-03 16:12:57.955919+00	2025-12-03 16:12:57.955919+00
eb8ce802-47c1-44d5-8508-8bd1260c8fc8	sof_zman_achilas_chametz_baal_hatanya	סוף זמן אכילת חמץ בעל התניא	Latest Eating Chametz (Baal HaTanya)	Sof Achilat Chametz BH	Latest time to eat chametz per Baal HaTanya	\N	\N	morning	proportional_hours(4, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.955919+00	2025-12-03 16:12:57.955919+00
3f31f108-2cc5-4d60-be0a-217dbf56c39b	sof_zman_biur_chametz_mga_72_zmanis	סוף זמן ביעור חמץ מג"א 72 זמניות	Latest Burning Chametz (MGA 72 Zmaniyos)	Sof Biur Chametz MGA 72Z	Latest time to burn chametz based on 72 zmaniyos day	\N	\N	morning	proportional_hours(5, mga_72_zmanis)	f	f	\N	\N	2025-12-03 16:12:57.955919+00	2025-12-03 16:12:57.955919+00
1b06c275-c1c1-4dd3-8ebd-e5f3135ac66d	sof_zman_biur_chametz_mga_16_1	סוף זמן ביעור חמץ מג"א 16.1°	Latest Burning Chametz (MGA 16.1°)	Sof Biur Chametz MGA 16.1	Latest time to burn chametz based on 16.1° day	\N	\N	morning	proportional_hours(5, mga_16_1)	f	f	\N	\N	2025-12-03 16:12:57.955919+00	2025-12-03 16:12:57.955919+00
d526930d-ead4-4de5-aebe-9998696695f6	sof_zman_biur_chametz_baal_hatanya	סוף זמן ביעור חמץ בעל התניא	Latest Burning Chametz (Baal HaTanya)	Sof Biur Chametz BH	Latest time to burn chametz per Baal HaTanya	\N	\N	morning	proportional_hours(5, baal_hatanya)	f	f	\N	\N	2025-12-03 16:12:57.955919+00	2025-12-03 16:12:57.955919+00
4489ea44-7c53-4c8b-b113-d54d48924265	tchillas_zman_kiddush_levana_3	תחילת זמן קידוש לבנה 3 ימים	Earliest Kiddush Levana (3 Days)	Tchillas Kiddush Levana 3	Earliest time for Kiddush Levana - 3 days after molad	\N	\N	nightfall	molad + 3days	f	f	\N	\N	2025-12-03 16:12:57.9575+00	2025-12-03 16:12:57.9575+00
467dc923-d8f9-4924-9b38-ab97c41df1fd	tchillas_zman_kiddush_levana_7	תחילת זמן קידוש לבנה 7 ימים	Earliest Kiddush Levana (7 Days)	Tchillas Kiddush Levana 7	Earliest time for Kiddush Levana - 7 days after molad	\N	\N	nightfall	molad + 7days	f	f	\N	\N	2025-12-03 16:12:57.9575+00	2025-12-03 16:12:57.9575+00
e8d3ea2d-c23e-4d91-9f5c-d18427b252c0	sof_zman_kiddush_levana_15	סוף זמן קידוש לבנה 15 ימים	Latest Kiddush Levana (15 Days)	Sof Kiddush Levana 15	Latest time for Kiddush Levana - 15 days after molad	\N	\N	nightfall	molad + 15days	f	f	\N	\N	2025-12-03 16:12:57.9575+00	2025-12-03 16:12:57.9575+00
a2dadd92-4a67-4db1-96bf-9cf8da4e057f	sof_zman_kiddush_levana_between_moldos	סוף זמן קידוש לבנה בין המולדות	Latest Kiddush Levana (Between Molados)	Sof Kiddush Levana BM	Latest Kiddush Levana - halfway between molados (~14.75 days)	\N	\N	nightfall	molad + 14days + 18hr	f	f	\N	\N	2025-12-03 16:12:57.9575+00	2025-12-03 16:12:57.9575+00
a37ca4f4-a2a1-42d2-8d4e-4967e26707e8	fast_begins	תחילת הצום	Fast Begins	Techilas Hatzom	Beginning of dawn-start fasts (minor fasts begin at alos)	\N	\N	dawn	solar(16.1, before_sunrise)	f	f	\N	\N	2025-12-03 16:12:57.958972+00	2025-12-03 16:12:57.958972+00
753cfe5d-5875-4b98-b92f-72e084cc7af5	fast_begins_72	תחילת הצום 72 דקות	Fast Begins (72 min)	Techilas Hatzom 72	Fast begins 72 minutes before sunrise	\N	\N	dawn	sunrise - 72min	f	f	\N	\N	2025-12-03 16:12:57.958972+00	2025-12-03 16:12:57.958972+00
114b86e5-5579-406b-bf50-617dcb3533c5	fast_begins_90	תחילת הצום 90 דקות	Fast Begins (90 min)	Techilas Hatzom 90	Fast begins 90 minutes before sunrise	\N	\N	dawn	sunrise - 90min	f	f	\N	\N	2025-12-03 16:12:57.958972+00	2025-12-03 16:12:57.958972+00
822c9e96-5fbf-4a1f-bc34-b13189b9d677	fast_begins_sunset	תחילת הצום (שקיעה)	Fast Begins (Sunset)	Techilas Hatzom Shkiah	Beginning of sunset-start fasts (Yom Kippur, Tisha B'Av)	\N	\N	sunset	sunset	f	f	\N	\N	2025-12-03 16:12:57.958972+00	2025-12-03 16:12:57.958972+00
efcd3ecd-66d4-442f-b477-b689a77ce27a	fixed_local_chatzos	חצות קבוע	Fixed Local Chatzos	Chatzos Kavua	Fixed local chatzos (12:00 PM local standard time)	\N	\N	midday	12:00	f	f	\N	\N	2025-12-03 16:12:57.960195+00	2025-12-03 16:12:57.960195+00
abd759d4-9a85-46b5-b497-ba46b7de0e38	shaah_zmanis_gra	שעה זמנית גר"א	Shaah Zmanis (GRA)	Shaah Zmanis GRA	One proportional hour according to GRA	\N	\N	midday	shaah_zmanis(gra)	f	t	\N	\N	2025-12-03 16:12:57.960195+00	2025-12-03 16:12:57.960195+00
e8ab1e15-6d83-4dce-b256-701be2e4a252	shaah_zmanis_mga	שעה זמנית מג"א	Shaah Zmanis (MGA)	Shaah Zmanis MGA	One proportional hour according to MGA	\N	\N	midday	shaah_zmanis(mga)	f	t	\N	\N	2025-12-03 16:12:57.960195+00	2025-12-03 16:12:57.960195+00
14ab0597-f946-4e7c-9f80-91ca128d5b55	samuch_lmincha_ketana_16_1	סמוך למנחה קטנה 16.1°	Samuch L'Mincha Ketana (16.1°)	Samuch LMincha 16.1	Half hour before Mincha Ketana (16.1° day)	\N	\N	afternoon	proportional_hours(9, mga_16_1)	f	f	\N	\N	2025-12-03 16:12:57.960195+00	2025-12-03 16:12:57.960195+00
038dc557-c1ec-4d82-b2b6-828a0cd82f73	havdalah	הבדלה	Havdalah	Havdalah	End of Shabbos/Yom Tov - default 42 minutes after sunset	\N	\N	nightfall	sunset + 42min	f	f	\N	\N	2025-12-03 21:03:48.682601+00	2025-12-03 21:03:48.682601+00
17a26364-11ca-4b16-9e29-18bdba18cf25	alos_12	עלות השחר 12°	Dawn (12°)	Alos Hashachar 12°	Dawn calculated at 12 degrees below the horizon. Used by Manchester and other Northern European communities per Minchas Yitzchak.	\N	\N	dawn	solar(12, before_sunrise)	f	f	\N	\N	2025-12-04 12:46:30.704236+00	2025-12-04 12:46:30.704236+00
7949f93d-c348-4e0c-99e9-743212ecb00b	tzais_7_08	צאת הכוכבים 7.08°	Nightfall (7.08°)	Tzais Hakochavim 7.08°	Three small stars visible when sun is 7.08 degrees below horizon. Used by Manchester community.	\N	\N	nightfall	solar(7.08, after_sunset)	f	f	\N	\N	2025-12-04 12:46:30.751676+00	2025-12-04 12:46:30.751676+00
072070ad-c303-4f36-a7ab-f5fee318fafb	plag_hamincha_terumas_hadeshen	פלג המנחה - תרומת הדשן	Plag HaMincha (Terumas HaDeshen)	Plag HaMincha Terumas HaDeshen	Plag HaMincha calculated with day starting from midnight per Terumas HaDeshen	\N	\N	afternoon	proportional_hours(10.75, custom(sunrise - 90min, sunset + 90min))	f	f	\N	\N	2025-12-04 13:36:58.919755+00	2025-12-04 13:36:58.919755+00
b3be6f50-cc36-4e7d-aa69-fbf2fea26810	sof_zman_shma_mga_16_1	סוף זמן שמע - מג"א 16.1°	Latest Shema (MGA 16.1°)	Sof Zman Shma MGA 16.1	Latest time for Shema per MGA using 16.1° dawn and 16.1° tzais	\N	\N	morning	proportional_hours(3, mga)	f	f	\N	\N	2025-12-04 13:36:58.919755+00	2025-12-04 13:36:58.919755+00
6258387c-5dac-48cf-a500-49cd87786350	sof_zman_shma_mga_72	סוף זמן שמע - מג"א 72	Latest Shema (MGA 72)	Sof Zman Shma MGA 72	Latest time for Shema per MGA using 72-minute dawn and tzais	\N	\N	morning	proportional_hours(3, mga_90)	f	f	\N	\N	2025-12-04 13:36:58.919755+00	2025-12-04 13:36:58.919755+00
b0e714e8-59d1-45d1-bff5-14d16b958bd2	alos_shemini_atzeres	עלות השחר - שמיני עצרת	Dawn for Aravos (Shemini Atzeres)	Alos HaShachar - Shemini Atzeret	Dawn calculation for the 8th day of Sukkot when Aravos is done early	\N	\N	dawn	sunrise - 24min	f	f	\N	\N	2025-12-04 13:36:58.919755+00	2025-12-04 13:40:39.76847+00
\.


--
-- Data for Name: password_reset_tokens; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.password_reset_tokens (id, email, token, expires_at, created_at) FROM stdin;
\.


--
-- Data for Name: publisher_coverage; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_coverage (id, publisher_id, coverage_level, continent_code, country_id, region_id, district_id, city_id, priority, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: publisher_invitations; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_invitations (id, publisher_id, email, token, status, invited_by, expires_at, accepted_at, created_at) FROM stdin;
\.


--
-- Data for Name: publisher_onboarding; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_onboarding (id, publisher_id, current_step, completed_steps, wizard_data, started_at, last_updated_at, completed_at, skipped) FROM stdin;
7225d46b-d7e5-4ed7-a432-7adac5daa152	6c85458d-2225-4f55-bc15-5c9844bcf362	5	{3}	{"coverage": [{"id": "GB", "name": "United Kingdom", "type": "country"}], "template": "default", "customizations": [{"enabled": true, "formula": "proportional_hours(9.5, gra)", "category": "everyday", "modified": false, "zman_key": "mincha_ketana", "hebrew_name": "מנחה קטנה", "english_name": "Mincha Ketana", "time_category": "afternoon", "master_zman_id": "8506c62a-2f48-42b4-a02f-0b18b8e8478c"}, {"enabled": true, "formula": "proportional_hours(10.75, gra)", "category": "everyday", "modified": false, "zman_key": "plag_hamincha", "hebrew_name": "פלג המנחה", "english_name": "Plag HaMincha", "time_category": "afternoon", "master_zman_id": "b4e6778c-cb14-4fe5-b3e8-99c85a19606c"}, {"enabled": true, "formula": "solar(16.1, before_sunrise)", "category": "everyday", "modified": false, "zman_key": "alos_hashachar", "hebrew_name": "עלות השחר", "english_name": "Dawn (Alos Hashachar)", "time_category": "dawn", "master_zman_id": "ada9beca-6052-4150-9d22-6a875582e3dc"}, {"enabled": true, "formula": "solar_noon", "category": "everyday", "modified": false, "zman_key": "chatzos", "hebrew_name": "חצות היום", "english_name": "Midday (Chatzos)", "time_category": "midday", "master_zman_id": "5c1806a7-5c5f-4231-8ea6-f2821a3f74ff"}, {"enabled": true, "formula": "proportional_hours(6.5, gra)", "category": "everyday", "modified": false, "zman_key": "mincha_gedola", "hebrew_name": "מנחה גדולה", "english_name": "Earliest Mincha (GRA)", "time_category": "midday", "master_zman_id": "a56cc3c5-2210-4945-8c48-85cd0b48d936"}, {"enabled": true, "formula": "solar_noon + 12hr", "category": "everyday", "modified": false, "zman_key": "chatzos_layla", "hebrew_name": "חצות לילה", "english_name": "Midnight (Chatzos Layla)", "time_category": "midnight", "master_zman_id": "6af15b21-1fd8-4958-89d0-8e8df94c059f"}, {"enabled": true, "formula": "proportional_hours(3, gra)", "category": "everyday", "modified": false, "zman_key": "sof_zman_shma_gra", "hebrew_name": "סוף זמן ק\\"ש גר\\"א", "english_name": "Latest Shema (GRA)", "time_category": "morning", "master_zman_id": "a03df06c-8cca-4115-9ff1-4bc04e759ffc"}, {"enabled": true, "formula": "proportional_hours(3, mga)", "category": "everyday", "modified": false, "zman_key": "sof_zman_shma_mga", "hebrew_name": "סוף זמן ק\\"ש מג\\"א", "english_name": "Latest Shema (MGA)", "time_category": "morning", "master_zman_id": "7faef612-5f93-4cb0-bf4d-b6ad67f22583"}, {"enabled": true, "formula": "proportional_hours(4, gra)", "category": "everyday", "modified": false, "zman_key": "sof_zman_tfila_gra", "hebrew_name": "סוף זמן תפילה גר\\"א", "english_name": "Latest Shacharit (GRA)", "time_category": "morning", "master_zman_id": "31ef5cc3-e541-4750-b78b-99840dc7a372"}, {"enabled": true, "formula": "proportional_hours(4, mga)", "category": "everyday", "modified": false, "zman_key": "sof_zman_tfila_mga", "hebrew_name": "סוף זמן תפילה מג\\"א", "english_name": "Latest Shacharit (MGA)", "time_category": "morning", "master_zman_id": "b32f320e-4fe5-4ba1-99db-78ad7b65cb66"}, {"enabled": true, "formula": "solar(8.5, after_sunset)", "category": "event", "modified": false, "zman_key": "shabbos_ends", "hebrew_name": "מוצאי שבת", "english_name": "Shabbos Ends", "time_category": "nightfall", "master_zman_id": "888f7113-4a77-44a1-aa1d-22cb297297a5"}, {"enabled": true, "formula": "solar(8.5, after_sunset)", "category": "event", "modified": false, "zman_key": "fast_ends", "hebrew_name": "סוף הצום", "english_name": "Fast Ends", "time_category": "nightfall", "master_zman_id": "5873dd70-0a42-44e7-aba4-d0eeec0457a0"}, {"enabled": true, "formula": "solar(8.5, after_sunset)", "category": "everyday", "modified": false, "zman_key": "tzais", "hebrew_name": "צאת הכוכבים", "english_name": "Nightfall (Tzais)", "time_category": "nightfall", "master_zman_id": "319dfba5-0cf0-4479-b0c5-16ae0218fef0"}, {"enabled": true, "formula": "sunset + 72min", "category": "everyday", "modified": false, "zman_key": "tzais_72", "hebrew_name": "צאת ר\\"ת 72 דקות", "english_name": "Tzais Rabbeinu Tam (72 min)", "time_category": "nightfall", "master_zman_id": "d156b928-3c35-4360-acc9-f767fe425f18"}, {"enabled": true, "formula": "sunrise", "category": "everyday", "modified": false, "zman_key": "sunrise", "hebrew_name": "הנץ החמה", "english_name": "Sunrise", "time_category": "sunrise", "master_zman_id": "10d89e97-e29b-4a0c-8775-04ccd6c15ba3"}, {"enabled": true, "formula": "solar(11.5, before_sunrise)", "category": "everyday", "modified": false, "zman_key": "misheyakir", "hebrew_name": "משיכיר", "english_name": "Misheyakir", "time_category": "sunrise", "master_zman_id": "fee6ae15-91bb-401d-be34-4a7256ed32cb"}, {"enabled": true, "formula": "sunset - 18min", "category": "event", "modified": false, "zman_key": "candle_lighting", "hebrew_name": "הדלקת נרות", "english_name": "Candle Lighting", "time_category": "sunset", "master_zman_id": "8b861617-e264-4542-a8db-01f7512cab7d"}, {"enabled": true, "formula": "sunset", "category": "everyday", "modified": false, "zman_key": "sunset", "hebrew_name": "שקיעה", "english_name": "Sunset", "time_category": "sunset", "master_zman_id": "c92d8740-af5c-4298-a65d-ce5f64d76551"}, {"enabled": true, "formula": "sunrise - 60min", "category": "everyday", "modified": false, "zman_key": "alos_60", "hebrew_name": "עלות השחר 60 דקות", "english_name": "Dawn (60 minutes)", "time_category": "dawn", "master_zman_id": "335f6c20-4702-41ae-babe-bf5e21527b75"}, {"enabled": true, "formula": "solar(26, before_sunrise)", "category": "everyday", "modified": false, "zman_key": "alos_26", "hebrew_name": "עלות השחר 26°", "english_name": "Dawn (26°)", "time_category": "dawn", "master_zman_id": "b5f13561-2202-4b6e-aca7-554a2f841b86"}]}	2025-12-03 18:44:47.541787+00	2025-12-03 18:45:33.792852+00	2025-12-03 18:45:35.478897+00	f
\.


--
-- Data for Name: publisher_requests; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_requests (id, name, email, website, description, status, rejection_reason, reviewed_by, reviewed_at, created_at) FROM stdin;
\.


--
-- Data for Name: publisher_snapshots; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_snapshots (id, publisher_id, description, snapshot_data, created_by, created_at) FROM stdin;
8132b85c-81b9-443e-86ae-e31a1821ebea	6c85458d-2225-4f55-bc15-5c9844bcf362	Version save - Dec 4, 2025 3:06 PM	{"zmanim": [{"is_beta": false, "category": "optional", "zman_key": "chatzos_layla", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Midnight - 12 hours after midday. Per Igros Moshe OC 2:20.", "formula_dsl": "solar_noon + 12hr", "hebrew_name": "חצות לילה", "source_type": "custom", "english_name": "Chatzos Layla", "is_published": true, "master_zman_id": "6af15b21-1fd8-4958-89d0-8e8df94c059f", "transliteration": "Chatzos Layla", "publisher_comment": "May vary by one minute from midday + 12 hours."}, {"is_beta": false, "category": "optional", "zman_key": "shabbos_ends", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "End of Shabbos when three small consecutive stars are visible. Sun 8° below horizon.", "formula_dsl": "solar(8, after_sunset)", "hebrew_name": "מוצש״ק", "source_type": "custom", "english_name": "Motzei Shabbos", "is_published": true, "master_zman_id": "888f7113-4a77-44a1-aa1d-22cb297297a5", "transliteration": "Motzei Shabbos Kodesh"}, {"is_beta": false, "category": "optional", "zman_key": "alos_72", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "72 fixed minutes before sunrise throughout the year.", "formula_dsl": "sunrise - 72min", "hebrew_name": "עלות 72 דק׳", "source_type": "registry", "english_name": "Alos 72 min", "is_published": true, "master_zman_id": "c2b8088d-da9f-4753-a245-eb2ba2346870", "transliteration": "Alos 72 Dakos", "publisher_comment": "For those whose custom it is. Some add in summer to account for mil being 22.5 min, making dawn 90 min before sunrise."}, {"is_beta": false, "category": "essential", "zman_key": "alos_12", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Sun 12° below horizon. Per Minchas Yitzchak 9:9, this corresponds with reality in Northern Europe.", "formula_dsl": "solar(12, before_sunrise)", "hebrew_name": "עלות השחר ב׳", "source_type": "registry", "english_name": "Alos HaShachar 2", "is_published": true, "master_zman_id": "17a26364-11ca-4b16-9e29-18bdba18cf25", "transliteration": "Alos HaShachar Beis", "publisher_comment": "This has been the practice in the Manchester community for nearly 80 years since its founding. This is the PRIMARY dawn used for MGA calculations."}, {"is_beta": false, "category": "essential", "zman_key": "misheyakir", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Earliest time for tallis and tefillin with a blessing. The printed time is 15 minutes after the actual misheyakir time.", "formula_dsl": "solar(11.5, before_sunrise)", "hebrew_name": "משיכיר", "source_type": "custom", "english_name": "Misheyakir", "is_published": true, "master_zman_id": "fee6ae15-91bb-401d-be34-4a7256ed32cb", "transliteration": "Misheyakir", "publisher_comment": "In pressing circumstances (e.g., traveling), one may put on tallis 2 degrees earlier."}, {"is_beta": false, "category": "essential", "zman_key": "sunrise", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "The time when the upper edge of the sun rises above the horizon at sea level.", "formula_dsl": "sunrise", "hebrew_name": "הנץ", "source_type": "custom", "english_name": "HaNetz", "is_published": true, "master_zman_id": "10d89e97-e29b-4a0c-8775-04ccd6c15ba3", "transliteration": "HaNetz"}, {"is_beta": false, "category": "essential", "zman_key": "mincha_ketana", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Two and a half proportional hours before sunset.", "formula_dsl": "proportional_hours(9.5, gra)", "hebrew_name": "מנחה קטנה", "source_type": "custom", "english_name": "Mincha Ketana", "is_published": true, "master_zman_id": "8506c62a-2f48-42b4-a02f-0b18b8e8478c", "transliteration": "Mincha Ketana"}, {"is_beta": false, "category": "essential", "zman_key": "fast_ends", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "End of fast. For rabbinic fasts, one may be lenient by several minutes.", "formula_dsl": "solar(7.08, after_sunset)", "hebrew_name": "סוף התענית", "source_type": "custom", "english_name": "Sof HaTaanis", "is_published": true, "master_zman_id": "5873dd70-0a42-44e7-aba4-d0eeec0457a0", "transliteration": "Sof HaTaanis"}, {"is_beta": false, "category": "essential", "zman_key": "candle_lighting", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Time for lighting Shabbos candles and accepting Shabbos.", "formula_dsl": "sunset - 15min", "hebrew_name": "הדלקת נרות", "source_type": "custom", "english_name": "Hadlakas Neiros", "is_published": true, "master_zman_id": "8b861617-e264-4542-a8db-01f7512cab7d", "transliteration": "Hadlakas Neiros", "publisher_comment": "15 minutes before sunset, as has been the custom from ancient times."}, {"is_beta": false, "category": "optional", "zman_key": "alos_90", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "90 fixed minutes before sunrise. For those who calculate a mil as 22.5 minutes (4 x 22.5 = 90).", "formula_dsl": "sunrise - 90min", "hebrew_name": "עלות 90 דק׳", "source_type": "registry", "english_name": "Alos 90 min", "is_published": true, "master_zman_id": "ad46eeac-4a01-43f6-bb59-2e99c0c39824", "transliteration": "Alos 90 Dakos", "publisher_comment": "Some add in summer to account for the measure of a mil being 22.5 minutes."}, {"is_beta": false, "category": "optional", "zman_key": "plag_hamincha_72", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Plag HaMincha according to MA/Terumas Hadeshen practiced in many communities. One and a quarter proportional hours before nightfall, calculating 72 minutes before sunrise to 72 minutes after sunset.", "formula_dsl": "proportional_hours(10.75, mga)", "hebrew_name": "פלג - מ״א", "source_type": "registry", "english_name": "Plag - MA", "is_published": true, "master_zman_id": "cfbd81d7-dbc7-4108-b71e-2d9e33dd1a7e", "transliteration": "Plag HaMincha MA", "publisher_comment": "Since the time for accepting Shabbos, printed for the community."}, {"is_beta": false, "category": "essential", "zman_key": "alos_hashachar", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Sun 16.1° below horizon. In polar summer (May-July), the sun does not descend to 16.1° in Manchester, so midnight (chatzos layla) is printed as dawn.", "formula_dsl": "if (month >= 5 && month <= 7 && latitude > 50) { solar_noon } else { solar(16.1, before_sunrise) }", "hebrew_name": "עלות השחר א׳", "source_type": "custom", "english_name": "Alos HaShachar 1", "is_published": true, "master_zman_id": "ada9beca-6052-4150-9d22-6a875582e3dc", "transliteration": "Alos HaShachar Aleph", "publisher_comment": "Per Vilna Gaon and Siddur of the Rav. 72 minutes before sunrise in Eretz Yisrael during Nissan/Tishrei. Used as stringency for nighttime mitzvos like evening Shema and counting of the Omer. In polar summer, midnight is used as the dawn time."}, {"is_beta": false, "category": "essential", "zman_key": "sof_zman_shma_mga", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Per Manchester Beth Din / Minchas Yitzchak using 12° dawn and 7.08° nightfall", "formula_dsl": "proportional_hours(3, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))", "hebrew_name": "ס״ז ק״ש-מג״א", "source_type": "custom", "english_name": "Sof Zman K\\"Sh MGA", "is_published": true, "master_zman_id": "7faef612-5f93-4cb0-bf4d-b6ad67f22583", "transliteration": "Sof Zman Krias Shema MGA", "publisher_comment": "On Shabbos, additional stringency times are printed from Dawn 1 (16.1°)."}, {"is_beta": false, "category": "essential", "zman_key": "plag_hamincha_terumas_hadeshen", "is_custom": true, "is_enabled": true, "is_visible": true, "description": "One and a quarter proportional hours before nightfall, calculating the day from Dawn 2 (12°) until nightfall (7.08°).", "formula_dsl": "proportional_hours(10.75, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))", "hebrew_name": "פלג - תה״ד", "source_type": "custom", "english_name": "Plag - T\\"HD", "is_published": true, "master_zman_id": "072070ad-c303-4f36-a7ab-f5fee318fafb", "transliteration": "Plag HaMincha Terumas HaDeshen", "publisher_comment": "Per Terumas Hadeshen method."}, {"is_beta": false, "category": "optional", "zman_key": "sof_zman_shma_mga_16_1", "is_custom": true, "is_enabled": true, "is_visible": true, "description": "Stringency from Dawn 1 (16.1°) to nightfall at 16.1°, so beginning and end of day are equal.", "formula_dsl": "proportional_hours(3, custom(solar(16.1, before_sunrise), solar(16.1, after_sunset)))", "hebrew_name": "ס״ז ק״ש מ״א (16.1°)", "source_type": "custom", "english_name": "Sof Zman K\\"Sh MA (16.1°)", "is_published": true, "master_zman_id": "b3be6f50-cc36-4e7d-aa69-fbf2fea26810", "transliteration": "Sof Zman Krias Shema MA 16.1", "publisher_comment": "Printed on Shabbos as additional stringency for Torah-level Shema obligation."}, {"is_beta": false, "category": "optional", "zman_key": "sof_zman_shma_mga_72", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "72 min before sunrise to 72 min after sunset. Always 36 minutes before GRA time.", "formula_dsl": "proportional_hours(3, mga)", "hebrew_name": "ס״ז ק״ש מ״א (72)", "source_type": "registry", "english_name": "Sof Zman K\\"Sh MA (72min)", "is_published": true, "master_zman_id": "6258387c-5dac-48cf-a500-49cd87786350", "transliteration": "Sof Zman Krias Shema MA 72", "publisher_comment": "Practiced in many communities."}, {"is_beta": false, "category": "optional", "zman_key": "alos_shemini_atzeres", "is_custom": true, "is_enabled": true, "is_visible": true, "description": "Dawn calculated as 1/8th of the day before sunrise, using the Manchester day definition (12° to 7.08°).", "formula_dsl": "proportional_hours(-1.5, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))", "hebrew_name": "עלות לערבות", "source_type": "custom", "english_name": "Alos for Aravos", "is_published": true, "master_zman_id": "b0e714e8-59d1-45d1-bff5-14d16b958bd2", "transliteration": "Alos LaAravos", "publisher_comment": "Printed by the Minchas Yitzchak as a stringency."}, {"is_beta": false, "category": "essential", "zman_key": "sof_zman_shma_gra", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Latest time for Shema according to Vilna Gaon and Rabbi Zalman. One quarter of the day from sunrise to sunset.", "formula_dsl": "proportional_hours(3, gra)", "hebrew_name": "ס״ז ק״ש-גר״א", "source_type": "custom", "english_name": "Sof Zman K\\"Sh GRA", "is_published": true, "master_zman_id": "a03df06c-8cca-4115-9ff1-4bc04e759ffc", "transliteration": "Sof Zman Krias Shema GRA"}, {"is_beta": false, "category": "essential", "zman_key": "sof_zman_tfila_mga", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Per Manchester Beth Din / Minchas Yitzchak using 12° dawn and 7.08° nightfall", "formula_dsl": "proportional_hours(4, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))", "hebrew_name": "ס״ז תפלה-מג״א", "source_type": "custom", "english_name": "Sof Zman Tefila MGA", "is_published": true, "master_zman_id": "b32f320e-4fe5-4ba1-99db-78ad7b65cb66", "transliteration": "Sof Zman Tefila MGA", "publisher_comment": "For those using 72 min dawn, this is always 24 min before GRA time."}, {"is_beta": false, "category": "essential", "zman_key": "sof_zman_tfila_gra", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Latest time for morning prayer according to Vilna Gaon. One third of the day from sunrise to sunset.", "formula_dsl": "proportional_hours(4, gra)", "hebrew_name": "ס״ז תפלה-גר״א", "source_type": "custom", "english_name": "Sof Zman Tefila GRA", "is_published": true, "master_zman_id": "31ef5cc3-e541-4750-b78b-99840dc7a372", "transliteration": "Sof Zman Tefila GRA"}, {"is_beta": false, "category": "essential", "zman_key": "chatzos", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "The time when the sun stands at highest point between east and west. Half the time between sunrise and sunset. Midnight is 12 hours after.", "formula_dsl": "solar_noon", "hebrew_name": "חצות", "source_type": "custom", "english_name": "Chatzos", "is_published": true, "master_zman_id": "5c1806a7-5c5f-4231-8ea6-f2821a3f74ff", "transliteration": "Chatzos", "publisher_comment": "Per Igros Moshe, OC 2:20. May vary by one minute."}, {"is_beta": false, "category": "essential", "zman_key": "mincha_gedola", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Earliest time for afternoon prayer. Half a proportional hour after midday, but no less than 30 minutes.", "formula_dsl": "solar_noon + 30min", "hebrew_name": "מנחה גדולה", "source_type": "custom", "english_name": "Mincha Gedola", "is_published": true, "master_zman_id": "a56cc3c5-2210-4945-8c48-85cd0b48d936", "transliteration": "Mincha Gedola", "publisher_comment": "The practice is to be stringent - in winter when the proportional half-hour is less than 30 minutes, we use 30 minutes."}, {"is_beta": false, "category": "essential", "zman_key": "plag_hamincha", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Earliest time for Maariv, lighting Shabbos candles, and Chanukah candles. One and a quarter proportional hours before sunset.", "formula_dsl": "proportional_hours(10.75, gra)", "hebrew_name": "פלג - לבוש", "source_type": "custom", "english_name": "Plag - Levush", "is_published": true, "master_zman_id": "b4e6778c-cb14-4fe5-b3e8-99c85a19606c", "transliteration": "Plag HaMincha Levush"}, {"is_beta": false, "category": "essential", "zman_key": "sunset", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "The time when the sun is completely hidden from our eyes. Time printed is slightly before actual to be safe.", "formula_dsl": "sunset", "hebrew_name": "שקיעה", "source_type": "custom", "english_name": "Shkiah", "is_published": true, "master_zman_id": "c92d8740-af5c-4298-a65d-ce5f64d76551", "transliteration": "Shkiah"}, {"is_beta": false, "category": "essential", "zman_key": "tzais_7_08", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "Time when three small consecutive stars are visible. Sun 7.08° below horizon.", "formula_dsl": "solar(7.08, after_sunset)", "hebrew_name": "צאת הכוכבים", "source_type": "custom", "english_name": "Tzais HaKochavim", "is_published": true, "master_zman_id": "7949f93d-c348-4e0c-99e9-743212ecb00b", "transliteration": "Tzais HaKochavim", "publisher_comment": "For rabbinic fasts, one may be lenient by several minutes - consult a halachic authority."}, {"is_beta": false, "category": "essential", "zman_key": "tzais_72", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "72 minutes after sunset throughout the year, provided sun is at least 8° below horizon.", "formula_dsl": "sunset + 72min", "hebrew_name": "ר״ת", "source_type": "custom", "english_name": "R\\"T", "is_published": true, "master_zman_id": "d156b928-3c35-4360-acc9-f767fe425f18", "transliteration": "Rabbeinu Tam"}, {"is_beta": false, "category": "essential", "zman_key": "fast_begins", "is_custom": false, "is_enabled": true, "is_visible": true, "description": "End time for eating in the morning on a minor fast day. One who sleeps and then wakes must stop eating at this time.", "formula_dsl": "solar(12, before_sunrise)", "hebrew_name": "התחלת התענית", "source_type": "registry", "english_name": "Haschalas HaTaanis", "is_published": true, "master_zman_id": "a37ca4f4-a2a1-42d2-8d4e-4967e26707e8", "transliteration": "Haschalas HaTaanis", "publisher_comment": "Per Orach Chaim 564. Uses Dawn 2 (12°) as the cutoff."}], "version": 1, "description": "Version save - Dec 4, 2025 3:06 PM", "exported_at": "2025-12-04T15:06:13Z"}	user_35yX6LKszGc7misNhjGdU0eMeyQ	2025-12-04 15:06:13.712937+00
\.


--
-- Data for Name: publisher_zman_aliases; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_zman_aliases (id, publisher_id, publisher_zman_id, custom_hebrew_name, custom_english_name, custom_transliteration, is_active, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: publisher_zman_day_types; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_zman_day_types (publisher_zman_id, day_type_id, is_visible, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: publisher_zman_events; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_zman_events (id, publisher_zman_id, jewish_event_id, is_enabled, applies_to_day, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: publisher_zman_tags; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_zman_tags (publisher_zman_id, tag_id, created_at, is_negated) FROM stdin;
8bdb8225-9580-4df1-b477-93620e51cc30	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
1eb0ec06-eb8c-4a9b-a1b1-4370b8e76567	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
9d708db2-368b-44ec-8313-dd1aa8b4f30a	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
73e3f134-386d-4444-9903-23b65124afd0	a1000001-0001-0001-0001-000000000010	2025-12-04 13:38:56.19347+00	f
ebc33b7c-5b48-413a-85de-7e5b90b9a7df	a1000001-0001-0001-0001-000000000010	2025-12-04 13:38:56.19347+00	f
f4fbebfe-e045-43cc-82e7-13d8534c54d0	a1000001-0001-0001-0001-000000000010	2025-12-04 13:38:56.19347+00	f
0ecedb5a-dcf8-421f-9d28-8d833cc452a8	a1000001-0001-0001-0001-000000000001	2025-12-04 13:38:56.19347+00	f
0ecedb5a-dcf8-421f-9d28-8d833cc452a8	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
0ecedb5a-dcf8-421f-9d28-8d833cc452a8	a1000001-0001-0001-0001-000000000020	2025-12-04 13:38:56.19347+00	f
49c3d95d-2fcc-4dc6-a3e0-e6635adc1665	a1000001-0001-0001-0001-000000000002	2025-12-04 13:38:56.19347+00	f
49c3d95d-2fcc-4dc6-a3e0-e6635adc1665	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
49c3d95d-2fcc-4dc6-a3e0-e6635adc1665	a1000001-0001-0001-0001-000000000020	2025-12-04 13:38:56.19347+00	f
32b8ff59-4fe6-49ad-84ba-627ec4c8e6fb	a1000001-0001-0001-0001-000000000002	2025-12-04 13:38:56.19347+00	f
32b8ff59-4fe6-49ad-84ba-627ec4c8e6fb	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
32b8ff59-4fe6-49ad-84ba-627ec4c8e6fb	a1000001-0001-0001-0001-000000000020	2025-12-04 13:38:56.19347+00	f
9c62ca60-e8d1-4ad1-a0d7-7e80f0d414cc	a1000001-0001-0001-0001-000000000002	2025-12-04 13:38:56.19347+00	f
9c62ca60-e8d1-4ad1-a0d7-7e80f0d414cc	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
9c62ca60-e8d1-4ad1-a0d7-7e80f0d414cc	a1000001-0001-0001-0001-000000000020	2025-12-04 13:38:56.19347+00	f
37fccc09-c7bc-47b2-b956-106a6738007f	a1000001-0001-0001-0001-000000000001	2025-12-04 13:38:56.19347+00	f
37fccc09-c7bc-47b2-b956-106a6738007f	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
37fccc09-c7bc-47b2-b956-106a6738007f	a1000001-0001-0001-0001-000000000021	2025-12-04 13:38:56.19347+00	f
bd3c12c6-871a-49d4-bc57-df1716d1f556	a1000001-0001-0001-0001-000000000002	2025-12-04 13:38:56.19347+00	f
bd3c12c6-871a-49d4-bc57-df1716d1f556	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
bd3c12c6-871a-49d4-bc57-df1716d1f556	a1000001-0001-0001-0001-000000000021	2025-12-04 13:38:56.19347+00	f
17e87531-7ce6-4d79-aa20-8cbed95abada	a1000001-0001-0001-0001-000000000001	2025-12-04 13:38:56.19347+00	f
1c6e84f2-c916-4111-817b-f37195beaa28	a1000001-0001-0001-0001-000000000001	2025-12-04 13:38:56.19347+00	f
17e87531-7ce6-4d79-aa20-8cbed95abada	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
1c6e84f2-c916-4111-817b-f37195beaa28	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
17e87531-7ce6-4d79-aa20-8cbed95abada	a1000001-0001-0001-0001-000000000022	2025-12-04 13:38:56.19347+00	f
1c6e84f2-c916-4111-817b-f37195beaa28	a1000001-0001-0001-0001-000000000022	2025-12-04 13:38:56.19347+00	f
d79ae898-ea5c-43ec-8cfa-8c55b5774cb8	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
d79ae898-ea5c-43ec-8cfa-8c55b5774cb8	a1000001-0001-0001-0001-000000000022	2025-12-04 13:38:56.19347+00	f
2910fbc5-a95b-46c0-9188-d1bf4bc5f2ad	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
2910fbc5-a95b-46c0-9188-d1bf4bc5f2ad	a1000001-0001-0001-0001-000000000022	2025-12-04 13:38:56.19347+00	f
038f4390-8416-4f22-9ce3-7dff4c9cb8e1	a1000001-0001-0001-0001-000000000011	2025-12-04 13:38:56.19347+00	f
038f4390-8416-4f22-9ce3-7dff4c9cb8e1	a1000001-0001-0001-0001-000000000022	2025-12-04 13:38:56.19347+00	f
2f56205d-5999-4bc7-aeae-515493df8840	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-04 13:38:56.19347+00	f
2f56205d-5999-4bc7-aeae-515493df8840	348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	2025-12-04 13:38:56.19347+00	f
2f56205d-5999-4bc7-aeae-515493df8840	b8946537-0457-4f9f-9068-e07b2d389c0a	2025-12-04 13:38:56.19347+00	f
2f56205d-5999-4bc7-aeae-515493df8840	a1000001-0001-0001-0001-000000000010	2025-12-04 13:38:56.19347+00	f
77f0b621-a0c5-4e4d-872f-192b09ab66f0	3d9fe336-6850-441e-b3c9-7a77a9905f86	2025-12-04 13:38:56.19347+00	f
77f0b621-a0c5-4e4d-872f-192b09ab66f0	6c10a75d-ab64-46ee-b801-66fce7c75844	2025-12-04 13:38:56.19347+00	f
77f0b621-a0c5-4e4d-872f-192b09ab66f0	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
59c61574-1ff0-443e-bc0e-21bc44b8afa1	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-04 13:38:56.19347+00	f
59c61574-1ff0-443e-bc0e-21bc44b8afa1	e9783be0-7610-4441-ad36-ba24e980fcbd	2025-12-04 13:38:56.19347+00	f
59c61574-1ff0-443e-bc0e-21bc44b8afa1	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
255dad2e-9688-4e08-8a3f-357d1a85181a	e017a942-e640-4b48-8cc6-1fdd30164454	2025-12-04 13:38:56.19347+00	f
255dad2e-9688-4e08-8a3f-357d1a85181a	5059e4c2-2ccd-4a8c-9696-dc77de8bd4dd	2025-12-04 13:38:56.19347+00	f
255dad2e-9688-4e08-8a3f-357d1a85181a	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
6dfc0aea-53d0-4c41-997d-ea4592c969be	a1000001-0001-0001-0001-000000000012	2025-12-04 13:38:56.19347+00	f
663116dc-9430-4de0-9fae-52721a1d701a	a1000001-0001-0001-0001-000000000003	2025-12-04 13:38:56.19347+00	f
663116dc-9430-4de0-9fae-52721a1d701a	a1000001-0001-0001-0001-000000000010	2025-12-04 13:38:56.19347+00	f
\.


--
-- Data for Name: publisher_zman_versions; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_zman_versions (id, publisher_zman_id, version_number, formula_dsl, created_by, created_at) FROM stdin;
\.


--
-- Data for Name: publisher_zmanim; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publisher_zmanim (id, publisher_id, zman_key, hebrew_name, english_name, formula_dsl, ai_explanation, publisher_comment, is_enabled, is_visible, is_published, is_custom, category, dependencies, master_zman_id, current_version, deleted_at, deleted_by, created_at, updated_at, linked_publisher_zman_id, source_type, is_beta, certified_at, transliteration, description) FROM stdin;
321a278b-db4e-40a3-a9d7-804e85a372df	6c85458d-2225-4f55-bc15-5c9844bcf362	chatzos_layla	חצות לילה	Chatzos Layla	solar_noon + 12hr	\N	May vary by one minute from midday + 12 hours.	t	t	t	f	optional	{}	6af15b21-1fd8-4958-89d0-8e8df94c059f	1	\N	\N	2025-12-03 18:45:35.454587+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Chatzos Layla	Midnight - 12 hours after midday. Per Igros Moshe OC 2:20.
77f0b621-a0c5-4e4d-872f-192b09ab66f0	6c85458d-2225-4f55-bc15-5c9844bcf362	shabbos_ends	מוצש״ק	Motzei Shabbos	solar(8, after_sunset)	\N	\N	t	t	t	f	optional	{}	888f7113-4a77-44a1-aa1d-22cb297297a5	1	\N	\N	2025-12-03 18:45:35.462006+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Motzei Shabbos Kodesh	End of Shabbos when three small consecutive stars are visible. Sun 8° below horizon.
1eb0ec06-eb8c-4a9b-a1b1-4370b8e76567	6c85458d-2225-4f55-bc15-5c9844bcf362	alos_12	עלות השחר ב׳	Alos HaShachar 2	solar(12, before_sunrise)	\N	This has been the practice in the Manchester community for nearly 80 years since its founding. This is the PRIMARY dawn used for MGA calculations.	t	t	t	f	essential	{}	17a26364-11ca-4b16-9e29-18bdba18cf25	1	\N	\N	2025-12-04 12:47:00.466691+00	2025-12-04 13:58:02.935428+00	\N	registry	f	\N	Alos HaShachar Beis	Sun 12° below horizon. Per Minchas Yitzchak 9:9, this corresponds with reality in Northern Europe.
8bdb8225-9580-4df1-b477-93620e51cc30	6c85458d-2225-4f55-bc15-5c9844bcf362	misheyakir	משיכיר	Misheyakir	solar(11.5, before_sunrise)	\N	In pressing circumstances (e.g., traveling), one may put on tallis 2 degrees earlier.	t	t	t	f	essential	{}	fee6ae15-91bb-401d-be34-4a7256ed32cb	1	\N	\N	2025-12-03 18:45:35.468729+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Misheyakir	Earliest time for tallis and tefillin with a blessing. The printed time is 15 minutes after the actual misheyakir time.
d844f0a4-3b01-4cc8-a0a8-8226f7073c23	6c85458d-2225-4f55-bc15-5c9844bcf362	sunrise	הנץ	HaNetz	sunrise	\N	\N	t	t	t	f	essential	{}	10d89e97-e29b-4a0c-8775-04ccd6c15ba3	1	\N	\N	2025-12-03 18:45:35.467594+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	HaNetz	The time when the upper edge of the sun rises above the horizon at sea level.
1c6e84f2-c916-4111-817b-f37195beaa28	6c85458d-2225-4f55-bc15-5c9844bcf362	mincha_ketana	מנחה קטנה	Mincha Ketana	proportional_hours(9.5, gra)	\N	\N	t	t	t	f	essential	{}	8506c62a-2f48-42b4-a02f-0b18b8e8478c	1	\N	\N	2025-12-03 18:45:35.444716+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Mincha Ketana	Two and a half proportional hours before sunset.
255dad2e-9688-4e08-8a3f-357d1a85181a	6c85458d-2225-4f55-bc15-5c9844bcf362	fast_ends	סוף התענית	Sof HaTaanis	solar(7.08, after_sunset)	\N	\N	t	t	t	f	essential	{}	5873dd70-0a42-44e7-aba4-d0eeec0457a0	1	\N	\N	2025-12-03 18:45:35.463417+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Sof HaTaanis	End of fast. For rabbinic fasts, one may be lenient by several minutes.
2f56205d-5999-4bc7-aeae-515493df8840	6c85458d-2225-4f55-bc15-5c9844bcf362	candle_lighting	הדלקת נרות	Hadlakas Neiros	sunset - 15min	\N	15 minutes before sunset, as has been the custom from ancient times.	t	t	t	f	essential	{}	8b861617-e264-4542-a8db-01f7512cab7d	1	\N	\N	2025-12-03 18:45:35.470095+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Hadlakas Neiros	Time for lighting Shabbos candles and accepting Shabbos.
73e3f134-386d-4444-9903-23b65124afd0	6c85458d-2225-4f55-bc15-5c9844bcf362	alos_72	עלות 72 דק׳	Alos 72 min	sunrise - 72min	\N	For those whose custom it is. Some add in summer to account for mil being 22.5 min, making dawn 90 min before sunrise.	t	t	t	f	optional	{}	c2b8088d-da9f-4753-a245-eb2ba2346870	1	\N	\N	2025-12-04 12:47:16.535569+00	2025-12-04 16:13:04.050259+00	\N	registry	f	2025-12-04 16:12:31.275078+00	Alos 72 Dakos	72 fixed minutes before sunrise throughout the year.
ebc33b7c-5b48-413a-85de-7e5b90b9a7df	6c85458d-2225-4f55-bc15-5c9844bcf362	alos_90	עלות 90 דק׳	Alos 90 min	sunrise - 90min	\N	Some add in summer to account for the measure of a mil being 22.5 minutes.	t	t	t	f	optional	{}	ad46eeac-4a01-43f6-bb59-2e99c0c39824	1	\N	\N	2025-12-04 13:06:14.853364+00	2025-12-04 13:58:02.935428+00	\N	registry	f	\N	Alos 90 Dakos	90 fixed minutes before sunrise. For those who calculate a mil as 22.5 minutes (4 x 22.5 = 90).
2910fbc5-a95b-46c0-9188-d1bf4bc5f2ad	6c85458d-2225-4f55-bc15-5c9844bcf362	plag_hamincha_72	פלג - מ״א	Plag - MA	proportional_hours(10.75, mga)	\N	Since the time for accepting Shabbos, printed for the community.	t	t	t	f	optional	{}	cfbd81d7-dbc7-4108-b71e-2d9e33dd1a7e	1	\N	\N	2025-12-04 13:06:14.84155+00	2025-12-04 13:58:02.935428+00	\N	registry	f	\N	Plag HaMincha MA	Plag HaMincha according to MA/Terumas Hadeshen practiced in many communities. One and a quarter proportional hours before nightfall, calculating 72 minutes before sunrise to 72 minutes after sunset.
9d708db2-368b-44ec-8313-dd1aa8b4f30a	6c85458d-2225-4f55-bc15-5c9844bcf362	alos_hashachar	עלות השחר א׳	Alos HaShachar 1	if (month >= 5 && month <= 7 && latitude > 50) { solar_noon } else { solar(16.1, before_sunrise) }	\N	Per Vilna Gaon and Siddur of the Rav. 72 minutes before sunrise in Eretz Yisrael during Nissan/Tishrei. Used as stringency for nighttime mitzvos like evening Shema and counting of the Omer. In polar summer, midnight is used as the dawn time.	t	t	t	f	essential	{}	ada9beca-6052-4150-9d22-6a875582e3dc	1	\N	\N	2025-12-03 18:45:35.450501+00	2025-12-04 13:58:02.935428+00	\N	custom	f	2025-12-04 13:22:00.062041+00	Alos HaShachar Aleph	Sun 16.1° below horizon. In polar summer (May-July), the sun does not descend to 16.1° in Manchester, so midnight (chatzos layla) is printed as dawn.
49c3d95d-2fcc-4dc6-a3e0-e6635adc1665	6c85458d-2225-4f55-bc15-5c9844bcf362	sof_zman_shma_mga	ס״ז ק״ש-מג״א	Sof Zman K"Sh MGA	proportional_hours(3, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))	\N	On Shabbos, additional stringency times are printed from Dawn 1 (16.1°).	t	t	t	f	essential	{}	7faef612-5f93-4cb0-bf4d-b6ad67f22583	1	\N	\N	2025-12-03 18:45:35.457701+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Sof Zman Krias Shema MGA	Per Manchester Beth Din / Minchas Yitzchak using 12° dawn and 7.08° nightfall
f4fbebfe-e045-43cc-82e7-13d8534c54d0	6c85458d-2225-4f55-bc15-5c9844bcf362	alos_shemini_atzeres	עלות לערבות	Alos for Aravos	proportional_hours(-1.5, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))	\N	Printed by the Minchas Yitzchak as a stringency.	t	t	t	t	optional	{}	b0e714e8-59d1-45d1-bff5-14d16b958bd2	1	\N	\N	2025-12-04 13:05:52.341246+00	2025-12-04 16:11:43.287368+00	\N	custom	f	\N	Alos LaAravos	Dawn calculated as 1/8th of the day before sunrise, using the Manchester day definition (12° to 7.08°).
038f4390-8416-4f22-9ce3-7dff4c9cb8e1	6c85458d-2225-4f55-bc15-5c9844bcf362	plag_hamincha_terumas_hadeshen	פלג - תה״ד	Plag - T"HD	proportional_hours(10.75, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))	\N	Per Terumas Hadeshen method.	t	t	t	t	essential	{}	072070ad-c303-4f36-a7ab-f5fee318fafb	1	\N	\N	2025-12-04 12:48:02.128587+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Plag HaMincha Terumas HaDeshen	One and a quarter proportional hours before nightfall, calculating the day from Dawn 2 (12°) until nightfall (7.08°).
32b8ff59-4fe6-49ad-84ba-627ec4c8e6fb	6c85458d-2225-4f55-bc15-5c9844bcf362	sof_zman_shma_mga_16_1	ס״ז ק״ש מ״א (16.1°)	Sof Zman K"Sh MA (16.1°)	proportional_hours(3, custom(solar(16.1, before_sunrise), solar(16.1, after_sunset)))	\N	Printed on Shabbos as additional stringency for Torah-level Shema obligation.	t	t	t	t	optional	{}	b3be6f50-cc36-4e7d-aa69-fbf2fea26810	1	\N	\N	2025-12-04 12:48:31.96226+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Sof Zman Krias Shema MA 16.1	Stringency from Dawn 1 (16.1°) to nightfall at 16.1°, so beginning and end of day are equal.
9c62ca60-e8d1-4ad1-a0d7-7e80f0d414cc	6c85458d-2225-4f55-bc15-5c9844bcf362	sof_zman_shma_mga_72	ס״ז ק״ש מ״א (72)	Sof Zman K"Sh MA (72min)	proportional_hours(3, mga)	\N	Practiced in many communities.	t	t	t	f	optional	{}	6258387c-5dac-48cf-a500-49cd87786350	1	\N	\N	2025-12-04 12:48:31.974101+00	2025-12-04 13:58:02.935428+00	\N	registry	f	\N	Sof Zman Krias Shema MA 72	72 min before sunrise to 72 min after sunset. Always 36 minutes before GRA time.
0ecedb5a-dcf8-421f-9d28-8d833cc452a8	6c85458d-2225-4f55-bc15-5c9844bcf362	sof_zman_shma_gra	ס״ז ק״ש-גר״א	Sof Zman K"Sh GRA	proportional_hours(3, gra)	\N	\N	t	t	t	f	essential	{}	a03df06c-8cca-4115-9ff1-4bc04e759ffc	1	\N	\N	2025-12-03 18:45:35.456243+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Sof Zman Krias Shema GRA	Latest time for Shema according to Vilna Gaon and Rabbi Zalman. One quarter of the day from sunrise to sunset.
bd3c12c6-871a-49d4-bc57-df1716d1f556	6c85458d-2225-4f55-bc15-5c9844bcf362	sof_zman_tfila_mga	ס״ז תפלה-מג״א	Sof Zman Tefila MGA	proportional_hours(4, custom(solar(12, before_sunrise), solar(7.08, after_sunset)))	\N	For those using 72 min dawn, this is always 24 min before GRA time.	t	t	t	f	essential	{}	b32f320e-4fe5-4ba1-99db-78ad7b65cb66	1	\N	\N	2025-12-03 18:45:35.460404+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Sof Zman Tefila MGA	Per Manchester Beth Din / Minchas Yitzchak using 12° dawn and 7.08° nightfall
37fccc09-c7bc-47b2-b956-106a6738007f	6c85458d-2225-4f55-bc15-5c9844bcf362	sof_zman_tfila_gra	ס״ז תפלה-גר״א	Sof Zman Tefila GRA	proportional_hours(4, gra)	\N	\N	t	t	t	f	essential	{}	31ef5cc3-e541-4750-b78b-99840dc7a372	1	\N	\N	2025-12-03 18:45:35.459272+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Sof Zman Tefila GRA	Latest time for morning prayer according to Vilna Gaon. One third of the day from sunrise to sunset.
9184b075-21cb-47b7-93d9-d18a66497ab5	6c85458d-2225-4f55-bc15-5c9844bcf362	chatzos	חצות	Chatzos	solar_noon	\N	Per Igros Moshe, OC 2:20. May vary by one minute.	t	t	t	f	essential	{}	5c1806a7-5c5f-4231-8ea6-f2821a3f74ff	1	\N	\N	2025-12-03 18:45:35.451704+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Chatzos	The time when the sun stands at highest point between east and west. Half the time between sunrise and sunset. Midnight is 12 hours after.
17e87531-7ce6-4d79-aa20-8cbed95abada	6c85458d-2225-4f55-bc15-5c9844bcf362	mincha_gedola	מנחה גדולה	Mincha Gedola	solar_noon + 30min	\N	The practice is to be stringent - in winter when the proportional half-hour is less than 30 minutes, we use 30 minutes.	t	t	t	f	essential	{}	a56cc3c5-2210-4945-8c48-85cd0b48d936	1	\N	\N	2025-12-03 18:45:35.453415+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Mincha Gedola	Earliest time for afternoon prayer. Half a proportional hour after midday, but no less than 30 minutes.
d79ae898-ea5c-43ec-8cfa-8c55b5774cb8	6c85458d-2225-4f55-bc15-5c9844bcf362	plag_hamincha	פלג - לבוש	Plag - Levush	proportional_hours(10.75, gra)	\N	\N	t	t	t	f	essential	{}	b4e6778c-cb14-4fe5-b3e8-99c85a19606c	1	\N	\N	2025-12-03 18:45:35.448881+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Plag HaMincha Levush	Earliest time for Maariv, lighting Shabbos candles, and Chanukah candles. One and a quarter proportional hours before sunset.
dfb93983-67e7-4b89-ad7f-e39280256639	6c85458d-2225-4f55-bc15-5c9844bcf362	sunset	שקיעה	Shkiah	sunset	\N	\N	t	t	t	f	essential	{}	c92d8740-af5c-4298-a65d-ce5f64d76551	1	\N	\N	2025-12-03 18:45:35.47128+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Shkiah	The time when the sun is completely hidden from our eyes. Time printed is slightly before actual to be safe.
6dfc0aea-53d0-4c41-997d-ea4592c969be	6c85458d-2225-4f55-bc15-5c9844bcf362	tzais_7_08	צאת הכוכבים	Tzais HaKochavim	solar(7.08, after_sunset)	\N	For rabbinic fasts, one may be lenient by several minutes - consult a halachic authority.	t	t	t	f	essential	{}	7949f93d-c348-4e0c-99e9-743212ecb00b	1	\N	\N	2025-12-03 18:45:35.465013+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Tzais HaKochavim	Time when three small consecutive stars are visible. Sun 7.08° below horizon.
663116dc-9430-4de0-9fae-52721a1d701a	6c85458d-2225-4f55-bc15-5c9844bcf362	tzais_72	ר״ת	R"T	sunset + 72min	\N	\N	t	t	t	f	essential	{}	d156b928-3c35-4360-acc9-f767fe425f18	1	\N	\N	2025-12-03 18:45:35.466113+00	2025-12-04 13:58:02.935428+00	\N	custom	f	\N	Rabbeinu Tam	72 minutes after sunset throughout the year, provided sun is at least 8° below horizon.
59c61574-1ff0-443e-bc0e-21bc44b8afa1	6c85458d-2225-4f55-bc15-5c9844bcf362	fast_begins	התחלת התענית	Haschalas HaTaanis	solar(12, before_sunrise)	\N	Per Orach Chaim 564. Uses Dawn 2 (12°) as the cutoff.	t	t	t	f	essential	{}	a37ca4f4-a2a1-42d2-8d4e-4967e26707e8	1	\N	\N	2025-12-04 13:06:34.636345+00	2025-12-04 13:58:02.935428+00	\N	registry	f	\N	Haschalas HaTaanis	End time for eating in the morning on a minor fast day. One who sleeps and then wakes must stop eating at this time.
\.


--
-- Data for Name: publishers; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.publishers (id, name, email, phone, website, description, logo_url, location, latitude, longitude, timezone, status, verification_token, verified_at, clerk_user_id, is_published, created_at, updated_at, bio, slug, is_verified, logo_data, is_certified, suspension_reason, deleted_at, deleted_by) FROM stdin;
6c85458d-2225-4f55-bc15-5c9844bcf362	Machzikei Hadass - Manchester	dniasoff@gmail.com	\N	\N	Official zmanim publisher for Machzikei Hadass Manchester community. Calculations based on nearly 80 years of community practice following the rulings of Minchas Yitzchak and local minhag.	\N	\N	53.4808	-2.2426	Europe/London	active	\N	\N	\N	t	2025-12-03 16:13:33.070226+00	2025-12-04 18:26:08.776745+00	\N	machzikei-hadass-manchester	t	data:image/png;base64,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ubwDORcsCz+OyTkuoRdQ9QNamlrrmVMQKGTODLD1V/tobW0j9D1cN4/Upg7ruMYWo/686v/Zm2vydQNUabKgRsyb1lxBep5nAmnijKuimP7+fl557WW++c3TcF2XnXbaia9//esccsgh6IYyTVp6qVQq+L7PW2+9xbRp01i9ejXHHnssfX19tLa2cuyxx9aztkqlguM45PN5enp6sCzrE0GABnVZV1cXnudxxx138IMf/IARI0Zwww03cMABB9T7DKVSibvvvptvfOMb7LHHHtx5550sX76c2267jQ0bNvDzn/+ciRMn4jgOcRzT29vLgAED0Fqb555cyQPMmDGD7373u6xYsaKeXaTBKM3srrrqKi6//PJ6IEjRiWghva2zzjqLZ555hm984xucffbZ3H777Vx++eXsvvvuzJkzh+bmZqrVKrZts3jxYr773e+yePFidtppJ6688komTZrE0KFDUUkvLQ1yjaxfv56BAwcipWT9+vU0NzcTBAG+73PRRRdx1lln8dhjjzF37lzOO+889ttvP2zbZujQoehEAKKS/pxt27z//vs88MAD/P73v6dSqXD44Ydz5plnMn78+HqmQ5ItpisZ/9oRK4QgDiPjZSYApdBCJCsLku/RCtnwuUlezCtZGv8nwiBILGHMHFl6/yoKkLabzKoZ/zSFxBGYMnMcgu8Rd27C932qff18vHQZy5Z+yJo1a1i/Zg1+rYaITcbb399P4PkEgemTeJ5HzjGbYsv5HFYQoisVbDTtpWYcS1DtreLrmF4V0Ss0tLRywz13TN16vwM+09lOFnQ+xUv3//aH11/+nY52IbCrFaJaP3EcUWxpIogjpO3gK4UXRmaNdNKsVyrpmUiRvHkElVoVxzE1fsuy0FoRxsm0txb4YcTIrcYyYvQoBg0fythtt2brHSYwZoux0D7A+J1bieTEcur9GKUdZM7YWUTK2AahTJlOCIgijWNpIwWXmw8AFRlZTXoYpkFHC2W87upDeCIJU+D7oVmN67oEvk+lUqGtrY3nnnuOE088nlyuwKWXXsqJJ55YzzjyydrmSqVCuVyul6fSEpJSiqeffpprr72WMWPGcOedd9b7Mo1X7WkpqvEqOkjWAdjJvMurr77KWWedxeuvv84Xv/hFfvKTn7D11ltvPnySmZgwDDn//PO58847mTBhAl1dXXU1W0dHB4MGDcLzPArJds80a7ATK5xSqcTatWu54IILePjhh8klKw0uv/xyhg0bxne/+102btyI53nsuuuuzJkzh3K5bH73DaW7tCymlOKhhx7i6quv5u2332bnnXfmrbfeoq2tjd/97ndMnjw5eU2ZYGVZFt3d3dxyyy385Cc/IZfL8b3vfY+jjz6aMWPGfOJ2w0QRlwb8xsDR+HtdtGgRp59+Ovvuuy8//elPiRPxQPp9QaI+NK8DHyspc3qex9q1aznttNN4++23OeKII7j++uspl8t1RVsYhthpn+9TvZn0sZpSmjav6SQ7Mys6zMVKzrGMKqsxaCUlNykSyyyJed+pGBUbo7DU6xFpG4mWUpurC319LPv4Y9auXM4bLzzPe6+9zsrlK4iDEN/zII5wnBy2MFlv3t7cqyJO7N+TMrWSxtGhaNt4fX0MaW7B6+2lJB20Mv5ohZYmPMfCz9msjyK+89MfTd3zayd+poPOJ4uuGXx57z33fWPRH/dttgW17i5cNJKYUj5HHId4vme2+imFHStkHGHHEY6KsaIIEQVYYYClAsqWTV4r7CikgKaApCghH8dYUUjBkgS9vWxcvpxlb73Fy88/z5O/fZjH7n+A+b97lMrKNcRd3bRIGxkGxtJPGPM9FYeEYYDt2ub9Jc3BIHSMbaVDm4JQKaIoJIoCsAW2Zfoz5kBLhkSTA0HozWOjadnDlhI78ZGStkWuWOKVV17my0ceSXNTCzNnzmT//fevK7xqtRq5XA6RLCmr1Ux/plAo1N+8Qgja29tZtGgR69atY5dddmH48OH1gCITuXJ6m2kAiRsseJYuXcott9zCcccdR7FY5Hvf+x5XX301AwcOrB/SnuchkuHKjRs3sm7dOhYtWsTKlSvZcccdmT17NscccwylUgmZNPzjhgVuabBIg093dzd33nkna9asIQgCfvrTn3L++eczceJEdthhB+655x5Usvr6uOOOq9vaqIYZoPRg11ozevRoLrzwQoYMGcKvf/1roihixIgRnHDCCRSLxXrgcBILHCkl++67L4cccghLlizhjjvuYPbs2YwYMYLx48fXy3h2Q38lff7r1q2rz81YiZfb3XffzerVq7nssssYPXo0brKTSCTiirR3pxM5efocbNumubmZ448/nq6uLqZPn061WmXPPfekWCwiEzFHPvn/E8L0a9Kwkz7/OIwQQpmS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	f	\N	\N	\N
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.schema_migrations (version, applied_at) FROM stdin;
00000000000001_schema.sql	2025-12-03 16:12:57.89988+00
00000000000002_seed_data.sql	2025-12-03 16:12:58.012996+00
00000000000003_category_tables.sql	2025-12-03 20:01:03.08316+00
00000000000004_display_groups.sql	2025-12-03 20:49:33.343833+00
00000000000005_add_havdalah_entry.sql	2025-12-03 21:03:48.713457+00
00000000000006_algorithm_templates.sql	2025-12-03 21:03:48.776442+00
00000000000007_publisher_snapshots.sql	2025-12-04 14:02:09.793356+00
00000000000008_jewish_day_tags.sql	2025-12-04 14:41:25.738022+00
00000000000009_publisher_is_official.sql	2025-12-04 17:25:15.051949+00
00000000000010_publisher_suspension_reason.sql	2025-12-04 17:45:19.585108+00
00000000000011_publisher_soft_delete.sql	2025-12-04 17:49:50.680101+00
00000000000012_negated_tags.sql	2025-12-04 18:38:43.099541+00
00000000000013_rename_official_to_certified.sql	2025-12-05 00:51:44.895635+00
00000000000014_geo_boundaries.sql	2025-12-05 01:40:37.924061+00
00000000000015_uk_counties.sql	2025-12-05 02:30:15.738841+00
00000000000016_geo_nuclear_rebuild.sql	2025-12-05 03:57:42.303481+00
00000000000017_add_wof_id.sql	2025-12-05 04:56:52.114562+00
00000000000018_city_region_not_null.sql	2025-12-05 05:32:24.303993+00
00000000000019_continent_wof_id.sql	2025-12-05 05:32:24.369413+00
00000000000020_city_flexible_hierarchy.sql	2025-12-05 05:49:21.414142+00
00000000000021_continent_anchor_all_levels.sql	2025-12-05 06:04:18.785849+00
00000000000022_relax_hierarchy_constraints.sql	2025-12-05 06:14:06.129832+00
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: system_config; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.system_config (id, key, value, description, created_at, updated_at) FROM stdin;
189fbba5-8da7-4fda-9770-fc192a7d5b9f	publisher_registration	{"enabled": true, "require_approval": true}	Publisher registration settings	2025-12-03 16:12:57.939444+00	2025-12-03 16:12:57.939444+00
c063ed2b-8b6f-4ee4-af39-c0217b51ab32	default_algorithm_template	{"name": "Standard GRA", "description": "Default algorithm template based on GRA"}	Default algorithm template for new publishers	2025-12-03 16:12:57.939444+00	2025-12-03 16:12:57.939444+00
d955b64f-eac4-4781-bca8-ded24c6b07b1	cache_ttl	{"cities": 604800, "zmanim": 86400, "algorithms": 3600}	Cache TTL settings in seconds	2025-12-03 16:12:57.939444+00	2025-12-03 16:12:57.939444+00
2486c91d-db19-4e4f-90b4-b0e2e1cbe862	rate_limit_anonymous	{"requests_per_hour": 100}	Rate limit for anonymous API requests	2025-12-03 16:12:57.939444+00	2025-12-03 16:12:57.939444+00
049c2c66-2e56-49c2-aa83-9dcdef02a009	rate_limit_authenticated	{"requests_per_hour": 1000}	Rate limit for authenticated API requests	2025-12-03 16:12:57.939444+00	2025-12-03 16:12:57.939444+00
\.


--
-- Data for Name: tag_event_mappings; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.tag_event_mappings (id, tag_id, hebcal_event_pattern, hebrew_month, hebrew_day_start, hebrew_day_end, priority, created_at) FROM stdin;
1d034ade-5ada-48f3-8a40-83d8dcf8216b	1feaa67a-0113-4930-86e0-eaaca1d070e1	Yom Kippur	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
53aca048-0757-486c-8981-d6b9a258352b	191e5b1f-7183-43b2-93f8-c8c7dea23332	Tish'a B'Av	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
df8439b3-b28a-4728-aa2f-589bd16937b0	ac00968d-5d85-461f-bdf4-43705cae56e5	Pesach%	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
edfab8ea-59e7-4aa6-b392-839a237c7c85	4bf5debe-da76-40c2-a815-a0e11a709464	%day of the Omer	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
963775dc-6e71-46ac-91ee-5159e0494370	302870a5-17f2-41f9-b4ac-481adbe52422	Chanukah%	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
383bbc51-9f2d-411d-8c79-ad2ae47f13f2	8bb294a7-66e3-4a94-9acc-8e58212a88ff	Purim	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
5f4ef01a-698b-46d6-8448-aaa67464ea7e	8713dabe-b731-4eb3-84d4-6dac910a36e7	Shushan Purim	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
5eae5bd6-fbcc-471d-8fd2-535e8c8665f0	c71a0aaa-0476-434d-bf5f-bccc08c2e8fc	Ta'anit Esther	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
cdffd202-7194-4349-840b-23b073443d3a	49a4fae2-1604-4456-a560-09abf5ef3b70	Erev Pesach	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
8a270995-be13-4795-8bcf-26464c11dce4	1d191690-84c1-4c43-89b1-094e4764afe1	Pesach % (CH'M)	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
d10781d3-610d-48ab-9f97-55f0807f4dbb	368e1453-6c63-4882-9baa-6048f430c06c	Erev Shavuot	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
b8e10469-1a2d-4a65-8ebe-c2748e8f372d	d381713f-dfa4-46ba-9efc-24eb782b93e6	Shavuot%	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
2e50cb54-57ec-44b1-9efa-56809ae7c45b	e0fe3646-0a4d-4c64-8e5c-ada80aa603b7	Erev Rosh Hashana	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
01f39bbf-bdb3-46da-b6b3-14d95287c024	f6a0fb66-f459-48be-8b44-fe2f52ad225d	Rosh Hashana%	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
180369b5-c3ea-41d8-a3dd-42f278024707	64b6581c-c0f7-4346-aac4-2e758e10e531	Tzom Gedaliah	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
deee106c-46dc-4912-b472-a37f1d6f3837	d9f86bff-0b80-4a3e-b834-4b351794b310	Erev Yom Kippur	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
83008353-dc8a-4cd6-b87f-d885ecdb1d5d	c9231e0a-5458-41fe-bf9c-bd26a79a353d	Erev Sukkot	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
df9a162c-a501-4d7d-8e72-6fd6559951e9	913d1fb2-ffaf-4905-a515-08c1dd9ada52	Sukkot%	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
9206ef5c-a30b-4310-b024-4190d0d4ea0e	894e1790-17f6-40e3-8231-f888ec1832c2	Sukkot % (CH'M)	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
e0b78751-41a8-4489-a440-45297b44e9a0	bc628dac-715b-47ce-a34e-bc58e394090b	Sukkot VII (Hoshana Raba)	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
96e43b38-5cc4-4889-9a3e-90be8c606425	81865c20-30be-4fc1-8172-4d263bb3ae86	Shmini Atzeret	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
e74688c9-f4c3-456c-9e8d-c8883dd53258	66b44e12-2535-4269-b7a4-23de9602c300	Simchat Torah	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
d234e6e0-8d5a-4d1a-89c9-9807efb9cb89	2a9396fd-e00d-4f13-9cbd-bf60c665dbc8	Asara B'Tevet	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
e9b36e86-53b3-4dd8-8293-b901b410b6c0	049f5f38-4746-44fa-b2b5-381f646edd38	Shiva Asar B'Tamuz	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
5381783d-e0c1-48b5-bf59-29123e0316ac	6c5249f7-971b-48e9-8a2f-29fbaf1c5f03	Erev Tish'a B'Av	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
0f5cffd0-4fd0-48ba-81db-f12acaafaea4	d17c3cc6-5e57-4f99-b979-765fa2a78d78	Rosh Chodesh%	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
ec57eef9-a06d-41a7-be84-33b35a2dddfd	4ab63bdf-c41a-4c5e-b4a3-2663d2009187	Tu BiShvat	\N	\N	\N	100	2025-12-04 14:41:25.703164+00
5a3ee2f7-2d86-41c2-b757-6fed778bdbb8	3f0b5b4a-ab95-4c13-b8a0-966164001cb8	\N	6	25	29	50	2025-12-04 14:41:25.706669+00
7b0fe9fb-a593-4fc2-b753-93cf243379d9	99870a49-031f-4d13-a2e4-716159b60ca7	\N	7	1	10	50	2025-12-04 14:41:25.708344+00
58577c57-0760-46da-bb46-933a8ce3ae96	935e2362-dc26-4e27-becc-679c5a45bf78	\N	4	17	29	40	2025-12-04 14:41:25.709454+00
42fe1611-f855-43cb-b126-591c72a7c4ac	935e2362-dc26-4e27-becc-679c5a45bf78	\N	5	1	9	40	2025-12-04 14:41:25.710933+00
19b0dd7a-069a-4ff0-a16b-bd389efbdfbc	537c62ae-1e6b-41b9-bb76-03cc2b61e243	\N	5	1	9	50	2025-12-04 14:41:25.712412+00
\.


--
-- Data for Name: tag_types; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.tag_types (id, key, display_name_hebrew, display_name_english, color, sort_order, created_at) FROM stdin;
ba1295de-121f-4723-811d-8c290fd53d9b	timing	זמן	Time of Day	bg-green-500/10 text-green-700 border-green-300 dark:bg-green-500/20 dark:text-green-300 dark:border-green-700	1	2025-12-03 20:01:03.060171+00
859f7598-e5a4-421f-b683-fae972be29a2	event	אירוע	Event Type	bg-blue-500/10 text-blue-700 border-blue-300 dark:bg-blue-500/20 dark:text-blue-300 dark:border-blue-700	2	2025-12-03 20:01:03.060171+00
ad01607e-8ab6-4d1e-9f74-e5da9b2f7c8c	shita	שיטה	Shita (Halachic Opinion)	bg-cyan-500/10 text-cyan-700 border-cyan-300 dark:bg-cyan-500/20 dark:text-cyan-300 dark:border-cyan-700	3	2025-12-03 20:01:03.060171+00
b34974e3-3ad2-4ae5-a2fe-393f2728f127	method	שיטת חישוב	Calculation Method	bg-purple-500/10 text-purple-700 border-purple-300 dark:bg-purple-500/20 dark:text-purple-300 dark:border-purple-700	4	2025-12-03 20:01:03.060171+00
05d76adf-c140-46b8-9b13-61d1f2809da3	behavior	התנהגות	Behavior	bg-orange-500/10 text-orange-700 border-orange-300 dark:bg-orange-500/20 dark:text-orange-300 dark:border-orange-700	5	2025-12-03 20:01:03.060171+00
b3b43a94-4aad-465d-a714-ce34a563ff4c	category	קטגוריה	Category	bg-gray-500/10 text-gray-700 border-gray-300 dark:bg-gray-500/20 dark:text-gray-300 dark:border-gray-700	6	2025-12-03 20:01:03.060171+00
e51bdca1-45ca-463f-af63-119038a3582e	calculation	חישוב	Calculation	bg-indigo-500/10 text-indigo-700 border-indigo-300 dark:bg-indigo-500/20 dark:text-indigo-300 dark:border-indigo-700	7	2025-12-03 20:01:03.060171+00
\.


--
-- Data for Name: time_categories; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.time_categories (id, key, display_name_hebrew, display_name_english, description, icon_name, color, sort_order, is_everyday, created_at) FROM stdin;
22d99925-68e0-44d9-bb88-db836e6a046b	dawn	שחר	Dawn	Alos HaShachar variants	Sunrise	purple	1	t	2025-12-03 20:01:03.055034+00
bb0123a8-2b7b-4b47-af34-ba0e0bb4f84b	sunrise	זריחה	Sunrise	Sunrise and early morning	Sun	amber	2	t	2025-12-03 20:01:03.055034+00
433505ac-57b0-4a89-b533-0d53aa2f1fe5	morning	בוקר	Morning	Shema and Tefillah times	Clock	yellow	3	t	2025-12-03 20:01:03.055034+00
4f76ff4a-2975-4d72-84cb-096c32548c80	midday	צהריים	Midday	Chatzos and Mincha Gedolah	Sun	orange	4	t	2025-12-03 20:01:03.055034+00
2dd8f9e7-f9eb-4849-bb5e-407d9c3b0b86	afternoon	אחה"צ	Afternoon	Mincha and Plag times	Clock	rose	5	t	2025-12-03 20:01:03.055034+00
74e6c91a-557e-4c30-93b7-c36267483eed	sunset	שקיעה	Sunset	Shkiah	Sunset	rose	6	t	2025-12-03 20:01:03.055034+00
465ffe27-6970-454c-b787-c70daa1659a3	nightfall	צאת הכוכבים	Nightfall	Tzeis HaKochavim variants	Moon	indigo	7	t	2025-12-03 20:01:03.055034+00
69ae6946-675c-43f9-ade9-29bba9f5d1f7	midnight	חצות לילה	Midnight	Chatzos Layla	Moon	slate	8	t	2025-12-03 20:01:03.055034+00
\.


--
-- Data for Name: zman_display_contexts; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.zman_display_contexts (id, master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order, created_at) FROM stdin;
\.


--
-- Data for Name: zman_registry_requests; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.zman_registry_requests (id, publisher_id, requested_key, requested_hebrew_name, requested_english_name, requested_formula_dsl, time_category, status, reviewed_by, reviewed_at, reviewer_notes, created_at, transliteration, description, halachic_notes, halachic_source, publisher_email, publisher_name, auto_add_on_approval) FROM stdin;
\.


--
-- Data for Name: zman_request_tags; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.zman_request_tags (id, request_id, tag_id, requested_tag_name, requested_tag_type, is_new_tag_request, created_at) FROM stdin;
\.


--
-- Data for Name: zman_tags; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.zman_tags (id, tag_key, name, display_name_hebrew, display_name_english, tag_type, description, color, sort_order, created_at) FROM stdin;
3d9fe336-6850-441e-b3c9-7a77a9905f86	shabbos	shabbos	שבת	Shabbos	event	Applies to Shabbos	\N	10	2025-12-03 16:12:57.930617+00
348cdd17-1d15-44a0-be8f-0e08eb3fd9d3	yom_tov	yom_tov	יום טוב	Yom Tov	event	Applies to Yom Tov (major holidays)	\N	20	2025-12-03 16:12:57.930617+00
1feaa67a-0113-4930-86e0-eaaca1d070e1	yom_kippur	yom_kippur	יום כיפור	Yom Kippur	event	Applies to Yom Kippur	\N	30	2025-12-03 16:12:57.930617+00
e017a942-e640-4b48-8cc6-1fdd30164454	fast_day	fast_day	תענית	Fast Day	event	Applies to minor fast days	\N	40	2025-12-03 16:12:57.930617+00
191e5b1f-7183-43b2-93f8-c8c7dea23332	tisha_bav	tisha_bav	תשעה באב	Tisha B'Av	event	Applies to Tisha B'Av	\N	50	2025-12-03 16:12:57.930617+00
ac00968d-5d85-461f-bdf4-43705cae56e5	pesach	pesach	ערב פסח	Erev Pesach	event	Applies to Erev Pesach (chametz times)	\N	60	2025-12-03 16:12:57.930617+00
fe7d8d90-0161-45a1-94ca-9a9f9c8d5e78	day_before	day_before	יום לפני	Day Before	timing	Display on the day before the event (e.g., candle lighting)	\N	100	2025-12-03 16:12:57.930617+00
f5308ac8-cf95-4d73-9d44-f7e85fce6425	day_of	day_of	יום של	Day Of	timing	Display on the day of the event	\N	110	2025-12-03 16:12:57.930617+00
84b9580e-7adf-4bc1-9d22-5d9eacf296fd	night_after	night_after	לילה אחרי	Night After	timing	Display on the night after the event (e.g., havdalah)	\N	120	2025-12-03 16:12:57.930617+00
b8946537-0457-4f9f-9068-e07b2d389c0a	is_candle_lighting	is_candle_lighting	הדלקת נרות	Candle Lighting	behavior	This is a candle lighting time	\N	200	2025-12-03 16:12:57.930617+00
6c10a75d-ab64-46ee-b801-66fce7c75844	is_havdalah	is_havdalah	הבדלה	Havdalah	behavior	This is a havdalah/end of Shabbos time	\N	210	2025-12-03 16:12:57.930617+00
e9783be0-7610-4441-ad36-ba24e980fcbd	is_fast_start	is_fast_start	תחילת צום	Fast Begins	behavior	This marks when a fast begins	\N	220	2025-12-03 16:12:57.930617+00
5059e4c2-2ccd-4a8c-9696-dc77de8bd4dd	is_fast_end	is_fast_end	סוף צום	Fast Ends	behavior	This marks when a fast ends	\N	230	2025-12-03 16:12:57.930617+00
a1000001-0001-0001-0001-000000000001	shita_gra	shita_gra	גר"א	GRA (Vilna Gaon)	shita	Gaon of Vilna - day from sunrise to sunset	\N	10	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000002	shita_mga	shita_mga	מג"א	MGA (Magen Avraham)	shita	Magen Avraham - day from alos to tzais (72 min)	\N	20	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000003	shita_rt	shita_rt	ר"ת	Rabbeinu Tam	shita	Rabbeinu Tam - 72 minutes after sunset for nightfall	\N	30	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000004	shita_baal_hatanya	shita_baal_hatanya	בעל התניא	Baal HaTanya	shita	Shulchan Aruch HaRav (Chabad)	\N	40	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000005	shita_ateret_torah	shita_ateret_torah	עטרת תורה	Ateret Torah	shita	Chacham Yosef Harari-Raful (Sephardic)	\N	50	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000006	shita_geonim	shita_geonim	גאונים	Geonim	shita	Various Geonic opinions on nightfall degrees	\N	60	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000007	shita_yereim	shita_yereim	יראים	Yereim	shita	Sefer Yereim - bein hashmashos calculations	\N	70	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000010	calc_fixed	calc_fixed	זמן קבוע	Fixed Time	calculation	Fixed minute offset (not proportional)	\N	100	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000011	calc_zmanis	calc_zmanis	שעות זמניות	Proportional (Zmaniyos)	calculation	Proportional/seasonal minutes based on day length	\N	110	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000012	calc_degrees	calc_degrees	מעלות	Solar Degrees	calculation	Based on sun position in degrees below horizon	\N	120	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000020	category_shema	category_shema	קריאת שמע	Shema Times	category	Times related to Shema recitation	\N	200	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000021	category_tefila	category_tefila	תפילה	Prayer Times	category	Times related to prayer services	\N	210	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000022	category_mincha	category_mincha	מנחה	Mincha Times	category	Times related to afternoon prayer	\N	220	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000023	category_chametz	category_chametz	חמץ	Chametz Times	category	Times related to chametz on Erev Pesach	\N	230	2025-12-03 16:12:57.96179+00
a1000001-0001-0001-0001-000000000024	category_kiddush_levana	category_kiddush_levana	קידוש לבנה	Kiddush Levana	category	Times for sanctifying the moon	\N	240	2025-12-03 16:12:57.96179+00
4bf5debe-da76-40c2-a815-a0e11a709464	omer	omer	ספירת העומר	Sefirat HaOmer	jewish_day	During the Omer counting period (49 days)	\N	300	2025-12-04 14:41:25.682508+00
302870a5-17f2-41f9-b4ac-481adbe52422	chanukah	chanukah	חנוכה	Chanukah	jewish_day	Festival of Lights (8 days)	\N	310	2025-12-04 14:41:25.682508+00
8bb294a7-66e3-4a94-9acc-8e58212a88ff	purim	purim	פורים	Purim	jewish_day	Feast of Lots	\N	320	2025-12-04 14:41:25.682508+00
8713dabe-b731-4eb3-84d4-6dac910a36e7	shushan_purim	shushan_purim	שושן פורים	Shushan Purim	jewish_day	Purim in walled cities	\N	321	2025-12-04 14:41:25.682508+00
c71a0aaa-0476-434d-bf5f-bccc08c2e8fc	taanis_esther	taanis_esther	תענית אסתר	Taanis Esther	jewish_day	Fast of Esther	\N	322	2025-12-04 14:41:25.682508+00
49a4fae2-1604-4456-a560-09abf5ef3b70	erev_pesach	erev_pesach	ערב פסח	Erev Pesach	jewish_day	Day before Passover (chametz times)	\N	330	2025-12-04 14:41:25.682508+00
1d191690-84c1-4c43-89b1-094e4764afe1	chol_hamoed_pesach	chol_hamoed_pesach	חול המועד פסח	Chol HaMoed Pesach	jewish_day	Intermediate days of Pesach	\N	332	2025-12-04 14:41:25.682508+00
368e1453-6c63-4882-9baa-6048f430c06c	erev_shavuos	erev_shavuos	ערב שבועות	Erev Shavuos	jewish_day	Day before Shavuos	\N	340	2025-12-04 14:41:25.682508+00
d381713f-dfa4-46ba-9efc-24eb782b93e6	shavuos	shavuos	שבועות	Shavuos	jewish_day	Feast of Weeks	\N	341	2025-12-04 14:41:25.682508+00
3f0b5b4a-ab95-4c13-b8a0-966164001cb8	selichos	selichos	סליחות	Selichos	jewish_day	Penitential prayer period	\N	350	2025-12-04 14:41:25.682508+00
e0fe3646-0a4d-4c64-8e5c-ada80aa603b7	erev_rosh_hashanah	erev_rosh_hashanah	ערב ראש השנה	Erev Rosh Hashanah	jewish_day	Day before Rosh Hashanah	\N	351	2025-12-04 14:41:25.682508+00
f6a0fb66-f459-48be-8b44-fe2f52ad225d	rosh_hashanah	rosh_hashanah	ראש השנה	Rosh Hashanah	jewish_day	Jewish New Year (2 days)	\N	352	2025-12-04 14:41:25.682508+00
64b6581c-c0f7-4346-aac4-2e758e10e531	tzom_gedaliah	tzom_gedaliah	צום גדליה	Tzom Gedaliah	jewish_day	Fast of Gedaliah	\N	353	2025-12-04 14:41:25.682508+00
99870a49-031f-4d13-a2e4-716159b60ca7	aseres_yemei_teshuva	aseres_yemei_teshuva	עשרת ימי תשובה	Ten Days of Repentance	jewish_day	Period from RH to YK	\N	354	2025-12-04 14:41:25.682508+00
d9f86bff-0b80-4a3e-b834-4b351794b310	erev_yom_kippur	erev_yom_kippur	ערב יום כיפור	Erev Yom Kippur	jewish_day	Day before Yom Kippur	\N	355	2025-12-04 14:41:25.682508+00
c9231e0a-5458-41fe-bf9c-bd26a79a353d	erev_sukkos	erev_sukkos	ערב סוכות	Erev Sukkos	jewish_day	Day before Sukkos	\N	360	2025-12-04 14:41:25.682508+00
913d1fb2-ffaf-4905-a515-08c1dd9ada52	sukkos	sukkos	סוכות	Sukkos	jewish_day	Feast of Tabernacles	\N	361	2025-12-04 14:41:25.682508+00
894e1790-17f6-40e3-8231-f888ec1832c2	chol_hamoed_sukkos	chol_hamoed_sukkos	חול המועד סוכות	Chol HaMoed Sukkos	jewish_day	Intermediate days of Sukkos	\N	362	2025-12-04 14:41:25.682508+00
bc628dac-715b-47ce-a34e-bc58e394090b	hoshanah_rabbah	hoshanah_rabbah	הושענא רבה	Hoshanah Rabbah	jewish_day	7th day of Sukkos	\N	363	2025-12-04 14:41:25.682508+00
81865c20-30be-4fc1-8172-4d263bb3ae86	shemini_atzeres	shemini_atzeres	שמיני עצרת	Shemini Atzeres	jewish_day	8th day of assembly	\N	364	2025-12-04 14:41:25.682508+00
66b44e12-2535-4269-b7a4-23de9602c300	simchas_torah	simchas_torah	שמחת תורה	Simchas Torah	jewish_day	Rejoicing of the Torah (Diaspora: day 2)	\N	365	2025-12-04 14:41:25.682508+00
2a9396fd-e00d-4f13-9cbd-bf60c665dbc8	asarah_bteves	asarah_bteves	עשרה בטבת	Asarah B'Teves	jewish_day	10th of Teves fast	\N	370	2025-12-04 14:41:25.682508+00
049f5f38-4746-44fa-b2b5-381f646edd38	shiva_asar_btamuz	shiva_asar_btamuz	שבעה עשר בתמוז	Shiva Asar B'Tamuz	jewish_day	17th of Tamuz fast	\N	371	2025-12-04 14:41:25.682508+00
6c5249f7-971b-48e9-8a2f-29fbaf1c5f03	erev_tisha_bav	erev_tisha_bav	ערב תשעה באב	Erev Tisha B'Av	jewish_day	Day/night before Tisha B'Av	\N	373	2025-12-04 14:41:25.682508+00
935e2362-dc26-4e27-becc-679c5a45bf78	three_weeks	three_weeks	בין המצרים	The Three Weeks	jewish_day	Period between 17 Tamuz and 9 Av	\N	380	2025-12-04 14:41:25.682508+00
537c62ae-1e6b-41b9-bb76-03cc2b61e243	nine_days	nine_days	תשעת הימים	The Nine Days	jewish_day	First 9 days of Av	\N	381	2025-12-04 14:41:25.682508+00
d17c3cc6-5e57-4f99-b979-765fa2a78d78	rosh_chodesh	rosh_chodesh	ראש חודש	Rosh Chodesh	jewish_day	New Moon/Month	\N	390	2025-12-04 14:41:25.682508+00
4ab63bdf-c41a-4c5e-b4a3-2663d2009187	tu_bshvat	tu_bshvat	ט"ו בשבט	Tu B'Shvat	jewish_day	New Year for Trees	\N	391	2025-12-04 14:41:25.682508+00
\.


--
-- Data for Name: zmanim_templates; Type: TABLE DATA; Schema: public; Owner: zmanim
--

COPY public.zmanim_templates (id, zman_key, hebrew_name, english_name, formula_dsl, category, description, is_required, created_at, updated_at) FROM stdin;
a1c051a8-aae2-44b3-b6b1-4af02eac4419	alos_hashachar	עלות השחר	Alos Hashachar (Dawn)	solar(16.1, before_sunrise)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
4c5efb9a-0924-449f-ae30-0bdc946a2961	misheyakir	משיכיר	Misheyakir	solar(11.5, before_sunrise)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
c2c72a97-dca4-438b-b091-3d994dbc1262	sunrise	הנץ החמה	Sunrise	sunrise	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
67c2b01f-4f5b-4ab0-a9cf-d7afd8d6eafa	sof_zman_shma_gra	סוף זמן ק"ש גר"א	Latest Shema (GRA)	proportional_hours(3, gra)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
1b3234d7-685d-41cf-be71-a7c573f8d301	sof_zman_shma_mga	סוף זמן ק"ש מג"א	Latest Shema (MGA)	proportional_hours(3, mga)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
b273b840-649f-48cb-b8ce-ea9f43fd27ab	sof_zman_tfila_gra	סוף זמן תפילה גר"א	Latest Shacharit (GRA)	proportional_hours(4, gra)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
309d8eed-f819-4727-afd3-d8344e7d1a61	chatzos	חצות היום	Chatzos (Midday)	solar_noon	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
d330f82b-c977-4f11-b191-9f67bd27ef44	mincha_gedola	מנחה גדולה	Mincha Gedola	proportional_hours(6.5, gra)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
4483562c-9d1d-43b0-99a5-584f2bc252e5	mincha_ketana	מנחה קטנה	Mincha Ketana	proportional_hours(9.5, gra)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
0b19e9ea-7c4f-4097-b6ed-1a3373331fa1	plag_hamincha	פלג המנחה	Plag HaMincha	proportional_hours(10.75, gra)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
b151c82f-ee68-4964-b0e3-590cac3270d9	sunset	שקיעה	Sunset	sunset	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
031877e8-f874-4771-8e11-af8b97e24264	tzais	צאת הכוכבים	Tzais (Nightfall)	solar(8.5, after_sunset)	essential	\N	t	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
a4a6e4d6-46bf-4fdb-9a52-b3a76bfa8679	sof_zman_tfila_mga	סוף זמן תפילה מג"א	Latest Shacharit (MGA)	proportional_hours(4, mga)	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
792767d2-995c-44bc-ac6a-e642a040505f	alos_72	עלות 72 דקות	Alos 72 Minutes	sunrise - 72min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
f8e11423-31e9-4f5c-926b-dedfb2b962c9	alos_90	עלות 90 דקות	Alos 90 Minutes	sunrise - 90min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
d415bbb9-3669-4155-9172-10c2ffa81a4a	alos_120	עלות 120 דקות	Alos 120 Minutes	sunrise - 120min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
3d180243-33c7-4641-bebc-5b18f31c3a86	tzais_72	צאת ר"ת	Tzais Rabbeinu Tam (72 min)	sunset + 72min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
80bf153a-a555-4a46-a1e6-26c83607ba43	tzais_42	צאת 42 דקות	Tzais 42 Minutes	sunset + 42min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
f171485b-3618-4c7f-8920-64c456b59c23	tzais_50	צאת 50 דקות	Tzais 50 Minutes	sunset + 50min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
537d4e02-04f2-498f-9b0d-4e213e1bee3b	tzais_3_stars	צאת 3 כוכבים	Tzais 3 Stars	solar(8.5, after_sunset)	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
bb4185fd-37e3-4fb8-b6e8-77b6bcd6d415	candle_lighting	הדלקת נרות	Candle Lighting	sunset - 18min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
ef9a81d9-02af-43cc-bc59-30f75f2d5a38	candle_lighting_20	הדלקת נרות (ירושלים)	Candle Lighting (Jerusalem)	sunset - 20min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
197a2a64-2713-4007-8114-ebaa390c8386	candle_lighting_40	הדלקת נרות (40 דקות)	Candle Lighting (40 min)	sunset - 40min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
f01e769b-3601-497d-8895-b1fc900a5874	shkia_amitis	שקיעה אמיתית	True Sunset	sunset	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
b82c1329-0aea-40b5-b069-10f34e8639a5	chatzos_layla	חצות לילה	Chatzos Layla (Midnight)	solar_noon + 12hr	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
4b10aefe-55cb-4a10-9788-65f543fa5b68	samuch_lmincha	סמוך למנחה קטנה	Samuch L'Mincha Ketana	proportional_hours(9, gra)	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
5bf2560e-dafe-4759-83a3-4e792233eb61	bein_hashmashos	בין השמשות	Bein Hashmashos	sunset	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
533c5b41-3ba1-438f-8bb2-56fe0f2784a3	kiddush_levana_earliest	קידוש לבנה מוקדם	Earliest Kiddush Levana	sunset + 72min	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
84ceffa1-2a3b-4a8d-8f9d-aa60bc660f09	kiddush_levana_latest	סוף קידוש לבנה	Latest Kiddush Levana	sunset	optional	\N	f	2025-12-03 16:12:57.938014+00	2025-12-03 16:12:57.938014+00
\.


--
-- Name: ai_index_status_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.ai_index_status_id_seq', 1, false);


--
-- Name: geo_boundary_imports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.geo_boundary_imports_id_seq', 190, true);


--
-- Name: geo_continents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.geo_continents_id_seq', 120, true);


--
-- Name: geo_countries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.geo_countries_id_seq', 3159, true);


--
-- Name: geo_districts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.geo_districts_id_seq', 265870, true);


--
-- Name: geo_name_mappings_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.geo_name_mappings_id_seq', 1, false);


--
-- Name: geo_regions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: zmanim
--

SELECT pg_catalog.setval('public.geo_regions_id_seq', 48345, true);


--
-- Name: ai_audit_logs ai_audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.ai_audit_logs
    ADD CONSTRAINT ai_audit_logs_pkey PRIMARY KEY (id);


--
-- Name: ai_index_status ai_index_status_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.ai_index_status
    ADD CONSTRAINT ai_index_status_pkey PRIMARY KEY (id);


--
-- Name: ai_index_status ai_index_status_source_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.ai_index_status
    ADD CONSTRAINT ai_index_status_source_key UNIQUE (source);


--
-- Name: algorithm_templates algorithm_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.algorithm_templates
    ADD CONSTRAINT algorithm_templates_pkey PRIMARY KEY (id);


--
-- Name: algorithm_templates algorithm_templates_template_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.algorithm_templates
    ADD CONSTRAINT algorithm_templates_template_key_key UNIQUE (template_key);


--
-- Name: algorithms algorithms_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.algorithms
    ADD CONSTRAINT algorithms_pkey PRIMARY KEY (id);


--
-- Name: astronomical_primitives astronomical_primitives_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.astronomical_primitives
    ADD CONSTRAINT astronomical_primitives_pkey PRIMARY KEY (id);


--
-- Name: astronomical_primitives astronomical_primitives_variable_name_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.astronomical_primitives
    ADD CONSTRAINT astronomical_primitives_variable_name_key UNIQUE (variable_name);


--
-- Name: cities cities_geonameid_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_geonameid_key UNIQUE (geonameid);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: cities cities_wof_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_wof_id_key UNIQUE (wof_id);


--
-- Name: day_types day_types_name_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.day_types
    ADD CONSTRAINT day_types_name_key UNIQUE (name);


--
-- Name: day_types day_types_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.day_types
    ADD CONSTRAINT day_types_pkey PRIMARY KEY (id);


--
-- Name: display_groups display_groups_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.display_groups
    ADD CONSTRAINT display_groups_key_key UNIQUE (key);


--
-- Name: display_groups display_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.display_groups
    ADD CONSTRAINT display_groups_pkey PRIMARY KEY (id);


--
-- Name: embeddings embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.embeddings
    ADD CONSTRAINT embeddings_pkey PRIMARY KEY (id);


--
-- Name: embeddings embeddings_source_chunk_index_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.embeddings
    ADD CONSTRAINT embeddings_source_chunk_index_key UNIQUE (source, chunk_index);


--
-- Name: event_categories event_categories_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT event_categories_key_key UNIQUE (key);


--
-- Name: event_categories event_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT event_categories_pkey PRIMARY KEY (id);


--
-- Name: explanation_cache explanation_cache_formula_hash_language_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.explanation_cache
    ADD CONSTRAINT explanation_cache_formula_hash_language_key UNIQUE (formula_hash, language);


--
-- Name: explanation_cache explanation_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.explanation_cache
    ADD CONSTRAINT explanation_cache_pkey PRIMARY KEY (id);


--
-- Name: geo_boundary_imports geo_boundary_imports_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_boundary_imports
    ADD CONSTRAINT geo_boundary_imports_pkey PRIMARY KEY (id);


--
-- Name: geo_continents geo_continents_code_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_continents
    ADD CONSTRAINT geo_continents_code_key UNIQUE (code);


--
-- Name: geo_continents geo_continents_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_continents
    ADD CONSTRAINT geo_continents_pkey PRIMARY KEY (id);


--
-- Name: geo_continents geo_continents_wof_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_continents
    ADD CONSTRAINT geo_continents_wof_id_key UNIQUE (wof_id);


--
-- Name: geo_countries geo_countries_code_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_countries
    ADD CONSTRAINT geo_countries_code_key UNIQUE (code);


--
-- Name: geo_countries geo_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_countries
    ADD CONSTRAINT geo_countries_pkey PRIMARY KEY (id);


--
-- Name: geo_countries geo_countries_wof_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_countries
    ADD CONSTRAINT geo_countries_wof_id_key UNIQUE (wof_id);


--
-- Name: geo_country_boundaries geo_country_boundaries_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_country_boundaries
    ADD CONSTRAINT geo_country_boundaries_pkey PRIMARY KEY (country_id);


--
-- Name: geo_district_boundaries geo_district_boundaries_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_district_boundaries
    ADD CONSTRAINT geo_district_boundaries_pkey PRIMARY KEY (district_id);


--
-- Name: geo_districts geo_districts_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_districts
    ADD CONSTRAINT geo_districts_pkey PRIMARY KEY (id);


--
-- Name: geo_districts geo_districts_region_id_code_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_districts
    ADD CONSTRAINT geo_districts_region_id_code_key UNIQUE (region_id, code);


--
-- Name: geo_districts geo_districts_wof_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_districts
    ADD CONSTRAINT geo_districts_wof_id_key UNIQUE (wof_id);


--
-- Name: geo_name_mappings geo_name_mappings_level_source_source_name_source_country_c_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_name_mappings
    ADD CONSTRAINT geo_name_mappings_level_source_source_name_source_country_c_key UNIQUE (level, source, source_name, source_country_code);


--
-- Name: geo_name_mappings geo_name_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_name_mappings
    ADD CONSTRAINT geo_name_mappings_pkey PRIMARY KEY (id);


--
-- Name: geo_region_boundaries geo_region_boundaries_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_region_boundaries
    ADD CONSTRAINT geo_region_boundaries_pkey PRIMARY KEY (region_id);


--
-- Name: geo_regions geo_regions_country_id_code_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_regions
    ADD CONSTRAINT geo_regions_country_id_code_key UNIQUE (country_id, code);


--
-- Name: geo_regions geo_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_regions
    ADD CONSTRAINT geo_regions_pkey PRIMARY KEY (id);


--
-- Name: geo_regions geo_regions_wof_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_regions
    ADD CONSTRAINT geo_regions_wof_id_key UNIQUE (wof_id);


--
-- Name: jewish_events jewish_events_code_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.jewish_events
    ADD CONSTRAINT jewish_events_code_key UNIQUE (code);


--
-- Name: jewish_events jewish_events_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.jewish_events
    ADD CONSTRAINT jewish_events_pkey PRIMARY KEY (id);


--
-- Name: master_zman_day_types master_zman_day_types_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_day_types
    ADD CONSTRAINT master_zman_day_types_pkey PRIMARY KEY (master_zman_id, day_type_id);


--
-- Name: master_zman_events master_zman_events_master_zman_id_jewish_event_id_applies_t_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_events
    ADD CONSTRAINT master_zman_events_master_zman_id_jewish_event_id_applies_t_key UNIQUE (master_zman_id, jewish_event_id, applies_to_day);


--
-- Name: master_zman_events master_zman_events_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_events
    ADD CONSTRAINT master_zman_events_pkey PRIMARY KEY (id);


--
-- Name: master_zman_tags master_zman_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_tags
    ADD CONSTRAINT master_zman_tags_pkey PRIMARY KEY (master_zman_id, tag_id);


--
-- Name: master_zmanim_registry master_zmanim_registry_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zmanim_registry
    ADD CONSTRAINT master_zmanim_registry_pkey PRIMARY KEY (id);


--
-- Name: master_zmanim_registry master_zmanim_registry_zman_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zmanim_registry
    ADD CONSTRAINT master_zmanim_registry_zman_key_key UNIQUE (zman_key);


--
-- Name: password_reset_tokens password_reset_tokens_email_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_email_key UNIQUE (email);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (id);


--
-- Name: publisher_coverage publisher_coverage_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_coverage
    ADD CONSTRAINT publisher_coverage_pkey PRIMARY KEY (id);


--
-- Name: publisher_invitations publisher_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_invitations
    ADD CONSTRAINT publisher_invitations_pkey PRIMARY KEY (id);


--
-- Name: publisher_invitations publisher_invitations_token_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_invitations
    ADD CONSTRAINT publisher_invitations_token_key UNIQUE (token);


--
-- Name: publisher_onboarding publisher_onboarding_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_onboarding
    ADD CONSTRAINT publisher_onboarding_pkey PRIMARY KEY (id);


--
-- Name: publisher_onboarding publisher_onboarding_publisher_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_onboarding
    ADD CONSTRAINT publisher_onboarding_publisher_id_key UNIQUE (publisher_id);


--
-- Name: publisher_requests publisher_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_requests
    ADD CONSTRAINT publisher_requests_pkey PRIMARY KEY (id);


--
-- Name: publisher_snapshots publisher_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_snapshots
    ADD CONSTRAINT publisher_snapshots_pkey PRIMARY KEY (id);


--
-- Name: publisher_zman_aliases publisher_zman_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_aliases
    ADD CONSTRAINT publisher_zman_aliases_pkey PRIMARY KEY (id);


--
-- Name: publisher_zman_aliases publisher_zman_aliases_publisher_id_publisher_zman_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_aliases
    ADD CONSTRAINT publisher_zman_aliases_publisher_id_publisher_zman_id_key UNIQUE (publisher_id, publisher_zman_id);


--
-- Name: publisher_zman_day_types publisher_zman_day_types_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_day_types
    ADD CONSTRAINT publisher_zman_day_types_pkey PRIMARY KEY (publisher_zman_id, day_type_id);


--
-- Name: publisher_zman_events publisher_zman_events_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_events
    ADD CONSTRAINT publisher_zman_events_pkey PRIMARY KEY (id);


--
-- Name: publisher_zman_events publisher_zman_events_publisher_zman_id_jewish_event_id_app_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_events
    ADD CONSTRAINT publisher_zman_events_publisher_zman_id_jewish_event_id_app_key UNIQUE (publisher_zman_id, jewish_event_id, applies_to_day);


--
-- Name: publisher_zman_tags publisher_zman_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_tags
    ADD CONSTRAINT publisher_zman_tags_pkey PRIMARY KEY (publisher_zman_id, tag_id);


--
-- Name: publisher_zman_versions publisher_zman_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_versions
    ADD CONSTRAINT publisher_zman_versions_pkey PRIMARY KEY (id);


--
-- Name: publisher_zman_versions publisher_zman_versions_publisher_zman_id_version_number_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_versions
    ADD CONSTRAINT publisher_zman_versions_publisher_zman_id_version_number_key UNIQUE (publisher_zman_id, version_number);


--
-- Name: publisher_zmanim publisher_zmanim_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zmanim
    ADD CONSTRAINT publisher_zmanim_pkey PRIMARY KEY (id);


--
-- Name: publisher_zmanim publisher_zmanim_publisher_id_zman_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zmanim
    ADD CONSTRAINT publisher_zmanim_publisher_id_zman_key_key UNIQUE (publisher_id, zman_key);


--
-- Name: publishers publishers_clerk_user_id_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_clerk_user_id_key UNIQUE (clerk_user_id);


--
-- Name: publishers publishers_email_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_email_key UNIQUE (email);


--
-- Name: publishers publishers_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publishers_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: system_config system_config_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.system_config
    ADD CONSTRAINT system_config_key_key UNIQUE (key);


--
-- Name: system_config system_config_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.system_config
    ADD CONSTRAINT system_config_pkey PRIMARY KEY (id);


--
-- Name: tag_event_mappings tag_event_mappings_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.tag_event_mappings
    ADD CONSTRAINT tag_event_mappings_pkey PRIMARY KEY (id);


--
-- Name: tag_types tag_types_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.tag_types
    ADD CONSTRAINT tag_types_key_key UNIQUE (key);


--
-- Name: tag_types tag_types_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.tag_types
    ADD CONSTRAINT tag_types_pkey PRIMARY KEY (id);


--
-- Name: time_categories time_categories_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.time_categories
    ADD CONSTRAINT time_categories_key_key UNIQUE (key);


--
-- Name: time_categories time_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.time_categories
    ADD CONSTRAINT time_categories_pkey PRIMARY KEY (id);


--
-- Name: zman_display_contexts zman_display_contexts_master_zman_id_context_code_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_display_contexts
    ADD CONSTRAINT zman_display_contexts_master_zman_id_context_code_key UNIQUE (master_zman_id, context_code);


--
-- Name: zman_display_contexts zman_display_contexts_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_display_contexts
    ADD CONSTRAINT zman_display_contexts_pkey PRIMARY KEY (id);


--
-- Name: zman_registry_requests zman_registry_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_registry_requests
    ADD CONSTRAINT zman_registry_requests_pkey PRIMARY KEY (id);


--
-- Name: zman_request_tags zman_request_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_request_tags
    ADD CONSTRAINT zman_request_tags_pkey PRIMARY KEY (id);


--
-- Name: zman_tags zman_tags_name_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_tags
    ADD CONSTRAINT zman_tags_name_key UNIQUE (name);


--
-- Name: zman_tags zman_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_tags
    ADD CONSTRAINT zman_tags_pkey PRIMARY KEY (id);


--
-- Name: zman_tags zman_tags_tag_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_tags
    ADD CONSTRAINT zman_tags_tag_key_key UNIQUE (tag_key);


--
-- Name: zmanim_templates zmanim_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zmanim_templates
    ADD CONSTRAINT zmanim_templates_pkey PRIMARY KEY (id);


--
-- Name: zmanim_templates zmanim_templates_zman_key_key; Type: CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zmanim_templates
    ADD CONSTRAINT zmanim_templates_zman_key_key UNIQUE (zman_key);


--
-- Name: embeddings_content_type_idx; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX embeddings_content_type_idx ON public.embeddings USING btree (content_type);


--
-- Name: embeddings_source_idx; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX embeddings_source_idx ON public.embeddings USING btree (source);


--
-- Name: embeddings_vector_idx; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX embeddings_vector_idx ON public.embeddings USING ivfflat (embedding public.vector_cosine_ops) WITH (lists='100');


--
-- Name: idx_ai_audit_created; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_ai_audit_created ON public.ai_audit_logs USING btree (created_at DESC);


--
-- Name: idx_ai_audit_publisher; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_ai_audit_publisher ON public.ai_audit_logs USING btree (publisher_id);


--
-- Name: idx_ai_audit_success; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_ai_audit_success ON public.ai_audit_logs USING btree (success);


--
-- Name: idx_ai_audit_type; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_ai_audit_type ON public.ai_audit_logs USING btree (request_type);


--
-- Name: idx_ai_audit_user; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_ai_audit_user ON public.ai_audit_logs USING btree (user_id);


--
-- Name: idx_algorithm_templates_active; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithm_templates_active ON public.algorithm_templates USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_algorithm_templates_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithm_templates_key ON public.algorithm_templates USING btree (template_key);


--
-- Name: idx_algorithms_forked_from; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithms_forked_from ON public.algorithms USING btree (forked_from) WHERE (forked_from IS NOT NULL);


--
-- Name: idx_algorithms_public; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithms_public ON public.algorithms USING btree (is_public) WHERE (is_public = true);


--
-- Name: idx_algorithms_publisher_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithms_publisher_id ON public.algorithms USING btree (publisher_id);


--
-- Name: idx_algorithms_publisher_status; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithms_publisher_status ON public.algorithms USING btree (publisher_id, status);


--
-- Name: idx_algorithms_publisher_status_created; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithms_publisher_status_created ON public.algorithms USING btree (publisher_id, status, created_at DESC);


--
-- Name: idx_algorithms_status; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_algorithms_status ON public.algorithms USING btree (status);


--
-- Name: idx_astronomical_primitives_category; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_astronomical_primitives_category ON public.astronomical_primitives USING btree (category);


--
-- Name: idx_astronomical_primitives_variable_name; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_astronomical_primitives_variable_name ON public.astronomical_primitives USING btree (variable_name);


--
-- Name: idx_cities_continent_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_continent_id ON public.cities USING btree (continent_id);


--
-- Name: idx_cities_country_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_country_id ON public.cities USING btree (country_id);


--
-- Name: idx_cities_district; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_district ON public.cities USING btree (district_id);


--
-- Name: idx_cities_location; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_location ON public.cities USING gist (location);


--
-- Name: idx_cities_name_ascii_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_name_ascii_trgm ON public.cities USING gin (name_ascii public.gin_trgm_ops);


--
-- Name: idx_cities_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_name_trgm ON public.cities USING gin (name public.gin_trgm_ops);


--
-- Name: idx_cities_population; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_population ON public.cities USING btree (population DESC NULLS LAST);


--
-- Name: idx_cities_region; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_region ON public.cities USING btree (region_id);


--
-- Name: idx_cities_region_population; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_region_population ON public.cities USING btree (region_id, population DESC NULLS LAST, name) WHERE (region_id IS NOT NULL);


--
-- Name: idx_cities_wof_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_cities_wof_id ON public.cities USING btree (wof_id) WHERE (wof_id IS NOT NULL);


--
-- Name: idx_country_boundaries_centroid; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_country_boundaries_centroid ON public.geo_country_boundaries USING gist (centroid);


--
-- Name: idx_country_boundaries_geom; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_country_boundaries_geom ON public.geo_country_boundaries USING gist (boundary);


--
-- Name: idx_country_boundaries_simplified; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_country_boundaries_simplified ON public.geo_country_boundaries USING gist (boundary_simplified);


--
-- Name: idx_day_types_name; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_day_types_name ON public.day_types USING btree (name);


--
-- Name: idx_day_types_parent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_day_types_parent ON public.day_types USING btree (parent_type);


--
-- Name: idx_display_groups_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_display_groups_key ON public.display_groups USING btree (key);


--
-- Name: idx_display_groups_sort; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_display_groups_sort ON public.display_groups USING btree (sort_order);


--
-- Name: idx_district_boundaries_centroid; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_district_boundaries_centroid ON public.geo_district_boundaries USING gist (centroid);


--
-- Name: idx_district_boundaries_geom; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_district_boundaries_geom ON public.geo_district_boundaries USING gist (boundary);


--
-- Name: idx_district_boundaries_simplified; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_district_boundaries_simplified ON public.geo_district_boundaries USING gist (boundary_simplified);


--
-- Name: idx_event_categories_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_event_categories_key ON public.event_categories USING btree (key);


--
-- Name: idx_event_categories_sort; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_event_categories_sort ON public.event_categories USING btree (sort_order);


--
-- Name: idx_explanation_cache_expiry; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_explanation_cache_expiry ON public.explanation_cache USING btree (expires_at);


--
-- Name: idx_explanation_cache_lookup; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_explanation_cache_lookup ON public.explanation_cache USING btree (formula_hash, language);


--
-- Name: idx_geo_continents_wof_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_continents_wof_id ON public.geo_continents USING btree (wof_id) WHERE (wof_id IS NOT NULL);


--
-- Name: idx_geo_countries_continent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_countries_continent ON public.geo_countries USING btree (continent_id);


--
-- Name: idx_geo_countries_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_countries_name_trgm ON public.geo_countries USING gin (name public.gin_trgm_ops);


--
-- Name: idx_geo_countries_wof_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_countries_wof_id ON public.geo_countries USING btree (wof_id) WHERE (wof_id IS NOT NULL);


--
-- Name: idx_geo_districts_continent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_districts_continent ON public.geo_districts USING btree (continent_id);


--
-- Name: idx_geo_districts_country; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_districts_country ON public.geo_districts USING btree (country_id);


--
-- Name: idx_geo_districts_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_districts_name_trgm ON public.geo_districts USING gin (name public.gin_trgm_ops);


--
-- Name: idx_geo_districts_region; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_districts_region ON public.geo_districts USING btree (region_id);


--
-- Name: idx_geo_districts_wof_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_districts_wof_id ON public.geo_districts USING btree (wof_id) WHERE (wof_id IS NOT NULL);


--
-- Name: idx_geo_regions_continent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_regions_continent ON public.geo_regions USING btree (continent_id);


--
-- Name: idx_geo_regions_country; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_regions_country ON public.geo_regions USING btree (country_id);


--
-- Name: idx_geo_regions_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_regions_name_trgm ON public.geo_regions USING gin (name public.gin_trgm_ops);


--
-- Name: idx_geo_regions_wof_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_geo_regions_wof_id ON public.geo_regions USING btree (wof_id) WHERE (wof_id IS NOT NULL);


--
-- Name: idx_jewish_events_code; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_jewish_events_code ON public.jewish_events USING btree (code);


--
-- Name: idx_jewish_events_parent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_jewish_events_parent ON public.jewish_events USING btree (parent_event_code);


--
-- Name: idx_jewish_events_type; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_jewish_events_type ON public.jewish_events USING btree (event_type);


--
-- Name: idx_master_registry_category; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_registry_category ON public.master_zmanim_registry USING btree (time_category);


--
-- Name: idx_master_registry_english_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_registry_english_name_trgm ON public.master_zmanim_registry USING gin (canonical_english_name public.gin_trgm_ops);


--
-- Name: idx_master_registry_hebrew_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_registry_hebrew_name_trgm ON public.master_zmanim_registry USING gin (canonical_hebrew_name public.gin_trgm_ops);


--
-- Name: idx_master_registry_hidden; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_registry_hidden ON public.master_zmanim_registry USING btree (is_hidden);


--
-- Name: idx_master_registry_transliteration_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_registry_transliteration_trgm ON public.master_zmanim_registry USING gin (transliteration public.gin_trgm_ops);


--
-- Name: idx_master_registry_visible_by_category; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_registry_visible_by_category ON public.master_zmanim_registry USING btree (time_category, canonical_hebrew_name) WHERE (is_hidden = false);


--
-- Name: idx_master_zman_day_types_day; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_day_types_day ON public.master_zman_day_types USING btree (day_type_id);


--
-- Name: idx_master_zman_day_types_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_day_types_zman ON public.master_zman_day_types USING btree (master_zman_id);


--
-- Name: idx_master_zman_events_event; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_events_event ON public.master_zman_events USING btree (jewish_event_id);


--
-- Name: idx_master_zman_events_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_events_zman ON public.master_zman_events USING btree (master_zman_id);


--
-- Name: idx_master_zman_tags_covering; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_tags_covering ON public.master_zman_tags USING btree (master_zman_id) INCLUDE (tag_id);


--
-- Name: idx_master_zman_tags_negated; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_tags_negated ON public.master_zman_tags USING btree (master_zman_id, is_negated);


--
-- Name: idx_master_zman_tags_tag; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_tags_tag ON public.master_zman_tags USING btree (tag_id);


--
-- Name: idx_master_zman_tags_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_master_zman_tags_zman ON public.master_zman_tags USING btree (master_zman_id);


--
-- Name: idx_onboarding_publisher; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_onboarding_publisher ON public.publisher_onboarding USING btree (publisher_id);


--
-- Name: idx_password_reset_tokens_email; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_password_reset_tokens_email ON public.password_reset_tokens USING btree (email);


--
-- Name: idx_password_reset_tokens_token; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_password_reset_tokens_token ON public.password_reset_tokens USING btree (token);


--
-- Name: idx_pub_zman_day_types_day; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_pub_zman_day_types_day ON public.publisher_zman_day_types USING btree (day_type_id);


--
-- Name: idx_pub_zman_day_types_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_pub_zman_day_types_zman ON public.publisher_zman_day_types USING btree (publisher_zman_id);


--
-- Name: idx_publisher_coverage_active; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_active ON public.publisher_coverage USING btree (publisher_id, is_active) WHERE (is_active = true);


--
-- Name: idx_publisher_coverage_city; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_city ON public.publisher_coverage USING btree (city_id) WHERE (coverage_level = 'city'::text);


--
-- Name: idx_publisher_coverage_continent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_continent ON public.publisher_coverage USING btree (continent_code) WHERE (coverage_level = 'continent'::text);


--
-- Name: idx_publisher_coverage_country; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_country ON public.publisher_coverage USING btree (country_id) WHERE (coverage_level = 'country'::text);


--
-- Name: idx_publisher_coverage_district; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_district ON public.publisher_coverage USING btree (district_id) WHERE (coverage_level = 'district'::text);


--
-- Name: idx_publisher_coverage_publisher; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_publisher ON public.publisher_coverage USING btree (publisher_id);


--
-- Name: idx_publisher_coverage_region; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_coverage_region ON public.publisher_coverage USING btree (region_id) WHERE (coverage_level = 'region'::text);


--
-- Name: idx_publisher_coverage_unique_city; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publisher_coverage_unique_city ON public.publisher_coverage USING btree (publisher_id, city_id) WHERE (coverage_level = 'city'::text);


--
-- Name: idx_publisher_coverage_unique_continent; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publisher_coverage_unique_continent ON public.publisher_coverage USING btree (publisher_id, continent_code) WHERE (coverage_level = 'continent'::text);


--
-- Name: idx_publisher_coverage_unique_country; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publisher_coverage_unique_country ON public.publisher_coverage USING btree (publisher_id, country_id) WHERE (coverage_level = 'country'::text);


--
-- Name: idx_publisher_coverage_unique_district; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publisher_coverage_unique_district ON public.publisher_coverage USING btree (publisher_id, district_id) WHERE (coverage_level = 'district'::text);


--
-- Name: idx_publisher_coverage_unique_region; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publisher_coverage_unique_region ON public.publisher_coverage USING btree (publisher_id, region_id) WHERE (coverage_level = 'region'::text);


--
-- Name: idx_publisher_invitations_email; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_invitations_email ON public.publisher_invitations USING btree (email, publisher_id);


--
-- Name: idx_publisher_invitations_publisher; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_invitations_publisher ON public.publisher_invitations USING btree (publisher_id);


--
-- Name: idx_publisher_invitations_token; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_invitations_token ON public.publisher_invitations USING btree (token);


--
-- Name: idx_publisher_requests_email_pending; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publisher_requests_email_pending ON public.publisher_requests USING btree (email) WHERE (status = 'pending'::text);


--
-- Name: idx_publisher_requests_status; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_requests_status ON public.publisher_requests USING btree (status);


--
-- Name: idx_publisher_snapshots_publisher_created; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_snapshots_publisher_created ON public.publisher_snapshots USING btree (publisher_id, created_at DESC);


--
-- Name: idx_publisher_zman_aliases_publisher; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_aliases_publisher ON public.publisher_zman_aliases USING btree (publisher_id);


--
-- Name: idx_publisher_zman_aliases_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_aliases_zman ON public.publisher_zman_aliases USING btree (publisher_zman_id);


--
-- Name: idx_publisher_zman_events_composite; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_events_composite ON public.publisher_zman_events USING btree (publisher_zman_id, jewish_event_id);


--
-- Name: idx_publisher_zman_events_event; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_events_event ON public.publisher_zman_events USING btree (jewish_event_id);


--
-- Name: idx_publisher_zman_events_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_events_zman ON public.publisher_zman_events USING btree (publisher_zman_id);


--
-- Name: idx_publisher_zman_tags_negated; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_tags_negated ON public.publisher_zman_tags USING btree (publisher_zman_id, is_negated);


--
-- Name: idx_publisher_zman_tags_tag; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_tags_tag ON public.publisher_zman_tags USING btree (tag_id);


--
-- Name: idx_publisher_zman_tags_zman; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_tags_zman ON public.publisher_zman_tags USING btree (publisher_zman_id);


--
-- Name: idx_publisher_zman_versions_zman_version; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zman_versions_zman_version ON public.publisher_zman_versions USING btree (publisher_zman_id, version_number DESC);


--
-- Name: idx_publisher_zmanim_active; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_active ON public.publisher_zmanim USING btree (publisher_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_publisher_zmanim_active_enabled; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_active_enabled ON public.publisher_zmanim USING btree (publisher_id, is_enabled) WHERE (deleted_at IS NULL);


--
-- Name: idx_publisher_zmanim_beta; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_beta ON public.publisher_zmanim USING btree (publisher_id, is_beta) WHERE (is_beta = true);


--
-- Name: idx_publisher_zmanim_category; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_category ON public.publisher_zmanim USING btree (category);


--
-- Name: idx_publisher_zmanim_custom; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_custom ON public.publisher_zmanim USING btree (publisher_id, is_custom) WHERE (is_custom = true);


--
-- Name: idx_publisher_zmanim_deleted; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_deleted ON public.publisher_zmanim USING btree (publisher_id, deleted_at) WHERE (deleted_at IS NOT NULL);


--
-- Name: idx_publisher_zmanim_enabled; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_enabled ON public.publisher_zmanim USING btree (publisher_id, is_enabled) WHERE (is_enabled = true);


--
-- Name: idx_publisher_zmanim_english_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_english_name_trgm ON public.publisher_zmanim USING gin (english_name public.gin_trgm_ops) WHERE ((is_published = true) AND (is_visible = true));


--
-- Name: idx_publisher_zmanim_hebrew_name_trgm; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_hebrew_name_trgm ON public.publisher_zmanim USING gin (hebrew_name public.gin_trgm_ops) WHERE ((is_published = true) AND (is_visible = true));


--
-- Name: idx_publisher_zmanim_key_lookup; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_key_lookup ON public.publisher_zmanim USING btree (publisher_id, zman_key) WHERE (deleted_at IS NULL);


--
-- Name: idx_publisher_zmanim_linked; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_linked ON public.publisher_zmanim USING btree (linked_publisher_zman_id);


--
-- Name: idx_publisher_zmanim_linked_source; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_linked_source ON public.publisher_zmanim USING btree (publisher_id, source_type, linked_publisher_zman_id) WHERE ((source_type)::text = 'linked'::text);


--
-- Name: idx_publisher_zmanim_master; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_master ON public.publisher_zmanim USING btree (master_zman_id);


--
-- Name: idx_publisher_zmanim_public_search; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_public_search ON public.publisher_zmanim USING btree (is_published, is_visible, category) WHERE ((is_published = true) AND (is_visible = true));


--
-- Name: idx_publisher_zmanim_published; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_published ON public.publisher_zmanim USING btree (publisher_id, is_published) WHERE (is_published = true);


--
-- Name: idx_publisher_zmanim_source_type; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publisher_zmanim_source_type ON public.publisher_zmanim USING btree (source_type);


--
-- Name: idx_publishers_clerk_user_id; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_clerk_user_id ON public.publishers USING btree (clerk_user_id);


--
-- Name: idx_publishers_deleted_at; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_deleted_at ON public.publishers USING btree (deleted_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_publishers_id_name; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_id_name ON public.publishers USING btree (id) INCLUDE (name, status, is_verified);


--
-- Name: idx_publishers_is_certified; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_is_certified ON public.publishers USING btree (is_certified);


--
-- Name: idx_publishers_location; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_location ON public.publishers USING gist (location);


--
-- Name: idx_publishers_slug; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE UNIQUE INDEX idx_publishers_slug ON public.publishers USING btree (slug) WHERE (slug IS NOT NULL);


--
-- Name: idx_publishers_status; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_status ON public.publishers USING btree (status);


--
-- Name: idx_publishers_verified; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_publishers_verified ON public.publishers USING btree (is_verified) WHERE (is_verified = true);


--
-- Name: idx_region_boundaries_centroid; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_region_boundaries_centroid ON public.geo_region_boundaries USING gist (centroid);


--
-- Name: idx_region_boundaries_geom; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_region_boundaries_geom ON public.geo_region_boundaries USING gist (boundary);


--
-- Name: idx_region_boundaries_simplified; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_region_boundaries_simplified ON public.geo_region_boundaries USING gist (boundary_simplified);


--
-- Name: idx_system_config_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_system_config_key ON public.system_config USING btree (key);


--
-- Name: idx_tag_event_mappings_hebrew_date; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_tag_event_mappings_hebrew_date ON public.tag_event_mappings USING btree (hebrew_month, hebrew_day_start) WHERE (hebrew_month IS NOT NULL);


--
-- Name: idx_tag_event_mappings_pattern; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_tag_event_mappings_pattern ON public.tag_event_mappings USING btree (hebcal_event_pattern) WHERE (hebcal_event_pattern IS NOT NULL);


--
-- Name: idx_tag_event_mappings_tag; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_tag_event_mappings_tag ON public.tag_event_mappings USING btree (tag_id);


--
-- Name: idx_tag_types_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_tag_types_key ON public.tag_types USING btree (key);


--
-- Name: idx_tag_types_sort; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_tag_types_sort ON public.tag_types USING btree (sort_order);


--
-- Name: idx_time_categories_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_time_categories_key ON public.time_categories USING btree (key);


--
-- Name: idx_time_categories_sort; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_time_categories_sort ON public.time_categories USING btree (sort_order);


--
-- Name: idx_zman_registry_requests_pending; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_registry_requests_pending ON public.zman_registry_requests USING btree (created_at DESC) WHERE ((status)::text = ('pending'::character varying)::text);


--
-- Name: idx_zman_registry_requests_publisher; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_registry_requests_publisher ON public.zman_registry_requests USING btree (publisher_id);


--
-- Name: idx_zman_registry_requests_publisher_created; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_registry_requests_publisher_created ON public.zman_registry_requests USING btree (publisher_id, created_at DESC);


--
-- Name: idx_zman_registry_requests_status; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_registry_requests_status ON public.zman_registry_requests USING btree (status);


--
-- Name: idx_zman_request_tags_request; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_request_tags_request ON public.zman_request_tags USING btree (request_id);


--
-- Name: idx_zman_request_tags_tag; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_request_tags_tag ON public.zman_request_tags USING btree (tag_id) WHERE (tag_id IS NOT NULL);


--
-- Name: idx_zman_tags_type; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zman_tags_type ON public.zman_tags USING btree (tag_type);


--
-- Name: idx_zmanim_templates_key; Type: INDEX; Schema: public; Owner: zmanim
--

CREATE INDEX idx_zmanim_templates_key ON public.zmanim_templates USING btree (zman_key);


--
-- Name: ai_index_status ai_index_status_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER ai_index_status_updated_at BEFORE UPDATE ON public.ai_index_status FOR EACH ROW EXECUTE FUNCTION public.update_embeddings_updated_at();


--
-- Name: embeddings embeddings_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER embeddings_updated_at BEFORE UPDATE ON public.embeddings FOR EACH ROW EXECUTE FUNCTION public.update_embeddings_updated_at();


--
-- Name: master_zmanim_registry master_registry_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER master_registry_updated_at BEFORE UPDATE ON public.master_zmanim_registry FOR EACH ROW EXECUTE FUNCTION public.update_master_registry_updated_at();


--
-- Name: publisher_zman_versions prune_versions_trigger; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER prune_versions_trigger AFTER INSERT ON public.publisher_zman_versions FOR EACH ROW EXECUTE FUNCTION public.prune_zman_versions();


--
-- Name: publisher_zman_day_types publisher_zman_day_types_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER publisher_zman_day_types_updated_at BEFORE UPDATE ON public.publisher_zman_day_types FOR EACH ROW EXECUTE FUNCTION public.update_publisher_zman_day_types_updated_at();


--
-- Name: publisher_zman_events publisher_zman_events_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER publisher_zman_events_updated_at BEFORE UPDATE ON public.publisher_zman_events FOR EACH ROW EXECUTE FUNCTION public.update_publisher_zman_events_updated_at();


--
-- Name: publisher_zmanim publisher_zmanim_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER publisher_zmanim_updated_at BEFORE UPDATE ON public.publisher_zmanim FOR EACH ROW EXECUTE FUNCTION public.update_publisher_zmanim_updated_at();


--
-- Name: cities trg_validate_city_hierarchy; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER trg_validate_city_hierarchy BEFORE INSERT OR UPDATE ON public.cities FOR EACH ROW EXECUTE FUNCTION public.validate_city_hierarchy();

ALTER TABLE public.cities DISABLE TRIGGER trg_validate_city_hierarchy;


--
-- Name: geo_districts trg_validate_district_hierarchy; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER trg_validate_district_hierarchy BEFORE INSERT OR UPDATE ON public.geo_districts FOR EACH ROW EXECUTE FUNCTION public.validate_district_hierarchy();


--
-- Name: geo_regions trg_validate_region_hierarchy; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER trg_validate_region_hierarchy BEFORE INSERT OR UPDATE ON public.geo_regions FOR EACH ROW EXECUTE FUNCTION public.validate_region_hierarchy();


--
-- Name: publisher_snapshots trigger_prune_publisher_snapshots; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER trigger_prune_publisher_snapshots AFTER INSERT ON public.publisher_snapshots FOR EACH ROW EXECUTE FUNCTION public.prune_publisher_snapshots();


--
-- Name: algorithms update_algorithms_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_algorithms_updated_at BEFORE UPDATE ON public.algorithms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: cities update_cities_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_cities_updated_at BEFORE UPDATE ON public.cities FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: geo_countries update_geo_countries_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_geo_countries_updated_at BEFORE UPDATE ON public.geo_countries FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: geo_country_boundaries update_geo_country_boundaries_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_geo_country_boundaries_updated_at BEFORE UPDATE ON public.geo_country_boundaries FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: geo_district_boundaries update_geo_district_boundaries_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_geo_district_boundaries_updated_at BEFORE UPDATE ON public.geo_district_boundaries FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: geo_districts update_geo_districts_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_geo_districts_updated_at BEFORE UPDATE ON public.geo_districts FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: geo_region_boundaries update_geo_region_boundaries_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_geo_region_boundaries_updated_at BEFORE UPDATE ON public.geo_region_boundaries FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: geo_regions update_geo_regions_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_geo_regions_updated_at BEFORE UPDATE ON public.geo_regions FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: publisher_coverage update_publisher_coverage_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_publisher_coverage_updated_at BEFORE UPDATE ON public.publisher_coverage FOR EACH ROW EXECUTE FUNCTION public.update_geo_updated_at();


--
-- Name: publisher_zman_aliases update_publisher_zman_aliases_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_publisher_zman_aliases_updated_at BEFORE UPDATE ON public.publisher_zman_aliases FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: publishers update_publishers_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_publishers_updated_at BEFORE UPDATE ON public.publishers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: system_config update_system_config_updated_at; Type: TRIGGER; Schema: public; Owner: zmanim
--

CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON public.system_config FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: ai_audit_logs ai_audit_logs_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.ai_audit_logs
    ADD CONSTRAINT ai_audit_logs_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE SET NULL;


--
-- Name: algorithms algorithms_forked_from_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.algorithms
    ADD CONSTRAINT algorithms_forked_from_fkey FOREIGN KEY (forked_from) REFERENCES public.algorithms(id) ON DELETE SET NULL;


--
-- Name: algorithms algorithms_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.algorithms
    ADD CONSTRAINT algorithms_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: cities cities_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_continent_id_fkey FOREIGN KEY (continent_id) REFERENCES public.geo_continents(id);


--
-- Name: cities cities_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id);


--
-- Name: cities cities_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.geo_districts(id);


--
-- Name: cities cities_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.geo_regions(id);


--
-- Name: geo_countries geo_countries_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_countries
    ADD CONSTRAINT geo_countries_continent_id_fkey FOREIGN KEY (continent_id) REFERENCES public.geo_continents(id);


--
-- Name: geo_country_boundaries geo_country_boundaries_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_country_boundaries
    ADD CONSTRAINT geo_country_boundaries_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id) ON DELETE CASCADE;


--
-- Name: geo_district_boundaries geo_district_boundaries_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_district_boundaries
    ADD CONSTRAINT geo_district_boundaries_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.geo_districts(id) ON DELETE CASCADE;


--
-- Name: geo_districts geo_districts_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_districts
    ADD CONSTRAINT geo_districts_continent_id_fkey FOREIGN KEY (continent_id) REFERENCES public.geo_continents(id);


--
-- Name: geo_districts geo_districts_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_districts
    ADD CONSTRAINT geo_districts_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id);


--
-- Name: geo_districts geo_districts_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_districts
    ADD CONSTRAINT geo_districts_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.geo_regions(id) ON DELETE CASCADE;


--
-- Name: geo_region_boundaries geo_region_boundaries_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_region_boundaries
    ADD CONSTRAINT geo_region_boundaries_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.geo_regions(id) ON DELETE CASCADE;


--
-- Name: geo_regions geo_regions_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_regions
    ADD CONSTRAINT geo_regions_continent_id_fkey FOREIGN KEY (continent_id) REFERENCES public.geo_continents(id);


--
-- Name: geo_regions geo_regions_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.geo_regions
    ADD CONSTRAINT geo_regions_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id) ON DELETE CASCADE;


--
-- Name: master_zman_day_types master_zman_day_types_day_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_day_types
    ADD CONSTRAINT master_zman_day_types_day_type_id_fkey FOREIGN KEY (day_type_id) REFERENCES public.day_types(id) ON DELETE CASCADE;


--
-- Name: master_zman_day_types master_zman_day_types_master_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_day_types
    ADD CONSTRAINT master_zman_day_types_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;


--
-- Name: master_zman_events master_zman_events_jewish_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_events
    ADD CONSTRAINT master_zman_events_jewish_event_id_fkey FOREIGN KEY (jewish_event_id) REFERENCES public.jewish_events(id) ON DELETE CASCADE;


--
-- Name: master_zman_events master_zman_events_master_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_events
    ADD CONSTRAINT master_zman_events_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;


--
-- Name: master_zman_tags master_zman_tags_master_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_tags
    ADD CONSTRAINT master_zman_tags_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;


--
-- Name: master_zman_tags master_zman_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.master_zman_tags
    ADD CONSTRAINT master_zman_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.zman_tags(id) ON DELETE CASCADE;


--
-- Name: publisher_coverage publisher_coverage_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_coverage
    ADD CONSTRAINT publisher_coverage_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE CASCADE;


--
-- Name: publisher_coverage publisher_coverage_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_coverage
    ADD CONSTRAINT publisher_coverage_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.geo_countries(id) ON DELETE CASCADE;


--
-- Name: publisher_coverage publisher_coverage_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_coverage
    ADD CONSTRAINT publisher_coverage_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.geo_districts(id) ON DELETE CASCADE;


--
-- Name: publisher_coverage publisher_coverage_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_coverage
    ADD CONSTRAINT publisher_coverage_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: publisher_coverage publisher_coverage_region_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_coverage
    ADD CONSTRAINT publisher_coverage_region_id_fkey FOREIGN KEY (region_id) REFERENCES public.geo_regions(id) ON DELETE CASCADE;


--
-- Name: publisher_invitations publisher_invitations_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_invitations
    ADD CONSTRAINT publisher_invitations_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: publisher_onboarding publisher_onboarding_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_onboarding
    ADD CONSTRAINT publisher_onboarding_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: publisher_snapshots publisher_snapshots_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_snapshots
    ADD CONSTRAINT publisher_snapshots_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_aliases publisher_zman_aliases_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_aliases
    ADD CONSTRAINT publisher_zman_aliases_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_aliases publisher_zman_aliases_publisher_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_aliases
    ADD CONSTRAINT publisher_zman_aliases_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_day_types publisher_zman_day_types_day_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_day_types
    ADD CONSTRAINT publisher_zman_day_types_day_type_id_fkey FOREIGN KEY (day_type_id) REFERENCES public.day_types(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_day_types publisher_zman_day_types_publisher_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_day_types
    ADD CONSTRAINT publisher_zman_day_types_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_events publisher_zman_events_jewish_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_events
    ADD CONSTRAINT publisher_zman_events_jewish_event_id_fkey FOREIGN KEY (jewish_event_id) REFERENCES public.jewish_events(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_events publisher_zman_events_publisher_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_events
    ADD CONSTRAINT publisher_zman_events_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_tags publisher_zman_tags_publisher_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_tags
    ADD CONSTRAINT publisher_zman_tags_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_tags publisher_zman_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_tags
    ADD CONSTRAINT publisher_zman_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.zman_tags(id) ON DELETE CASCADE;


--
-- Name: publisher_zman_versions publisher_zman_versions_publisher_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zman_versions
    ADD CONSTRAINT publisher_zman_versions_publisher_zman_id_fkey FOREIGN KEY (publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE CASCADE;


--
-- Name: publisher_zmanim publisher_zmanim_linked_publisher_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zmanim
    ADD CONSTRAINT publisher_zmanim_linked_publisher_zman_id_fkey FOREIGN KEY (linked_publisher_zman_id) REFERENCES public.publisher_zmanim(id) ON DELETE SET NULL;


--
-- Name: publisher_zmanim publisher_zmanim_master_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zmanim
    ADD CONSTRAINT publisher_zmanim_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id);


--
-- Name: publisher_zmanim publisher_zmanim_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.publisher_zmanim
    ADD CONSTRAINT publisher_zmanim_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: tag_event_mappings tag_event_mappings_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.tag_event_mappings
    ADD CONSTRAINT tag_event_mappings_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.zman_tags(id) ON DELETE CASCADE;


--
-- Name: zman_display_contexts zman_display_contexts_master_zman_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_display_contexts
    ADD CONSTRAINT zman_display_contexts_master_zman_id_fkey FOREIGN KEY (master_zman_id) REFERENCES public.master_zmanim_registry(id) ON DELETE CASCADE;


--
-- Name: zman_registry_requests zman_registry_requests_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_registry_requests
    ADD CONSTRAINT zman_registry_requests_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(id) ON DELETE CASCADE;


--
-- Name: zman_request_tags zman_request_tags_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_request_tags
    ADD CONSTRAINT zman_request_tags_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.zman_registry_requests(id) ON DELETE CASCADE;


--
-- Name: zman_request_tags zman_request_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: zmanim
--

ALTER TABLE ONLY public.zman_request_tags
    ADD CONSTRAINT zman_request_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.zman_tags(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict PkCpT10fz9uHHn1DGb7rafi0s79kEQjh4hI2PI8d0dq6JJ8ytkz3qauZGXVksOR

