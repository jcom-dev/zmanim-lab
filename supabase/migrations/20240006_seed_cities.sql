-- Migration: Seed cities database with major world cities
-- Story: 1.5 Global Location System
-- Date: 2025-11-25
-- Source: Curated list of major cities with Jewish communities and global coverage

-- USA Cities (state)
INSERT INTO cities (name, name_ascii, country, country_code, region, region_type, latitude, longitude, timezone, population) VALUES
-- New York Metro
('New York', 'New York', 'United States', 'US', 'New York', 'state', 40.7128, -74.0060, 'America/New_York', 8336817),
('Brooklyn', 'Brooklyn', 'United States', 'US', 'New York', 'state', 40.6782, -73.9442, 'America/New_York', 2736074),
('Manhattan', 'Manhattan', 'United States', 'US', 'New York', 'state', 40.7831, -73.9712, 'America/New_York', 1628706),
('Queens', 'Queens', 'United States', 'US', 'New York', 'state', 40.7282, -73.7949, 'America/New_York', 2405464),
('The Bronx', 'The Bronx', 'United States', 'US', 'New York', 'state', 40.8448, -73.8648, 'America/New_York', 1472654),
('Staten Island', 'Staten Island', 'United States', 'US', 'New York', 'state', 40.5795, -74.1502, 'America/New_York', 495747),
('Long Island', 'Long Island', 'United States', 'US', 'New York', 'state', 40.7891, -73.1350, 'America/New_York', 7869820),
('Monsey', 'Monsey', 'United States', 'US', 'New York', 'state', 41.1112, -74.0685, 'America/New_York', 22000),
('Lakewood', 'Lakewood', 'United States', 'US', 'New Jersey', 'state', 40.0960, -74.2177, 'America/New_York', 135158),
-- California
('Los Angeles', 'Los Angeles', 'United States', 'US', 'California', 'state', 34.0522, -118.2437, 'America/Los_Angeles', 3979576),
('San Francisco', 'San Francisco', 'United States', 'US', 'California', 'state', 37.7749, -122.4194, 'America/Los_Angeles', 884363),
('San Diego', 'San Diego', 'United States', 'US', 'California', 'state', 32.7157, -117.1611, 'America/Los_Angeles', 1423851),
('San Jose', 'San Jose', 'United States', 'US', 'California', 'state', 37.3382, -121.8863, 'America/Los_Angeles', 1035317),
('Palo Alto', 'Palo Alto', 'United States', 'US', 'California', 'state', 37.4419, -122.1430, 'America/Los_Angeles', 68572),
-- Florida
('Miami', 'Miami', 'United States', 'US', 'Florida', 'state', 25.7617, -80.1918, 'America/New_York', 467963),
('Boca Raton', 'Boca Raton', 'United States', 'US', 'Florida', 'state', 26.3587, -80.0831, 'America/New_York', 99805),
('Hollywood', 'Hollywood', 'United States', 'US', 'Florida', 'state', 26.0112, -80.1495, 'America/New_York', 154823),
('Fort Lauderdale', 'Fort Lauderdale', 'United States', 'US', 'Florida', 'state', 26.1224, -80.1373, 'America/New_York', 182760),
('Orlando', 'Orlando', 'United States', 'US', 'Florida', 'state', 28.5383, -81.3792, 'America/New_York', 307573),
('Tampa', 'Tampa', 'United States', 'US', 'Florida', 'state', 27.9506, -82.4572, 'America/New_York', 399700),
-- Illinois
('Chicago', 'Chicago', 'United States', 'US', 'Illinois', 'state', 41.8781, -87.6298, 'America/Chicago', 2716000),
('Skokie', 'Skokie', 'United States', 'US', 'Illinois', 'state', 42.0324, -87.7334, 'America/Chicago', 67824),
-- Texas
('Houston', 'Houston', 'United States', 'US', 'Texas', 'state', 29.7604, -95.3698, 'America/Chicago', 2320268),
('Dallas', 'Dallas', 'United States', 'US', 'Texas', 'state', 32.7767, -96.7970, 'America/Chicago', 1343573),
('Austin', 'Austin', 'United States', 'US', 'Texas', 'state', 30.2672, -97.7431, 'America/Chicago', 978908),
('San Antonio', 'San Antonio', 'United States', 'US', 'Texas', 'state', 29.4241, -98.4936, 'America/Chicago', 1547253),
-- Other US Cities
('Boston', 'Boston', 'United States', 'US', 'Massachusetts', 'state', 42.3601, -71.0589, 'America/New_York', 692600),
('Philadelphia', 'Philadelphia', 'United States', 'US', 'Pennsylvania', 'state', 39.9526, -75.1652, 'America/New_York', 1584064),
('Phoenix', 'Phoenix', 'United States', 'US', 'Arizona', 'state', 33.4484, -112.0740, 'America/Phoenix', 1680992),
('Seattle', 'Seattle', 'United States', 'US', 'Washington', 'state', 47.6062, -122.3321, 'America/Los_Angeles', 753675),
('Denver', 'Denver', 'United States', 'US', 'Colorado', 'state', 39.7392, -104.9903, 'America/Denver', 727211),
('Atlanta', 'Atlanta', 'United States', 'US', 'Georgia', 'state', 33.7490, -84.3880, 'America/New_York', 498044),
('Detroit', 'Detroit', 'United States', 'US', 'Michigan', 'state', 42.3314, -83.0458, 'America/Detroit', 670031),
('Cleveland', 'Cleveland', 'United States', 'US', 'Ohio', 'state', 41.4993, -81.6944, 'America/New_York', 372624),
('Baltimore', 'Baltimore', 'United States', 'US', 'Maryland', 'state', 39.2904, -76.6122, 'America/New_York', 593490),
('Washington', 'Washington', 'United States', 'US', 'District of Columbia', 'state', 38.9072, -77.0369, 'America/New_York', 689545),
('Las Vegas', 'Las Vegas', 'United States', 'US', 'Nevada', 'state', 36.1699, -115.1398, 'America/Los_Angeles', 651319),
('Minneapolis', 'Minneapolis', 'United States', 'US', 'Minnesota', 'state', 44.9778, -93.2650, 'America/Chicago', 429954),
('St. Louis', 'St. Louis', 'United States', 'US', 'Missouri', 'state', 38.6270, -90.1994, 'America/Chicago', 301578),
('Pittsburgh', 'Pittsburgh', 'United States', 'US', 'Pennsylvania', 'state', 40.4406, -79.9959, 'America/New_York', 302971),

-- Israel Cities (district)
('Jerusalem', 'Jerusalem', 'Israel', 'IL', 'Jerusalem', 'district', 31.7683, 35.2137, 'Asia/Jerusalem', 936425),
('Tel Aviv', 'Tel Aviv', 'Israel', 'IL', 'Tel Aviv', 'district', 32.0853, 34.7818, 'Asia/Jerusalem', 460613),
('Haifa', 'Haifa', 'Israel', 'IL', 'Haifa', 'district', 32.7940, 34.9896, 'Asia/Jerusalem', 285316),
('Rishon LeZion', 'Rishon LeZion', 'Israel', 'IL', 'Central', 'district', 31.9730, 34.7925, 'Asia/Jerusalem', 254384),
('Petah Tikva', 'Petah Tikva', 'Israel', 'IL', 'Central', 'district', 32.0868, 34.8870, 'Asia/Jerusalem', 247956),
('Ashdod', 'Ashdod', 'Israel', 'IL', 'Southern', 'district', 31.8044, 34.6553, 'Asia/Jerusalem', 225939),
('Netanya', 'Netanya', 'Israel', 'IL', 'Central', 'district', 32.3286, 34.8569, 'Asia/Jerusalem', 221353),
('Beer Sheva', 'Beer Sheva', 'Israel', 'IL', 'Southern', 'district', 31.2520, 34.7915, 'Asia/Jerusalem', 209687),
('Bnei Brak', 'Bnei Brak', 'Israel', 'IL', 'Tel Aviv', 'district', 32.0833, 34.8333, 'Asia/Jerusalem', 204639),
('Holon', 'Holon', 'Israel', 'IL', 'Tel Aviv', 'district', 32.0167, 34.7667, 'Asia/Jerusalem', 196282),
('Ramat Gan', 'Ramat Gan', 'Israel', 'IL', 'Tel Aviv', 'district', 32.0833, 34.8167, 'Asia/Jerusalem', 163480),
('Herzliya', 'Herzliya', 'Israel', 'IL', 'Tel Aviv', 'district', 32.1667, 34.8333, 'Asia/Jerusalem', 97470),
('Kfar Saba', 'Kfar Saba', 'Israel', 'IL', 'Central', 'district', 32.1833, 34.9000, 'Asia/Jerusalem', 105671),
('Modiin', 'Modiin', 'Israel', 'IL', 'Central', 'district', 31.8928, 35.0104, 'Asia/Jerusalem', 93277),
('Eilat', 'Eilat', 'Israel', 'IL', 'Southern', 'district', 29.5581, 34.9482, 'Asia/Jerusalem', 52575),
('Tiberias', 'Tiberias', 'Israel', 'IL', 'Northern', 'district', 32.7897, 35.5311, 'Asia/Jerusalem', 46800),
('Tzfat', 'Tzfat', 'Israel', 'IL', 'Northern', 'district', 32.9658, 35.4983, 'Asia/Jerusalem', 35700),

-- UK Cities (county/region)
('London', 'London', 'United Kingdom', 'GB', 'Greater London', 'region', 51.5074, -0.1278, 'Europe/London', 8982000),
('Manchester', 'Manchester', 'United Kingdom', 'GB', 'Greater Manchester', 'county', 53.4808, -2.2426, 'Europe/London', 547627),
('Birmingham', 'Birmingham', 'United Kingdom', 'GB', 'West Midlands', 'county', 52.4862, -1.8904, 'Europe/London', 1141816),
('Leeds', 'Leeds', 'United Kingdom', 'GB', 'West Yorkshire', 'county', 53.8008, -1.5491, 'Europe/London', 793139),
('Glasgow', 'Glasgow', 'United Kingdom', 'GB', 'Scotland', 'region', 55.8642, -4.2518, 'Europe/London', 635640),
('Liverpool', 'Liverpool', 'United Kingdom', 'GB', 'Merseyside', 'county', 53.4084, -2.9916, 'Europe/London', 498042),
('Bristol', 'Bristol', 'United Kingdom', 'GB', 'Bristol', 'county', 51.4545, -2.5879, 'Europe/London', 467099),
('Edinburgh', 'Edinburgh', 'United Kingdom', 'GB', 'Scotland', 'region', 55.9533, -3.1883, 'Europe/London', 488050),
('Cardiff', 'Cardiff', 'United Kingdom', 'GB', 'Wales', 'region', 51.4816, -3.1791, 'Europe/London', 366903),
('Sheffield', 'Sheffield', 'United Kingdom', 'GB', 'South Yorkshire', 'county', 53.3811, -1.4701, 'Europe/London', 584853),
('Golders Green', 'Golders Green', 'United Kingdom', 'GB', 'Greater London', 'region', 51.5722, -0.1944, 'Europe/London', 18000),
('Hendon', 'Hendon', 'United Kingdom', 'GB', 'Greater London', 'region', 51.5833, -0.2333, 'Europe/London', 52000),
('Stamford Hill', 'Stamford Hill', 'United Kingdom', 'GB', 'Greater London', 'region', 51.5729, -0.0757, 'Europe/London', 27000),
('Gateshead', 'Gateshead', 'United Kingdom', 'GB', 'Tyne and Wear', 'county', 54.9526, -1.6032, 'Europe/London', 120046),

-- Canada Cities (province)
('Toronto', 'Toronto', 'Canada', 'CA', 'Ontario', 'province', 43.6532, -79.3832, 'America/Toronto', 2930000),
('Montreal', 'Montreal', 'Canada', 'CA', 'Quebec', 'province', 45.5017, -73.5673, 'America/Montreal', 1780000),
('Vancouver', 'Vancouver', 'Canada', 'CA', 'British Columbia', 'province', 49.2827, -123.1207, 'America/Vancouver', 675218),
('Calgary', 'Calgary', 'Canada', 'CA', 'Alberta', 'province', 51.0447, -114.0719, 'America/Edmonton', 1336000),
('Ottawa', 'Ottawa', 'Canada', 'CA', 'Ontario', 'province', 45.4215, -75.6972, 'America/Toronto', 1017449),
('Edmonton', 'Edmonton', 'Canada', 'CA', 'Alberta', 'province', 53.5461, -113.4938, 'America/Edmonton', 1010899),
('Winnipeg', 'Winnipeg', 'Canada', 'CA', 'Manitoba', 'province', 49.8951, -97.1384, 'America/Winnipeg', 749534),
('Halifax', 'Halifax', 'Canada', 'CA', 'Nova Scotia', 'province', 44.6488, -63.5752, 'America/Halifax', 439819),

-- Australia Cities (state)
('Sydney', 'Sydney', 'Australia', 'AU', 'New South Wales', 'state', -33.8688, 151.2093, 'Australia/Sydney', 5312163),
('Melbourne', 'Melbourne', 'Australia', 'AU', 'Victoria', 'state', -37.8136, 144.9631, 'Australia/Melbourne', 5078193),
('Brisbane', 'Brisbane', 'Australia', 'AU', 'Queensland', 'state', -27.4698, 153.0251, 'Australia/Brisbane', 2514184),
('Perth', 'Perth', 'Australia', 'AU', 'Western Australia', 'state', -31.9505, 115.8605, 'Australia/Perth', 2085973),
('Adelaide', 'Adelaide', 'Australia', 'AU', 'South Australia', 'state', -34.9285, 138.6007, 'Australia/Adelaide', 1345777),
('Gold Coast', 'Gold Coast', 'Australia', 'AU', 'Queensland', 'state', -28.0167, 153.4000, 'Australia/Brisbane', 679127),

-- France Cities (region)
('Paris', 'Paris', 'France', 'FR', 'Ile-de-France', 'region', 48.8566, 2.3522, 'Europe/Paris', 2161000),
('Marseille', 'Marseille', 'France', 'FR', 'Provence-Alpes-Cote d''Azur', 'region', 43.2965, 5.3698, 'Europe/Paris', 861635),
('Lyon', 'Lyon', 'France', 'FR', 'Auvergne-Rhone-Alpes', 'region', 45.7640, 4.8357, 'Europe/Paris', 516092),
('Nice', 'Nice', 'France', 'FR', 'Provence-Alpes-Cote d''Azur', 'region', 43.7102, 7.2620, 'Europe/Paris', 342669),
('Strasbourg', 'Strasbourg', 'France', 'FR', 'Grand Est', 'region', 48.5734, 7.7521, 'Europe/Paris', 280966),

-- Germany Cities (state)
('Berlin', 'Berlin', 'Germany', 'DE', 'Berlin', 'state', 52.5200, 13.4050, 'Europe/Berlin', 3748148),
('Munich', 'Munich', 'Germany', 'DE', 'Bavaria', 'state', 48.1351, 11.5820, 'Europe/Berlin', 1471508),
('Frankfurt', 'Frankfurt', 'Germany', 'DE', 'Hesse', 'state', 50.1109, 8.6821, 'Europe/Berlin', 753056),
('Hamburg', 'Hamburg', 'Germany', 'DE', 'Hamburg', 'state', 53.5488, 9.9872, 'Europe/Berlin', 1899160),
('Cologne', 'Cologne', 'Germany', 'DE', 'North Rhine-Westphalia', 'state', 50.9375, 6.9603, 'Europe/Berlin', 1085664),
('Dusseldorf', 'Dusseldorf', 'Germany', 'DE', 'North Rhine-Westphalia', 'state', 51.2277, 6.7735, 'Europe/Berlin', 619294),

-- South Africa Cities (province)
('Johannesburg', 'Johannesburg', 'South Africa', 'ZA', 'Gauteng', 'province', -26.2041, 28.0473, 'Africa/Johannesburg', 5635127),
('Cape Town', 'Cape Town', 'South Africa', 'ZA', 'Western Cape', 'province', -33.9249, 18.4241, 'Africa/Johannesburg', 4618000),
('Durban', 'Durban', 'South Africa', 'ZA', 'KwaZulu-Natal', 'province', -29.8587, 31.0218, 'Africa/Johannesburg', 3720953),

-- Argentina Cities (province)
('Buenos Aires', 'Buenos Aires', 'Argentina', 'AR', 'Buenos Aires', 'province', -34.6037, -58.3816, 'America/Argentina/Buenos_Aires', 2891082),

-- Brazil Cities (state)
('Sao Paulo', 'Sao Paulo', 'Brazil', 'BR', 'Sao Paulo', 'state', -23.5505, -46.6333, 'America/Sao_Paulo', 12325232),
('Rio de Janeiro', 'Rio de Janeiro', 'Brazil', 'BR', 'Rio de Janeiro', 'state', -22.9068, -43.1729, 'America/Sao_Paulo', 6747815),

-- Mexico Cities (state)
('Mexico City', 'Mexico City', 'Mexico', 'MX', 'Mexico City', 'state', 19.4326, -99.1332, 'America/Mexico_City', 21581000),

-- Other European Cities
('Amsterdam', 'Amsterdam', 'Netherlands', 'NL', 'North Holland', 'province', 52.3676, 4.9041, 'Europe/Amsterdam', 872680),
('Antwerp', 'Antwerp', 'Belgium', 'BE', 'Antwerp', 'province', 51.2194, 4.4025, 'Europe/Brussels', 523248),
('Brussels', 'Brussels', 'Belgium', 'BE', 'Brussels', 'region', 50.8503, 4.3517, 'Europe/Brussels', 1209000),
('Vienna', 'Vienna', 'Austria', 'AT', 'Vienna', 'state', 48.2082, 16.3738, 'Europe/Vienna', 1911191),
('Zurich', 'Zurich', 'Switzerland', 'CH', 'Zurich', 'canton', 47.3769, 8.5417, 'Europe/Zurich', 402762),
('Geneva', 'Geneva', 'Switzerland', 'CH', 'Geneva', 'canton', 46.2044, 6.1432, 'Europe/Zurich', 203856),
('Rome', 'Rome', 'Italy', 'IT', 'Lazio', 'region', 41.9028, 12.4964, 'Europe/Rome', 2872800),
('Milan', 'Milan', 'Italy', 'IT', 'Lombardy', 'region', 45.4642, 9.1900, 'Europe/Rome', 1371498),
('Madrid', 'Madrid', 'Spain', 'ES', 'Community of Madrid', 'community', 40.4168, -3.7038, 'Europe/Madrid', 3223334),
('Barcelona', 'Barcelona', 'Spain', 'ES', 'Catalonia', 'community', 41.3874, 2.1686, 'Europe/Madrid', 1620343),

-- Russia
('Moscow', 'Moscow', 'Russia', 'RU', 'Moscow', 'city', 55.7558, 37.6173, 'Europe/Moscow', 12506468),
('Saint Petersburg', 'Saint Petersburg', 'Russia', 'RU', 'Saint Petersburg', 'city', 59.9311, 30.3609, 'Europe/Moscow', 5351935),

-- Asia
('Tokyo', 'Tokyo', 'Japan', 'JP', 'Tokyo', 'prefecture', 35.6762, 139.6503, 'Asia/Tokyo', 13960000),
('Hong Kong', 'Hong Kong', 'Hong Kong', 'HK', NULL, NULL, 22.3193, 114.1694, 'Asia/Hong_Kong', 7500700),
('Singapore', 'Singapore', 'Singapore', 'SG', NULL, NULL, 1.3521, 103.8198, 'Asia/Singapore', 5850342),
('Mumbai', 'Mumbai', 'India', 'IN', 'Maharashtra', 'state', 19.0760, 72.8777, 'Asia/Kolkata', 20411000),
('Dubai', 'Dubai', 'United Arab Emirates', 'AE', 'Dubai', 'emirate', 25.2048, 55.2708, 'Asia/Dubai', 3137000);
