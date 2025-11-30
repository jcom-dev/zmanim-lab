-- Migration: Seed cities database with major world cities
-- Adapted for new schema (name, country_code, region, latitude, longitude, timezone, population)

-- USA Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('New York', 'US', 'New York', 40.7128, -74.0060, 'America/New_York', 8336817),
('Brooklyn', 'US', 'New York', 40.6782, -73.9442, 'America/New_York', 2736074),
('Los Angeles', 'US', 'California', 34.0522, -118.2437, 'America/Los_Angeles', 3979576),
('Chicago', 'US', 'Illinois', 41.8781, -87.6298, 'America/Chicago', 2716000),
('Houston', 'US', 'Texas', 29.7604, -95.3698, 'America/Chicago', 2320268),
('Miami', 'US', 'Florida', 25.7617, -80.1918, 'America/New_York', 467963),
('Boston', 'US', 'Massachusetts', 42.3601, -71.0589, 'America/New_York', 692600),
('Philadelphia', 'US', 'Pennsylvania', 39.9526, -75.1652, 'America/New_York', 1584064),
('Phoenix', 'US', 'Arizona', 33.4484, -112.0740, 'America/Phoenix', 1680992),
('Seattle', 'US', 'Washington', 47.6062, -122.3321, 'America/Los_Angeles', 753675),
('Denver', 'US', 'Colorado', 39.7392, -104.9903, 'America/Denver', 727211),
('Atlanta', 'US', 'Georgia', 33.7490, -84.3880, 'America/New_York', 498044),
('San Francisco', 'US', 'California', 37.7749, -122.4194, 'America/Los_Angeles', 884363),
('Dallas', 'US', 'Texas', 32.7767, -96.7970, 'America/Chicago', 1343573),
('Lakewood', 'US', 'New Jersey', 40.0960, -74.2177, 'America/New_York', 135158),
('Baltimore', 'US', 'Maryland', 39.2904, -76.6122, 'America/New_York', 593490),
('Washington', 'US', 'District of Columbia', 38.9072, -77.0369, 'America/New_York', 689545)
ON CONFLICT DO NOTHING;

-- Israel Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Jerusalem', 'IL', 'Jerusalem', 31.7683, 35.2137, 'Asia/Jerusalem', 936425),
('Tel Aviv', 'IL', 'Tel Aviv', 32.0853, 34.7818, 'Asia/Jerusalem', 460613),
('Haifa', 'IL', 'Haifa', 32.7940, 34.9896, 'Asia/Jerusalem', 285316),
('Bnei Brak', 'IL', 'Tel Aviv', 32.0833, 34.8333, 'Asia/Jerusalem', 204639),
('Petah Tikva', 'IL', 'Central', 32.0868, 34.8870, 'Asia/Jerusalem', 247956),
('Ashdod', 'IL', 'Southern', 31.8044, 34.6553, 'Asia/Jerusalem', 225939),
('Netanya', 'IL', 'Central', 32.3286, 34.8569, 'Asia/Jerusalem', 221353),
('Beer Sheva', 'IL', 'Southern', 31.2520, 34.7915, 'Asia/Jerusalem', 209687),
('Modiin', 'IL', 'Central', 31.8928, 35.0104, 'Asia/Jerusalem', 93277),
('Tzfat', 'IL', 'Northern', 32.9658, 35.4983, 'Asia/Jerusalem', 35700)
ON CONFLICT DO NOTHING;

-- UK Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('London', 'GB', 'Greater London', 51.5074, -0.1278, 'Europe/London', 8982000),
('Manchester', 'GB', 'Greater Manchester', 53.4808, -2.2426, 'Europe/London', 547627),
('Birmingham', 'GB', 'West Midlands', 52.4862, -1.8904, 'Europe/London', 1141816),
('Leeds', 'GB', 'West Yorkshire', 53.8008, -1.5491, 'Europe/London', 793139),
('Glasgow', 'GB', 'Scotland', 55.8642, -4.2518, 'Europe/London', 635640),
('Gateshead', 'GB', 'Tyne and Wear', 54.9526, -1.6032, 'Europe/London', 120046)
ON CONFLICT DO NOTHING;

-- Canada Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Toronto', 'CA', 'Ontario', 43.6532, -79.3832, 'America/Toronto', 2930000),
('Montreal', 'CA', 'Quebec', 45.5017, -73.5673, 'America/Montreal', 1780000),
('Vancouver', 'CA', 'British Columbia', 49.2827, -123.1207, 'America/Vancouver', 675218)
ON CONFLICT DO NOTHING;

-- Australia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Sydney', 'AU', 'New South Wales', -33.8688, 151.2093, 'Australia/Sydney', 5367206),
('Melbourne', 'AU', 'Victoria', -37.8136, 144.9631, 'Australia/Melbourne', 5078193)
ON CONFLICT DO NOTHING;

-- France Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Paris', 'FR', 'Ile-de-France', 48.8566, 2.3522, 'Europe/Paris', 2161000),
('Marseille', 'FR', 'Provence-Alpes-Cote Azur', 43.2965, 5.3698, 'Europe/Paris', 861635),
('Lyon', 'FR', 'Auvergne-Rhone-Alpes', 45.7640, 4.8357, 'Europe/Paris', 516092),
('Strasbourg', 'FR', 'Grand Est', 48.5734, 7.7521, 'Europe/Paris', 280966)
ON CONFLICT DO NOTHING;

-- South Africa Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Johannesburg', 'ZA', 'Gauteng', -26.2041, 28.0473, 'Africa/Johannesburg', 5635127),
('Cape Town', 'ZA', 'Western Cape', -33.9249, 18.4241, 'Africa/Johannesburg', 4618000)
ON CONFLICT DO NOTHING;

-- Argentina Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Buenos Aires', 'AR', 'Buenos Aires', -34.6037, -58.3816, 'America/Argentina/Buenos_Aires', 15024000)
ON CONFLICT DO NOTHING;

-- Mexico Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Mexico City', 'MX', 'Ciudad de Mexico', 19.4326, -99.1332, 'America/Mexico_City', 21581000)
ON CONFLICT DO NOTHING;

-- Germany Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Berlin', 'DE', 'Berlin', 52.5200, 13.4050, 'Europe/Berlin', 3644826),
('Munich', 'DE', 'Bavaria', 48.1351, 11.5820, 'Europe/Berlin', 1484226),
('Frankfurt', 'DE', 'Hesse', 50.1109, 8.6821, 'Europe/Berlin', 753056)
ON CONFLICT DO NOTHING;
