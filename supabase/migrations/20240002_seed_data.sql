-- Seed geographic regions (major cities)
INSERT INTO geographic_regions (name, name_local, type, location, timezone, elevation, population, country_code) VALUES
('Jerusalem', 'ירושלים', 'city', ST_SetSRID(ST_MakePoint(35.2137, 31.7683), 4326), 'Asia/Jerusalem', 754, 936425, 'IL'),
('Tel Aviv', 'תל אביב', 'city', ST_SetSRID(ST_MakePoint(34.7818, 32.0853), 4326), 'Asia/Jerusalem', 5, 460613, 'IL'),
('New York', 'New York', 'city', ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326), 'America/New_York', 10, 8336817, 'US'),
('Los Angeles', 'Los Angeles', 'city', ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326), 'America/Los_Angeles', 93, 3979576, 'US'),
('London', 'London', 'city', ST_SetSRID(ST_MakePoint(-0.1278, 51.5074), 4326), 'Europe/London', 11, 8982000, 'GB'),
('Paris', 'Paris', 'city', ST_SetSRID(ST_MakePoint(2.3522, 48.8566), 4326), 'Europe/Paris', 35, 2161000, 'FR'),
('Chicago', 'Chicago', 'city', ST_SetSRID(ST_MakePoint(-87.6298, 41.8781), 4326), 'America/Chicago', 181, 2716000, 'US'),
('Miami', 'Miami', 'city', ST_SetSRID(ST_MakePoint(-80.1918, 25.7617), 4326), 'America/New_York', 2, 467963, 'US'),
('Toronto', 'Toronto', 'city', ST_SetSRID(ST_MakePoint(-79.3832, 43.6532), 4326), 'America/Toronto', 76, 2930000, 'CA'),
('Montreal', 'Montreal', 'city', ST_SetSRID(ST_MakePoint(-73.5673, 45.5017), 4326), 'America/Montreal', 36, 1780000, 'CA');

-- Seed example publisher
INSERT INTO publishers (name, organization, slug, email, description, website, status, verified_at) VALUES
('Chief Rabbinate of Israel', 'Israel Chief Rabbinate', 'israel-chief-rabbinate', 'info@rabbinate.gov.il',
 'Official Jewish legal authority in Israel providing standardized zmanim calculations for all of Israel', 'https://www.rabbinate.gov.il', 'active', NOW());

-- Get publisher ID for algorithm
DO $$
DECLARE
    publisher_uuid UUID;
BEGIN
    SELECT id INTO publisher_uuid FROM publishers WHERE slug = 'israel-chief-rabbinate';

    -- Seed example algorithm
    INSERT INTO algorithms (publisher_id, name, version, description, calculation_type, formula_definition, is_active, published_at) VALUES
    (publisher_uuid, 'Standard Israeli Calculation', '2.0', 'Standard calculation method used throughout Israel based on solar depression angles and proportional hours', 'solar_depression',
     '{"version": "1.0", "type": "solar_depression", "zmanim": {"alos_hashachar": {"method": "solar_angle", "angle_degrees": 16.1, "direction": "before_sunrise"}, "sunrise": {"method": "elevation_adjusted", "refraction": 0.833}, "sof_zman_shma": {"method": "shaos_zmaniyos", "hours": 3, "base": "sunrise"}, "sof_zman_tefillah": {"method": "shaos_zmaniyos", "hours": 4, "base": "sunrise"}, "chatzos": {"method": "midpoint", "between": ["sunrise", "sunset"]}, "mincha_gedola": {"method": "fixed_offset", "minutes": 30, "base": "chatzos", "direction": "after"}, "mincha_ketana": {"method": "shaos_zmaniyos", "hours": 9.5, "base": "sunrise"}, "plag_hamincha": {"method": "shaos_zmaniyos", "hours": 10.75, "base": "sunrise"}, "sunset": {"method": "elevation_adjusted", "refraction": 0.833}, "tzeis": {"method": "solar_angle", "angle_degrees": 8.5, "direction": "after_sunset"}}, "shaah_zmanis_method": {"type": "gra", "start": "sunrise", "end": "sunset"}}'::jsonb,
     TRUE, NOW());

    -- Seed coverage area for Israel
    INSERT INTO coverage_areas (publisher_id, name, description, boundary, priority, country_code, is_active) VALUES
    (publisher_uuid, 'All of Israel', 'National coverage for the State of Israel',
     ST_SetSRID(ST_GeomFromText('POLYGON((34.2 29.5, 35.9 29.5, 35.9 33.3, 34.2 33.3, 34.2 29.5))'), 4326),
     10, 'IL', TRUE);
END $$;
