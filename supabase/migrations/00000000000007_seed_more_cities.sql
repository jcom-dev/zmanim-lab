-- Migration: Seed comprehensive cities database with world cities
-- Focus on major cities globally with emphasis on Jewish communities

-- Additional USA Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Cleveland', 'US', 'Ohio', 41.4993, -81.6944, 'America/New_York', 372624),
('Detroit', 'US', 'Michigan', 42.3314, -83.0458, 'America/Detroit', 639111),
('Las Vegas', 'US', 'Nevada', 36.1699, -115.1398, 'America/Los_Angeles', 651319),
('San Diego', 'US', 'California', 32.7157, -117.1611, 'America/Los_Angeles', 1423851),
('Portland', 'US', 'Oregon', 45.5051, -122.6750, 'America/Los_Angeles', 654741),
('Pittsburgh', 'US', 'Pennsylvania', 40.4406, -79.9959, 'America/New_York', 302407),
('St. Louis', 'US', 'Missouri', 38.6270, -90.1994, 'America/Chicago', 301578),
('Cincinnati', 'US', 'Ohio', 39.1031, -84.5120, 'America/New_York', 309317),
('Minneapolis', 'US', 'Minnesota', 44.9778, -93.2650, 'America/Chicago', 429954),
('Salt Lake City', 'US', 'Utah', 40.7608, -111.8910, 'America/Denver', 200567),
('New Haven', 'US', 'Connecticut', 41.3083, -72.9279, 'America/New_York', 134023),
('Hartford', 'US', 'Connecticut', 41.7658, -72.6734, 'America/New_York', 121054),
('Providence', 'US', 'Rhode Island', 41.8240, -71.4128, 'America/New_York', 190934),
('Teaneck', 'US', 'New Jersey', 40.8976, -74.0160, 'America/New_York', 40892),
('Passaic', 'US', 'New Jersey', 40.8568, -74.1285, 'America/New_York', 71247),
('Elizabeth', 'US', 'New Jersey', 40.6639, -74.2107, 'America/New_York', 137298),
('Monsey', 'US', 'New York', 41.1112, -74.0685, 'America/New_York', 22000),
('Spring Valley', 'US', 'New York', 41.1131, -74.0437, 'America/New_York', 33000),
('White Plains', 'US', 'New York', 41.0340, -73.7629, 'America/New_York', 58109),
('Scarsdale', 'US', 'New York', 40.9887, -73.7846, 'America/New_York', 17890),
('Great Neck', 'US', 'New York', 40.8007, -73.7285, 'America/New_York', 40000),
('Flushing', 'US', 'New York', 40.7654, -73.8318, 'America/New_York', 227000),
('Crown Heights', 'US', 'New York', 40.6694, -73.9422, 'America/New_York', 96000),
('Williamsburg', 'US', 'New York', 40.7081, -73.9571, 'America/New_York', 151000),
('Boro Park', 'US', 'New York', 40.6340, -73.9920, 'America/New_York', 120000),
('Flatbush', 'US', 'New York', 40.6414, -73.9595, 'America/New_York', 110000),
('Kew Gardens', 'US', 'New York', 40.7142, -73.8303, 'America/New_York', 20500),
('Far Rockaway', 'US', 'New York', 40.6053, -73.7559, 'America/New_York', 69000),
('Lawrence', 'US', 'New York', 40.6157, -73.7296, 'America/New_York', 6800),
('Cedarhurst', 'US', 'New York', 40.6237, -73.7240, 'America/New_York', 6592),
('Woodmere', 'US', 'New York', 40.6326, -73.7129, 'America/New_York', 17000),
('Boca Raton', 'US', 'Florida', 26.3683, -80.1289, 'America/New_York', 99805),
('Fort Lauderdale', 'US', 'Florida', 26.1224, -80.1373, 'America/New_York', 182760),
('Hollywood', 'US', 'Florida', 26.0112, -80.1495, 'America/New_York', 154823),
('West Palm Beach', 'US', 'Florida', 26.7153, -80.0534, 'America/New_York', 117415),
('Aventura', 'US', 'Florida', 25.9565, -80.1392, 'America/New_York', 40242),
('Surfside', 'US', 'Florida', 25.8784, -80.1256, 'America/New_York', 5751),
('Bal Harbour', 'US', 'Florida', 25.8942, -80.1256, 'America/New_York', 3305),
('Scottsdale', 'US', 'Arizona', 33.4942, -111.9261, 'America/Phoenix', 258069),
('Tucson', 'US', 'Arizona', 32.2226, -110.9747, 'America/Phoenix', 548073)
ON CONFLICT DO NOTHING;

-- Additional Israel Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Ramat Gan', 'IL', 'Tel Aviv', 32.0700, 34.8237, 'Asia/Jerusalem', 163480),
('Holon', 'IL', 'Tel Aviv', 32.0111, 34.7722, 'Asia/Jerusalem', 196282),
('Bat Yam', 'IL', 'Tel Aviv', 32.0171, 34.7510, 'Asia/Jerusalem', 159064),
('Herzliya', 'IL', 'Tel Aviv', 32.1626, 34.8455, 'Asia/Jerusalem', 97470),
('Kfar Saba', 'IL', 'Central', 32.1781, 34.9065, 'Asia/Jerusalem', 105000),
('Raanana', 'IL', 'Central', 32.1836, 34.8714, 'Asia/Jerusalem', 80000),
('Rehovot', 'IL', 'Central', 31.8928, 34.8113, 'Asia/Jerusalem', 143904),
('Rishon LeZion', 'IL', 'Central', 31.9642, 34.8049, 'Asia/Jerusalem', 254384),
('Ashkelon', 'IL', 'Southern', 31.6690, 34.5715, 'Asia/Jerusalem', 144073),
('Eilat', 'IL', 'Southern', 29.5581, 34.9482, 'Asia/Jerusalem', 52555),
('Tiberias', 'IL', 'Northern', 32.7922, 35.5312, 'Asia/Jerusalem', 46200),
('Nahariya', 'IL', 'Northern', 33.0069, 35.0978, 'Asia/Jerusalem', 59200),
('Akko', 'IL', 'Northern', 32.9261, 35.0764, 'Asia/Jerusalem', 48930),
('Karmiel', 'IL', 'Northern', 32.9196, 35.3050, 'Asia/Jerusalem', 48800),
('Afula', 'IL', 'Northern', 32.6065, 35.2898, 'Asia/Jerusalem', 55600),
('Beit Shemesh', 'IL', 'Jerusalem', 31.7471, 34.9887, 'Asia/Jerusalem', 130000),
('Elad', 'IL', 'Central', 32.0520, 34.9510, 'Asia/Jerusalem', 54000),
('Beitar Illit', 'IL', 'Jerusalem', 31.6939, 35.1233, 'Asia/Jerusalem', 62000),
('Kiryat Gat', 'IL', 'Southern', 31.6100, 34.7642, 'Asia/Jerusalem', 59400),
('Dimona', 'IL', 'Southern', 31.0686, 35.0329, 'Asia/Jerusalem', 36300)
ON CONFLICT DO NOTHING;

-- Additional UK Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Liverpool', 'GB', 'Merseyside', 53.4084, -2.9916, 'Europe/London', 498042),
('Bristol', 'GB', 'South West', 51.4545, -2.5879, 'Europe/London', 467099),
('Edinburgh', 'GB', 'Scotland', 55.9533, -3.1883, 'Europe/London', 524930),
('Sheffield', 'GB', 'South Yorkshire', 53.3811, -1.4701, 'Europe/London', 584853),
('Brighton', 'GB', 'East Sussex', 50.8225, -0.1372, 'Europe/London', 290395),
('Newcastle', 'GB', 'Tyne and Wear', 54.9783, -1.6178, 'Europe/London', 302820),
('Nottingham', 'GB', 'East Midlands', 52.9548, -1.1581, 'Europe/London', 321500),
('Leicester', 'GB', 'East Midlands', 52.6369, -1.1398, 'Europe/London', 354224),
('Salford', 'GB', 'Greater Manchester', 53.4875, -2.2901, 'Europe/London', 103886),
('Prestwich', 'GB', 'Greater Manchester', 53.5316, -2.2856, 'Europe/London', 35000),
('Golders Green', 'GB', 'Greater London', 51.5724, -0.1940, 'Europe/London', 30000),
('Hendon', 'GB', 'Greater London', 51.5836, -0.2268, 'Europe/London', 56000),
('Stamford Hill', 'GB', 'Greater London', 51.5763, -0.0729, 'Europe/London', 40000),
('Edgware', 'GB', 'Greater London', 51.6137, -0.2750, 'Europe/London', 80000)
ON CONFLICT DO NOTHING;

-- Additional Canada Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Calgary', 'CA', 'Alberta', 51.0447, -114.0719, 'America/Edmonton', 1336000),
('Edmonton', 'CA', 'Alberta', 53.5461, -113.4938, 'America/Edmonton', 1010899),
('Ottawa', 'CA', 'Ontario', 45.4215, -75.6972, 'America/Toronto', 1017449),
('Winnipeg', 'CA', 'Manitoba', 49.8951, -97.1384, 'America/Winnipeg', 778489),
('Halifax', 'CA', 'Nova Scotia', 44.6488, -63.5752, 'America/Halifax', 439819),
('Hamilton', 'CA', 'Ontario', 43.2557, -79.8711, 'America/Toronto', 579200),
('Thornhill', 'CA', 'Ontario', 43.8101, -79.4163, 'America/Toronto', 111000),
('North York', 'CA', 'Ontario', 43.7615, -79.4111, 'America/Toronto', 650000),
('Downsview', 'CA', 'Ontario', 43.7532, -79.4428, 'America/Toronto', 53000)
ON CONFLICT DO NOTHING;

-- Additional Australia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Brisbane', 'AU', 'Queensland', -27.4698, 153.0251, 'Australia/Brisbane', 2514184),
('Perth', 'AU', 'Western Australia', -31.9505, 115.8605, 'Australia/Perth', 2125114),
('Adelaide', 'AU', 'South Australia', -34.9285, 138.6007, 'Australia/Adelaide', 1376601),
('Gold Coast', 'AU', 'Queensland', -28.0167, 153.4000, 'Australia/Brisbane', 679127),
('Canberra', 'AU', 'Australian Capital Territory', -35.2809, 149.1300, 'Australia/Sydney', 453558),
('St Kilda', 'AU', 'Victoria', -37.8676, 144.9807, 'Australia/Melbourne', 23000),
('Caulfield', 'AU', 'Victoria', -37.8770, 145.0232, 'Australia/Melbourne', 45000)
ON CONFLICT DO NOTHING;

-- Additional France Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Nice', 'FR', 'Provence-Alpes-Cote Azur', 43.7102, 7.2620, 'Europe/Paris', 340017),
('Toulouse', 'FR', 'Occitanie', 43.6047, 1.4442, 'Europe/Paris', 479553),
('Bordeaux', 'FR', 'Nouvelle-Aquitaine', 44.8378, -0.5792, 'Europe/Paris', 257068),
('Lille', 'FR', 'Hauts-de-France', 50.6292, 3.0573, 'Europe/Paris', 234475),
('Nantes', 'FR', 'Pays de la Loire', 47.2184, -1.5536, 'Europe/Paris', 314138),
('Montpellier', 'FR', 'Occitanie', 43.6108, 3.8767, 'Europe/Paris', 285121),
('Sarcelles', 'FR', 'Ile-de-France', 48.9953, 2.3808, 'Europe/Paris', 58000),
('Neuilly-sur-Seine', 'FR', 'Ile-de-France', 48.8846, 2.2686, 'Europe/Paris', 60853),
('Boulogne-Billancourt', 'FR', 'Ile-de-France', 48.8397, 2.2399, 'Europe/Paris', 121334)
ON CONFLICT DO NOTHING;

-- Additional Germany Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Hamburg', 'DE', 'Hamburg', 53.5511, 9.9937, 'Europe/Berlin', 1899160),
('Cologne', 'DE', 'North Rhine-Westphalia', 50.9375, 6.9603, 'Europe/Berlin', 1085664),
('Dusseldorf', 'DE', 'North Rhine-Westphalia', 51.2277, 6.7735, 'Europe/Berlin', 619294),
('Stuttgart', 'DE', 'Baden-Wurttemberg', 48.7758, 9.1829, 'Europe/Berlin', 634830),
('Hanover', 'DE', 'Lower Saxony', 52.3759, 9.7320, 'Europe/Berlin', 532163),
('Leipzig', 'DE', 'Saxony', 51.3397, 12.3731, 'Europe/Berlin', 593145),
('Dresden', 'DE', 'Saxony', 51.0504, 13.7373, 'Europe/Berlin', 556780),
('Nuremberg', 'DE', 'Bavaria', 49.4521, 11.0767, 'Europe/Berlin', 518365)
ON CONFLICT DO NOTHING;

-- Belgium Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Brussels', 'BE', 'Brussels-Capital', 50.8503, 4.3517, 'Europe/Brussels', 1209000),
('Antwerp', 'BE', 'Flanders', 51.2194, 4.4025, 'Europe/Brussels', 523248),
('Ghent', 'BE', 'Flanders', 51.0543, 3.7174, 'Europe/Brussels', 262219),
('Liege', 'BE', 'Wallonia', 50.6326, 5.5797, 'Europe/Brussels', 197355)
ON CONFLICT DO NOTHING;

-- Netherlands Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Amsterdam', 'NL', 'North Holland', 52.3676, 4.9041, 'Europe/Amsterdam', 872680),
('Rotterdam', 'NL', 'South Holland', 51.9244, 4.4777, 'Europe/Amsterdam', 651446),
('The Hague', 'NL', 'South Holland', 52.0705, 4.3007, 'Europe/Amsterdam', 545838),
('Utrecht', 'NL', 'Utrecht', 52.0907, 5.1214, 'Europe/Amsterdam', 357179)
ON CONFLICT DO NOTHING;

-- Switzerland Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Zurich', 'CH', 'Zurich', 47.3769, 8.5417, 'Europe/Zurich', 434008),
('Geneva', 'CH', 'Geneva', 46.2044, 6.1432, 'Europe/Zurich', 203840),
('Basel', 'CH', 'Basel-Stadt', 47.5596, 7.5886, 'Europe/Zurich', 178120),
('Bern', 'CH', 'Bern', 46.9480, 7.4474, 'Europe/Zurich', 134794),
('Lausanne', 'CH', 'Vaud', 46.5197, 6.6323, 'Europe/Zurich', 139111)
ON CONFLICT DO NOTHING;

-- Austria Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Vienna', 'AT', 'Vienna', 48.2082, 16.3738, 'Europe/Vienna', 1911191),
('Graz', 'AT', 'Styria', 47.0707, 15.4395, 'Europe/Vienna', 291072),
('Salzburg', 'AT', 'Salzburg', 47.8095, 13.0550, 'Europe/Vienna', 155021),
('Innsbruck', 'AT', 'Tyrol', 47.2692, 11.4041, 'Europe/Vienna', 132493)
ON CONFLICT DO NOTHING;

-- Italy Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Rome', 'IT', 'Lazio', 41.9028, 12.4964, 'Europe/Rome', 2873000),
('Milan', 'IT', 'Lombardy', 45.4642, 9.1900, 'Europe/Rome', 1396059),
('Naples', 'IT', 'Campania', 40.8518, 14.2681, 'Europe/Rome', 967069),
('Turin', 'IT', 'Piedmont', 45.0703, 7.6869, 'Europe/Rome', 870952),
('Florence', 'IT', 'Tuscany', 43.7696, 11.2558, 'Europe/Rome', 382258),
('Venice', 'IT', 'Veneto', 45.4408, 12.3155, 'Europe/Rome', 261905),
('Bologna', 'IT', 'Emilia-Romagna', 44.4949, 11.3426, 'Europe/Rome', 390625)
ON CONFLICT DO NOTHING;

-- Spain Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Madrid', 'ES', 'Community of Madrid', 40.4168, -3.7038, 'Europe/Madrid', 3266126),
('Barcelona', 'ES', 'Catalonia', 41.3851, 2.1734, 'Europe/Madrid', 1620343),
('Valencia', 'ES', 'Valencia', 39.4699, -0.3763, 'Europe/Madrid', 791413),
('Seville', 'ES', 'Andalusia', 37.3891, -5.9845, 'Europe/Madrid', 688711),
('Malaga', 'ES', 'Andalusia', 36.7213, -4.4214, 'Europe/Madrid', 578460),
('Bilbao', 'ES', 'Basque Country', 43.2630, -2.9350, 'Europe/Madrid', 346843)
ON CONFLICT DO NOTHING;

-- Portugal Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Lisbon', 'PT', 'Lisbon', 38.7223, -9.1393, 'Europe/Lisbon', 544851),
('Porto', 'PT', 'Norte', 41.1579, -8.6291, 'Europe/Lisbon', 237591)
ON CONFLICT DO NOTHING;

-- Poland Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Warsaw', 'PL', 'Masovian', 52.2297, 21.0122, 'Europe/Warsaw', 1790658),
('Krakow', 'PL', 'Lesser Poland', 50.0647, 19.9450, 'Europe/Warsaw', 779115),
('Lodz', 'PL', 'Lodz', 51.7592, 19.4550, 'Europe/Warsaw', 685285),
('Wroclaw', 'PL', 'Lower Silesian', 51.1079, 17.0385, 'Europe/Warsaw', 643782),
('Gdansk', 'PL', 'Pomeranian', 54.3520, 18.6466, 'Europe/Warsaw', 470907)
ON CONFLICT DO NOTHING;

-- Hungary Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Budapest', 'HU', 'Central Hungary', 47.4979, 19.0402, 'Europe/Budapest', 1756000),
('Debrecen', 'HU', 'Northern Great Plain', 47.5316, 21.6273, 'Europe/Budapest', 203506)
ON CONFLICT DO NOTHING;

-- Czech Republic Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Prague', 'CZ', 'Prague', 50.0755, 14.4378, 'Europe/Prague', 1335084),
('Brno', 'CZ', 'South Moravian', 49.1951, 16.6068, 'Europe/Prague', 382405)
ON CONFLICT DO NOTHING;

-- Russia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Moscow', 'RU', 'Central', 55.7558, 37.6173, 'Europe/Moscow', 12655050),
('Saint Petersburg', 'RU', 'Northwestern', 59.9311, 30.3609, 'Europe/Moscow', 5383890)
ON CONFLICT DO NOTHING;

-- Ukraine Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Kyiv', 'UA', 'Kyiv', 50.4501, 30.5234, 'Europe/Kiev', 2962180),
('Kharkiv', 'UA', 'Kharkiv', 49.9935, 36.2304, 'Europe/Kiev', 1433886),
('Odessa', 'UA', 'Odessa', 46.4825, 30.7233, 'Europe/Kiev', 1017022),
('Dnipro', 'UA', 'Dnipropetrovsk', 48.4647, 35.0462, 'Europe/Kiev', 993094)
ON CONFLICT DO NOTHING;

-- Romania Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Bucharest', 'RO', 'Bucharest', 44.4268, 26.1025, 'Europe/Bucharest', 1883425),
('Cluj-Napoca', 'RO', 'Cluj', 46.7712, 23.6236, 'Europe/Bucharest', 324576)
ON CONFLICT DO NOTHING;

-- Greece Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Athens', 'GR', 'Attica', 37.9838, 23.7275, 'Europe/Athens', 664046),
('Thessaloniki', 'GR', 'Central Macedonia', 40.6401, 22.9444, 'Europe/Athens', 315196)
ON CONFLICT DO NOTHING;

-- Turkey Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Istanbul', 'TR', 'Istanbul', 41.0082, 28.9784, 'Europe/Istanbul', 15462452),
('Ankara', 'TR', 'Ankara', 39.9334, 32.8597, 'Europe/Istanbul', 5663322),
('Izmir', 'TR', 'Izmir', 38.4192, 27.1287, 'Europe/Istanbul', 4367251)
ON CONFLICT DO NOTHING;

-- Morocco Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Casablanca', 'MA', 'Casablanca-Settat', 33.5731, -7.5898, 'Africa/Casablanca', 3359818),
('Marrakech', 'MA', 'Marrakech-Safi', 31.6295, -7.9811, 'Africa/Casablanca', 928850),
('Rabat', 'MA', 'Rabat-Sale-Kenitra', 34.0209, -6.8416, 'Africa/Casablanca', 577827),
('Fes', 'MA', 'Fes-Meknes', 34.0181, -5.0078, 'Africa/Casablanca', 1112072)
ON CONFLICT DO NOTHING;

-- Tunisia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Tunis', 'TN', 'Tunis', 36.8065, 10.1815, 'Africa/Tunis', 693210),
('Sfax', 'TN', 'Sfax', 34.7406, 10.7603, 'Africa/Tunis', 330440)
ON CONFLICT DO NOTHING;

-- Egypt Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Cairo', 'EG', 'Cairo', 30.0444, 31.2357, 'Africa/Cairo', 9540000),
('Alexandria', 'EG', 'Alexandria', 31.2001, 29.9187, 'Africa/Cairo', 5200000)
ON CONFLICT DO NOTHING;

-- Additional South Africa Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Durban', 'ZA', 'KwaZulu-Natal', -29.8587, 31.0218, 'Africa/Johannesburg', 3720953),
('Pretoria', 'ZA', 'Gauteng', -25.7479, 28.2293, 'Africa/Johannesburg', 2921488),
('Port Elizabeth', 'ZA', 'Eastern Cape', -33.9608, 25.6022, 'Africa/Johannesburg', 1152115)
ON CONFLICT DO NOTHING;

-- Additional Argentina Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Cordoba', 'AR', 'Cordoba', -31.4201, -64.1888, 'America/Argentina/Cordoba', 1391000),
('Rosario', 'AR', 'Santa Fe', -32.9468, -60.6393, 'America/Argentina/Buenos_Aires', 1193605)
ON CONFLICT DO NOTHING;

-- Brazil Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Sao Paulo', 'BR', 'Sao Paulo', -23.5505, -46.6333, 'America/Sao_Paulo', 12325232),
('Rio de Janeiro', 'BR', 'Rio de Janeiro', -22.9068, -43.1729, 'America/Sao_Paulo', 6748000),
('Curitiba', 'BR', 'Parana', -25.4290, -49.2671, 'America/Sao_Paulo', 1948626),
('Porto Alegre', 'BR', 'Rio Grande do Sul', -30.0346, -51.2177, 'America/Sao_Paulo', 1484941),
('Belo Horizonte', 'BR', 'Minas Gerais', -19.9167, -43.9345, 'America/Sao_Paulo', 2722000),
('Salvador', 'BR', 'Bahia', -12.9714, -38.5014, 'America/Bahia', 2886698),
('Recife', 'BR', 'Pernambuco', -8.0476, -34.8770, 'America/Recife', 1653461)
ON CONFLICT DO NOTHING;

-- Chile Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Santiago', 'CL', 'Santiago Metropolitan', -33.4489, -70.6693, 'America/Santiago', 6310000),
('Valparaiso', 'CL', 'Valparaiso', -33.0472, -71.6127, 'America/Santiago', 295000),
('Vina del Mar', 'CL', 'Valparaiso', -33.0153, -71.5500, 'America/Santiago', 334248)
ON CONFLICT DO NOTHING;

-- Colombia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Bogota', 'CO', 'Bogota', 4.7110, -74.0721, 'America/Bogota', 7181469),
('Medellin', 'CO', 'Antioquia', 6.2442, -75.5812, 'America/Bogota', 2569007),
('Cali', 'CO', 'Valle del Cauca', 3.4516, -76.5320, 'America/Bogota', 2227642)
ON CONFLICT DO NOTHING;

-- Peru Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Lima', 'PE', 'Lima', -12.0464, -77.0428, 'America/Lima', 10391000)
ON CONFLICT DO NOTHING;

-- Venezuela Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Caracas', 'VE', 'Capital District', 10.4806, -66.9036, 'America/Caracas', 2245744)
ON CONFLICT DO NOTHING;

-- Panama Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Panama City', 'PA', 'Panama', 9.1025, -79.4518, 'America/Panama', 880691)
ON CONFLICT DO NOTHING;

-- Uruguay Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Montevideo', 'UY', 'Montevideo', -34.9011, -56.1645, 'America/Montevideo', 1319108)
ON CONFLICT DO NOTHING;

-- Costa Rica Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('San Jose', 'CR', 'San Jose', 9.9281, -84.0907, 'America/Costa_Rica', 342188)
ON CONFLICT DO NOTHING;

-- Additional Mexico Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Guadalajara', 'MX', 'Jalisco', 20.6597, -103.3496, 'America/Mexico_City', 1495182),
('Monterrey', 'MX', 'Nuevo Leon', 25.6866, -100.3161, 'America/Monterrey', 1142994),
('Cancun', 'MX', 'Quintana Roo', 21.1619, -86.8515, 'America/Cancun', 888797),
('Tijuana', 'MX', 'Baja California', 32.5149, -117.0382, 'America/Tijuana', 1922523)
ON CONFLICT DO NOTHING;

-- India Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Mumbai', 'IN', 'Maharashtra', 19.0760, 72.8777, 'Asia/Kolkata', 12442373),
('Delhi', 'IN', 'Delhi', 28.7041, 77.1025, 'Asia/Kolkata', 11034555),
('Bangalore', 'IN', 'Karnataka', 12.9716, 77.5946, 'Asia/Kolkata', 8443675),
('Kolkata', 'IN', 'West Bengal', 22.5726, 88.3639, 'Asia/Kolkata', 4496694),
('Chennai', 'IN', 'Tamil Nadu', 13.0827, 80.2707, 'Asia/Kolkata', 4681087),
('Hyderabad', 'IN', 'Telangana', 17.3850, 78.4867, 'Asia/Kolkata', 6809970),
('Kochi', 'IN', 'Kerala', 9.9312, 76.2673, 'Asia/Kolkata', 677381)
ON CONFLICT DO NOTHING;

-- China Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Shanghai', 'CN', 'Shanghai', 31.2304, 121.4737, 'Asia/Shanghai', 24281400),
('Beijing', 'CN', 'Beijing', 39.9042, 116.4074, 'Asia/Shanghai', 21540000),
('Hong Kong', 'CN', 'Hong Kong', 22.3193, 114.1694, 'Asia/Hong_Kong', 7482500),
('Shenzhen', 'CN', 'Guangdong', 22.5431, 114.0579, 'Asia/Shanghai', 12528300),
('Guangzhou', 'CN', 'Guangdong', 23.1291, 113.2644, 'Asia/Shanghai', 13501100)
ON CONFLICT DO NOTHING;

-- Japan Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Tokyo', 'JP', 'Tokyo', 35.6762, 139.6503, 'Asia/Tokyo', 13960000),
('Osaka', 'JP', 'Osaka', 34.6937, 135.5023, 'Asia/Tokyo', 2752412),
('Kyoto', 'JP', 'Kyoto', 35.0116, 135.7681, 'Asia/Tokyo', 1475183),
('Yokohama', 'JP', 'Kanagawa', 35.4437, 139.6380, 'Asia/Tokyo', 3748995),
('Kobe', 'JP', 'Hyogo', 34.6901, 135.1956, 'Asia/Tokyo', 1537272)
ON CONFLICT DO NOTHING;

-- South Korea Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Seoul', 'KR', 'Seoul', 37.5665, 126.9780, 'Asia/Seoul', 9776000),
('Busan', 'KR', 'Busan', 35.1796, 129.0756, 'Asia/Seoul', 3429000)
ON CONFLICT DO NOTHING;

-- Taiwan Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Taipei', 'TW', 'Taipei', 25.0330, 121.5654, 'Asia/Taipei', 2646204),
('Kaohsiung', 'TW', 'Kaohsiung', 22.6273, 120.3014, 'Asia/Taipei', 2765932)
ON CONFLICT DO NOTHING;

-- Singapore
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Singapore', 'SG', 'Singapore', 1.3521, 103.8198, 'Asia/Singapore', 5686000)
ON CONFLICT DO NOTHING;

-- Malaysia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Kuala Lumpur', 'MY', 'Kuala Lumpur', 3.1390, 101.6869, 'Asia/Kuala_Lumpur', 1982112),
('Penang', 'MY', 'Penang', 5.4164, 100.3327, 'Asia/Kuala_Lumpur', 708127)
ON CONFLICT DO NOTHING;

-- Thailand Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Bangkok', 'TH', 'Bangkok', 13.7563, 100.5018, 'Asia/Bangkok', 8305218),
('Chiang Mai', 'TH', 'Chiang Mai', 18.7883, 98.9853, 'Asia/Bangkok', 131091)
ON CONFLICT DO NOTHING;

-- Vietnam Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Ho Chi Minh City', 'VN', 'Ho Chi Minh City', 10.8231, 106.6297, 'Asia/Ho_Chi_Minh', 8993000),
('Hanoi', 'VN', 'Hanoi', 21.0285, 105.8542, 'Asia/Ho_Chi_Minh', 8053663)
ON CONFLICT DO NOTHING;

-- Philippines Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Manila', 'PH', 'Metro Manila', 14.5995, 120.9842, 'Asia/Manila', 1846513),
('Cebu City', 'PH', 'Central Visayas', 10.3157, 123.8854, 'Asia/Manila', 964169)
ON CONFLICT DO NOTHING;

-- Indonesia Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Jakarta', 'ID', 'Jakarta', -6.2088, 106.8456, 'Asia/Jakarta', 10562088),
('Bali', 'ID', 'Bali', -8.4095, 115.1889, 'Asia/Makassar', 4225000),
('Surabaya', 'ID', 'East Java', -7.2575, 112.7521, 'Asia/Jakarta', 2874314)
ON CONFLICT DO NOTHING;

-- New Zealand Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Auckland', 'NZ', 'Auckland', -36.8485, 174.7633, 'Pacific/Auckland', 1571718),
('Wellington', 'NZ', 'Wellington', -41.2865, 174.7762, 'Pacific/Auckland', 215400),
('Christchurch', 'NZ', 'Canterbury', -43.5320, 172.6306, 'Pacific/Auckland', 389700)
ON CONFLICT DO NOTHING;

-- Ireland Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Dublin', 'IE', 'Dublin', 53.3498, -6.2603, 'Europe/Dublin', 544107),
('Cork', 'IE', 'Cork', 51.8985, -8.4756, 'Europe/Dublin', 125622)
ON CONFLICT DO NOTHING;

-- Denmark Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Copenhagen', 'DK', 'Capital Region', 55.6761, 12.5683, 'Europe/Copenhagen', 794128)
ON CONFLICT DO NOTHING;

-- Sweden Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Stockholm', 'SE', 'Stockholm', 59.3293, 18.0686, 'Europe/Stockholm', 975551),
('Gothenburg', 'SE', 'Vastra Gotaland', 57.7089, 11.9746, 'Europe/Stockholm', 583056),
('Malmo', 'SE', 'Skane', 55.6050, 13.0038, 'Europe/Stockholm', 347949)
ON CONFLICT DO NOTHING;

-- Norway Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Oslo', 'NO', 'Oslo', 59.9139, 10.7522, 'Europe/Oslo', 693494),
('Bergen', 'NO', 'Vestland', 60.3913, 5.3221, 'Europe/Oslo', 285601)
ON CONFLICT DO NOTHING;

-- Finland Cities
INSERT INTO cities (name, country_code, region, latitude, longitude, timezone, population) VALUES
('Helsinki', 'FI', 'Uusimaa', 60.1699, 24.9384, 'Europe/Helsinki', 656229)
ON CONFLICT DO NOTHING;

-- Update country column for new cities
UPDATE cities SET country = CASE country_code
    WHEN 'US' THEN 'United States'
    WHEN 'IL' THEN 'Israel'
    WHEN 'GB' THEN 'United Kingdom'
    WHEN 'CA' THEN 'Canada'
    WHEN 'AU' THEN 'Australia'
    WHEN 'FR' THEN 'France'
    WHEN 'ZA' THEN 'South Africa'
    WHEN 'AR' THEN 'Argentina'
    WHEN 'MX' THEN 'Mexico'
    WHEN 'DE' THEN 'Germany'
    WHEN 'BE' THEN 'Belgium'
    WHEN 'NL' THEN 'Netherlands'
    WHEN 'CH' THEN 'Switzerland'
    WHEN 'AT' THEN 'Austria'
    WHEN 'IT' THEN 'Italy'
    WHEN 'ES' THEN 'Spain'
    WHEN 'PT' THEN 'Portugal'
    WHEN 'PL' THEN 'Poland'
    WHEN 'HU' THEN 'Hungary'
    WHEN 'CZ' THEN 'Czech Republic'
    WHEN 'RU' THEN 'Russia'
    WHEN 'UA' THEN 'Ukraine'
    WHEN 'RO' THEN 'Romania'
    WHEN 'GR' THEN 'Greece'
    WHEN 'TR' THEN 'Turkey'
    WHEN 'MA' THEN 'Morocco'
    WHEN 'TN' THEN 'Tunisia'
    WHEN 'EG' THEN 'Egypt'
    WHEN 'BR' THEN 'Brazil'
    WHEN 'CL' THEN 'Chile'
    WHEN 'CO' THEN 'Colombia'
    WHEN 'PE' THEN 'Peru'
    WHEN 'VE' THEN 'Venezuela'
    WHEN 'PA' THEN 'Panama'
    WHEN 'UY' THEN 'Uruguay'
    WHEN 'CR' THEN 'Costa Rica'
    WHEN 'IN' THEN 'India'
    WHEN 'CN' THEN 'China'
    WHEN 'JP' THEN 'Japan'
    WHEN 'KR' THEN 'South Korea'
    WHEN 'TW' THEN 'Taiwan'
    WHEN 'SG' THEN 'Singapore'
    WHEN 'MY' THEN 'Malaysia'
    WHEN 'TH' THEN 'Thailand'
    WHEN 'VN' THEN 'Vietnam'
    WHEN 'PH' THEN 'Philippines'
    WHEN 'ID' THEN 'Indonesia'
    WHEN 'NZ' THEN 'New Zealand'
    WHEN 'IE' THEN 'Ireland'
    WHEN 'DK' THEN 'Denmark'
    WHEN 'SE' THEN 'Sweden'
    WHEN 'NO' THEN 'Norway'
    WHEN 'FI' THEN 'Finland'
    ELSE country_code
END WHERE country IS NULL;
