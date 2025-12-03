-- ============================================
-- ZMANIM LAB - SEED DATA
-- ============================================
-- Seed data for master registry, templates, tags, events, and countries
-- This file should be run after 00000000000000_initial_schema.sql

-- ============================================
-- COUNTRIES SEED DATA
-- ============================================
INSERT INTO countries (code, name) VALUES
    ('US', 'United States'),
    ('IL', 'Israel'),
    ('UK', 'United Kingdom'),
    ('CA', 'Canada'),
    ('AU', 'Australia'),
    ('FR', 'France'),
    ('DE', 'Germany'),
    ('ZA', 'South Africa'),
    ('AR', 'Argentina'),
    ('BR', 'Brazil'),
    ('MX', 'Mexico')
ON CONFLICT (code) DO NOTHING;

-- ============================================
-- ZMAN TAGS SEED DATA
-- ============================================
INSERT INTO zman_tags (tag_key, name, display_name_hebrew, display_name_english, tag_type, color, sort_order) VALUES
    ('gra', 'gra', 'גר"א', 'GRA (Vilna Gaon)', 'shita', '#3B82F6', 1),
    ('mga', 'mga', 'מג"א', 'MGA (Magen Avraham)', 'shita', '#8B5CF6', 2),
    ('rabbeinu_tam', 'rabbeinu_tam', 'ר"ת', 'Rabbeinu Tam', 'shita', '#F59E0B', 3),
    ('baal_hatanya', 'baal_hatanya', 'בעל התניא', 'Baal HaTanya', 'shita', '#10B981', 4),
    ('fixed_minutes', 'fixed_minutes', 'דקות קבועות', 'Fixed Minutes', 'method', '#6366F1', 10),
    ('solar_angle', 'solar_angle', 'זווית שמש', 'Solar Angle', 'method', '#EC4899', 11),
    ('proportional_hours', 'proportional_hours', 'שעות זמניות', 'Proportional Hours', 'method', '#14B8A6', 12)
ON CONFLICT (name) DO UPDATE SET
    tag_key = EXCLUDED.tag_key,
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    tag_type = EXCLUDED.tag_type,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order;

-- ============================================
-- DAY TYPES SEED DATA (deprecated but kept for compatibility)
-- ============================================
INSERT INTO day_types (name, display_name_hebrew, display_name_english, description, parent_type, sort_order) VALUES
    ('weekday', 'יום חול', 'Weekday', 'Regular weekday (Sunday-Thursday)', NULL, 10),
    ('friday', 'יום שישי', 'Friday', 'Friday (Erev Shabbos)', 'weekday', 15),
    ('erev_shabbos', 'ערב שבת', 'Erev Shabbos', 'Friday afternoon before Shabbos', NULL, 20),
    ('shabbos', 'שבת', 'Shabbos', 'Shabbat day', NULL, 25),
    ('motzei_shabbos', 'מוצאי שבת', 'Motzei Shabbos', 'Saturday night after Shabbos', NULL, 30),
    ('erev_yom_tov', 'ערב יום טוב', 'Erev Yom Tov', 'Day before Yom Tov', NULL, 40),
    ('yom_tov', 'יום טוב', 'Yom Tov', 'Festival day (Pesach, Shavuos, Sukkos, etc.)', NULL, 45),
    ('motzei_yom_tov', 'מוצאי יום טוב', 'Motzei Yom Tov', 'Night after Yom Tov', NULL, 50),
    ('chol_hamoed', 'חול המועד', 'Chol HaMoed', 'Intermediate festival days', NULL, 55),
    ('erev_pesach', 'ערב פסח', 'Erev Pesach', 'Day before Pesach', 'erev_yom_tov', 60),
    ('pesach', 'פסח', 'Pesach', 'Passover (first and last days)', 'yom_tov', 61),
    ('erev_shavuos', 'ערב שבועות', 'Erev Shavuos', 'Day before Shavuos', 'erev_yom_tov', 65),
    ('shavuos', 'שבועות', 'Shavuos', 'Feast of Weeks', 'yom_tov', 66),
    ('erev_rosh_hashanah', 'ערב ראש השנה', 'Erev Rosh Hashanah', 'Day before Rosh Hashanah', 'erev_yom_tov', 70),
    ('rosh_hashanah', 'ראש השנה', 'Rosh Hashanah', 'Jewish New Year', 'yom_tov', 71),
    ('erev_yom_kippur', 'ערב יום כיפור', 'Erev Yom Kippur', 'Day before Yom Kippur', 'erev_yom_tov', 75),
    ('yom_kippur', 'יום כיפור', 'Yom Kippur', 'Day of Atonement', 'yom_tov', 76),
    ('erev_sukkos', 'ערב סוכות', 'Erev Sukkos', 'Day before Sukkos', 'erev_yom_tov', 80),
    ('sukkos', 'סוכות', 'Sukkos', 'Feast of Tabernacles', 'yom_tov', 81),
    ('hoshanah_rabbah', 'הושענא רבה', 'Hoshanah Rabbah', '7th day of Sukkos', 'chol_hamoed', 82),
    ('shemini_atzeres', 'שמיני עצרת', 'Shemini Atzeres', '8th day of Sukkos', 'yom_tov', 83),
    ('simchas_torah', 'שמחת תורה', 'Simchas Torah', 'Rejoicing of the Torah', 'yom_tov', 84),
    ('taanis', 'תענית', 'Fast Day', 'General fast day', NULL, 100),
    ('taanis_start', 'תחילת תענית', 'Beginning of Fast', 'Start of a fast day', 'taanis', 101),
    ('taanis_end', 'סוף תענית', 'End of Fast', 'End of a fast day', 'taanis', 102),
    ('tzom_gedaliah', 'צום גדליה', 'Tzom Gedaliah', 'Fast of Gedaliah', 'taanis', 110),
    ('asarah_bteves', 'עשרה בטבת', 'Asarah B''Teves', '10th of Teves', 'taanis', 111),
    ('taanis_esther', 'תענית אסתר', 'Taanis Esther', 'Fast of Esther', 'taanis', 112),
    ('shiva_asar_btamuz', 'שבעה עשר בתמוז', 'Shiva Asar B''Tamuz', '17th of Tamuz', 'taanis', 113),
    ('tisha_bav', 'תשעה באב', 'Tisha B''Av', '9th of Av', 'taanis', 114),
    ('erev_tisha_bav', 'ערב תשעה באב', 'Erev Tisha B''Av', 'Evening before Tisha B''Av when the fast begins at sunset', 'taanis', 115),
    ('rosh_chodesh', 'ראש חודש', 'Rosh Chodesh', 'New month', NULL, 120),
    ('chanukah', 'חנוכה', 'Chanukah', 'Festival of Lights', NULL, 130),
    ('purim', 'פורים', 'Purim', 'Feast of Lots', NULL, 135),
    ('shushan_purim', 'שושן פורים', 'Shushan Purim', 'Purim in walled cities', NULL, 136),
    ('lag_baomer', 'ל"ג בעומר', 'Lag BaOmer', '33rd day of Omer', NULL, 140),
    ('tu_bshvat', 'ט"ו בשבט', 'Tu B''Shvat', 'New Year of Trees', NULL, 145),
    ('yom_haatzmaut', 'יום העצמאות', 'Yom HaAtzmaut', 'Israel Independence Day', NULL, 150),
    ('yom_yerushalayim', 'יום ירושלים', 'Yom Yerushalayim', 'Jerusalem Day', NULL, 151),
    ('yom_hazikaron', 'יום הזיכרון', 'Yom HaZikaron', 'Memorial Day', NULL, 152),
    ('yom_hashoah', 'יום השואה', 'Yom HaShoah', 'Holocaust Remembrance Day', NULL, 153)
ON CONFLICT (name) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    description = EXCLUDED.description,
    parent_type = EXCLUDED.parent_type,
    sort_order = EXCLUDED.sort_order;

-- ============================================
-- JEWISH EVENTS SEED DATA
-- ============================================
INSERT INTO jewish_events (code, name_hebrew, name_english, event_type, duration_days_israel, duration_days_diaspora, fast_start_type, parent_event_code, sort_order) VALUES
    ('shabbos', 'שבת', 'Shabbos', 'weekly', 1, 1, NULL, NULL, 10),
    ('yom_kippur', 'יום כיפור', 'Yom Kippur', 'fast', 1, 1, 'sunset', NULL, 20),
    ('tisha_bav', 'תשעה באב', 'Tisha B''Av', 'fast', 1, 1, 'sunset', NULL, 21),
    ('tzom_gedaliah', 'צום גדליה', 'Tzom Gedaliah', 'fast', 1, 1, 'dawn', NULL, 30),
    ('asarah_bteves', 'עשרה בטבת', 'Asarah B''Teves', 'fast', 1, 1, 'dawn', NULL, 31),
    ('shiva_asar_btamuz', 'שבעה עשר בתמוז', 'Shiva Asar B''Tamuz', 'fast', 1, 1, 'dawn', NULL, 32),
    ('taanis_esther', 'תענית אסתר', 'Taanis Esther', 'fast', 1, 1, 'dawn', NULL, 33),
    ('rosh_hashanah', 'ראש השנה', 'Rosh Hashanah', 'yom_tov', 2, 2, NULL, NULL, 40),
    ('sukkos', 'סוכות', 'Sukkos', 'yom_tov', 1, 2, NULL, NULL, 50),
    ('shemini_atzeres', 'שמיני עצרת', 'Shemini Atzeres', 'yom_tov', 1, 2, NULL, NULL, 51),
    ('pesach_first', 'פסח (ראשון)', 'Pesach (First Days)', 'yom_tov', 1, 2, NULL, NULL, 60),
    ('pesach_last', 'פסח (אחרון)', 'Pesach (Last Days)', 'yom_tov', 1, 2, NULL, NULL, 61),
    ('shavuos', 'שבועות', 'Shavuos', 'yom_tov', 1, 2, NULL, NULL, 70),
    ('rosh_chodesh', 'ראש חודש', 'Rosh Chodesh', 'informational', 1, 1, NULL, NULL, 100),
    ('chanukah', 'חנוכה', 'Chanukah', 'informational', 8, 8, NULL, NULL, 110),
    ('purim', 'פורים', 'Purim', 'informational', 1, 1, NULL, NULL, 120),
    ('shushan_purim', 'שושן פורים', 'Shushan Purim', 'informational', 1, 1, NULL, NULL, 121),
    ('lag_baomer', 'ל"ג בעומר', 'Lag BaOmer', 'informational', 1, 1, NULL, NULL, 130),
    ('tu_bshvat', 'ט"ו בשבט', 'Tu B''Shvat', 'informational', 1, 1, NULL, NULL, 140),
    ('yom_haatzmaut', 'יום העצמאות', 'Yom HaAtzmaut', 'informational', 1, 1, NULL, NULL, 150),
    ('yom_yerushalayim', 'יום ירושלים', 'Yom Yerushalayim', 'informational', 1, 1, NULL, NULL, 151),
    ('yom_hazikaron', 'יום הזיכרון', 'Yom HaZikaron', 'informational', 1, 1, NULL, NULL, 152),
    ('yom_hashoah', 'יום השואה', 'Yom HaShoah', 'informational', 1, 1, NULL, NULL, 153)
ON CONFLICT (code) DO UPDATE SET
    name_hebrew = EXCLUDED.name_hebrew,
    name_english = EXCLUDED.name_english,
    event_type = EXCLUDED.event_type,
    duration_days_israel = EXCLUDED.duration_days_israel,
    duration_days_diaspora = EXCLUDED.duration_days_diaspora,
    fast_start_type = EXCLUDED.fast_start_type,
    parent_event_code = EXCLUDED.parent_event_code,
    sort_order = EXCLUDED.sort_order;

-- ============================================
-- ASTRONOMICAL PRIMITIVES SEED DATA
-- ============================================
INSERT INTO astronomical_primitives (variable_name, display_name, description, formula_dsl, category, calculation_type, solar_angle, is_dawn, edge_type, sort_order) VALUES
    ('sunrise', 'Sunrise', 'Geometric sunrise - sun center crosses the horizon (0°)', 'sunrise', 'horizon', 'horizon', NULL, true, 'center', 100),
    ('sunset', 'Sunset', 'Geometric sunset - sun center crosses the horizon (0°)', 'sunset', 'horizon', 'horizon', NULL, false, 'center', 101),
    ('sunrise_visible', 'Sunrise (Visible)', 'First visible edge of sun appears above horizon (accounting for refraction)', 'visible_sunrise', 'horizon', 'horizon', NULL, true, 'top_edge', 102),
    ('sunset_visible', 'Sunset (Visible)', 'Last visible edge of sun disappears below horizon (accounting for refraction)', 'visible_sunset', 'horizon', 'horizon', NULL, false, 'top_edge', 103),
    ('civil_dawn', 'Civil Dawn', 'Sun 6° below horizon - enough light for outdoor activities without artificial light', 'solar(6, before_sunrise)', 'civil_twilight', 'solar_angle', 6.0, true, 'center', 200),
    ('civil_dusk', 'Civil Dusk', 'Sun 6° below horizon - artificial light needed for outdoor activities', 'solar(6, after_sunset)', 'civil_twilight', 'solar_angle', 6.0, false, 'center', 201),
    ('nautical_dawn', 'Nautical Dawn', 'Sun 12° below horizon - horizon visible at sea for navigation', 'solar(12, before_sunrise)', 'nautical_twilight', 'solar_angle', 12.0, true, 'center', 300),
    ('nautical_dusk', 'Nautical Dusk', 'Sun 12° below horizon - horizon no longer visible at sea', 'solar(12, after_sunset)', 'nautical_twilight', 'solar_angle', 12.0, false, 'center', 301),
    ('astronomical_dawn', 'Astronomical Dawn', 'Sun 18° below horizon - sky completely dark before this, first hint of light', 'solar(18, before_sunrise)', 'astronomical_twilight', 'solar_angle', 18.0, true, 'center', 400),
    ('astronomical_dusk', 'Astronomical Dusk', 'Sun 18° below horizon - sky becomes completely dark after this', 'solar(18, after_sunset)', 'astronomical_twilight', 'solar_angle', 18.0, false, 'center', 401),
    ('solar_noon', 'Solar Noon', 'Sun at highest point in the sky (transit/meridian crossing)', 'solar_noon', 'solar_position', 'transit', NULL, NULL, 'center', 500),
    ('solar_midnight', 'Solar Midnight', 'Sun at lowest point (anti-transit) - opposite side of Earth', 'solar_midnight', 'solar_position', 'transit', NULL, NULL, 'center', 501)
ON CONFLICT (variable_name) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    description = EXCLUDED.description,
    formula_dsl = EXCLUDED.formula_dsl,
    category = EXCLUDED.category,
    calculation_type = EXCLUDED.calculation_type,
    solar_angle = EXCLUDED.solar_angle,
    is_dawn = EXCLUDED.is_dawn,
    edge_type = EXCLUDED.edge_type,
    sort_order = EXCLUDED.sort_order;

-- ============================================
-- ZMANIM TEMPLATES SEED DATA
-- ============================================
INSERT INTO zmanim_templates (zman_key, hebrew_name, english_name, formula_dsl, category, is_required, sort_order) VALUES
    ('alos_hashachar', 'עלות השחר', 'Alos Hashachar (Dawn)', 'solar(16.1, before_sunrise)', 'essential', true, 1),
    ('misheyakir', 'משיכיר', 'Misheyakir', 'solar(11.5, before_sunrise)', 'essential', true, 2),
    ('sunrise', 'הנץ החמה', 'Sunrise', 'sunrise', 'essential', true, 3),
    ('sof_zman_shma_gra', 'סוף זמן ק"ש גר"א', 'Latest Shema (GRA)', 'proportional_hours(3, gra)', 'essential', true, 4),
    ('sof_zman_shma_mga', 'סוף זמן ק"ש מג"א', 'Latest Shema (MGA)', 'proportional_hours(3, mga)', 'essential', true, 5),
    ('sof_zman_tfila_gra', 'סוף זמן תפילה גר"א', 'Latest Shacharit (GRA)', 'proportional_hours(4, gra)', 'essential', true, 6),
    ('chatzos', 'חצות היום', 'Chatzos (Midday)', 'solar_noon', 'essential', true, 7),
    ('mincha_gedola', 'מנחה גדולה', 'Mincha Gedola', 'solar_noon + 30min', 'essential', true, 8),
    ('mincha_ketana', 'מנחה קטנה', 'Mincha Ketana', 'proportional_hours(9.5, gra)', 'essential', true, 9),
    ('plag_hamincha', 'פלג המנחה', 'Plag HaMincha', 'proportional_hours(10.75, gra)', 'essential', true, 10),
    ('sunset', 'שקיעה', 'Sunset', 'sunset', 'essential', true, 11),
    ('tzais', 'צאת הכוכבים', 'Tzais (Nightfall)', 'solar(8.5, after_sunset)', 'essential', true, 12),
    ('sof_zman_tfila_mga', 'סוף זמן תפילה מג"א', 'Latest Shacharit (MGA)', 'proportional_hours(4, mga)', 'optional', false, 20),
    ('alos_72', 'עלות 72 דקות', 'Alos 72 Minutes', 'sunrise - 72min', 'optional', false, 21),
    ('alos_90', 'עלות 90 דקות', 'Alos 90 Minutes', 'sunrise - 90min', 'optional', false, 22),
    ('alos_120', 'עלות 120 דקות', 'Alos 120 Minutes', 'sunrise - 120min', 'optional', false, 23),
    ('tzais_72', 'צאת ר"ת', 'Tzais Rabbeinu Tam (72 min)', 'sunset + 72min', 'optional', false, 24),
    ('tzais_42', 'צאת 42 דקות', 'Tzais 42 Minutes', 'sunset + 42min', 'optional', false, 25),
    ('tzais_50', 'צאת 50 דקות', 'Tzais 50 Minutes', 'sunset + 50min', 'optional', false, 26),
    ('tzais_3_stars', 'צאת 3 כוכבים', 'Tzais 3 Stars', 'solar(8.5, after_sunset)', 'optional', false, 27),
    ('candle_lighting', 'הדלקת נרות', 'Candle Lighting', 'sunset - 18min', 'optional', false, 28),
    ('candle_lighting_20', 'הדלקת נרות (ירושלים)', 'Candle Lighting (Jerusalem)', 'sunset - 20min', 'optional', false, 29),
    ('candle_lighting_40', 'הדלקת נרות (40 דקות)', 'Candle Lighting (40 min)', 'sunset - 40min', 'optional', false, 30),
    ('shkia_amitis', 'שקיעה אמיתית', 'True Sunset', 'sunset', 'optional', false, 31),
    ('chatzos_layla', 'חצות לילה', 'Chatzos Layla (Midnight)', 'solar_noon + 12hr', 'optional', false, 32),
    ('samuch_lmincha', 'סמוך למנחה קטנה', 'Samuch L''Mincha Ketana', 'proportional_hours(9, gra)', 'optional', false, 33),
    ('bein_hashmashos', 'בין השמשות', 'Bein Hashmashos', 'sunset', 'optional', false, 34),
    ('kiddush_levana_earliest', 'קידוש לבנה מוקדם', 'Earliest Kiddush Levana', 'sunset + 72min', 'optional', false, 40),
    ('kiddush_levana_latest', 'סוף קידוש לבנה', 'Latest Kiddush Levana', 'sunset', 'optional', false, 41)
ON CONFLICT (zman_key) DO UPDATE SET
    hebrew_name = EXCLUDED.hebrew_name,
    english_name = EXCLUDED.english_name,
    formula_dsl = EXCLUDED.formula_dsl,
    category = EXCLUDED.category,
    is_required = EXCLUDED.is_required,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();

-- ============================================
-- MASTER ZMANIM REGISTRY SEED DATA
-- ============================================
INSERT INTO master_zmanim_registry (zman_key, canonical_hebrew_name, canonical_english_name, transliteration, time_category, default_formula_dsl, is_core, sort_order, description) VALUES
    -- ============================================
    -- DAWN (עלות השחר) - Time Category: dawn
    -- ============================================
    ('alos_hashachar', 'עלות השחר', 'Dawn (Alos Hashachar)', 'Alos Hashachar', 'dawn', 'solar(16.1, before_sunrise)', true, 100, 'Dawn - when the first light appears on the eastern horizon (16.1° below horizon)'),
    ('alos_16_1', 'עלות השחר 16.1°', 'Dawn (16.1°)', 'Alos 16.1', 'dawn', 'solar(16.1, before_sunrise)', false, 101, 'Dawn calculated at 16.1° solar depression'),
    ('alos_18', 'עלות השחר 18°', 'Dawn (18°)', 'Alos 18', 'dawn', 'solar(18, before_sunrise)', false, 102, 'Dawn at astronomical twilight (18°)'),
    ('alos_19_8', 'עלות השחר 19.8°', 'Dawn (19.8°)', 'Alos 19.8', 'dawn', 'solar(19.8, before_sunrise)', false, 103, 'Dawn at 19.8° - stricter opinion'),
    ('alos_26', 'עלות השחר 26°', 'Dawn (26°)', 'Alos 26', 'dawn', 'solar(26, before_sunrise)', false, 104, 'Dawn at 26° - very stringent'),
    ('alos_72', 'עלות השחר 72 דקות', 'Dawn (72 minutes)', 'Alos 72', 'dawn', 'sunrise - 72min', false, 110, 'Dawn 72 fixed minutes before sunrise'),
    ('alos_90', 'עלות השחר 90 דקות', 'Dawn (90 minutes)', 'Alos 90', 'dawn', 'sunrise - 90min', false, 111, 'Dawn 90 fixed minutes before sunrise'),
    ('alos_96', 'עלות השחר 96 דקות', 'Dawn (96 minutes)', 'Alos 96', 'dawn', 'sunrise - 96min', false, 112, 'Dawn 96 fixed minutes before sunrise'),
    ('alos_120', 'עלות השחר 120 דקות', 'Dawn (120 minutes)', 'Alos 120', 'dawn', 'sunrise - 120min', false, 113, 'Dawn 120 fixed minutes before sunrise (2 hours)'),

    -- ============================================
    -- SUNRISE (הנץ החמה) - Time Category: sunrise
    -- ============================================
    ('misheyakir', 'משיכיר', 'Misheyakir', 'Misheyakir', 'sunrise', 'solar(11.5, before_sunrise)', false, 200, 'Earliest time to put on tallit and tefillin'),
    ('misheyakir_10_2', 'משיכיר 10.2°', 'Misheyakir (10.2°)', 'Misheyakir 10.2', 'sunrise', 'solar(10.2, before_sunrise)', false, 201, 'Misheyakir at 10.2° solar depression'),
    ('misheyakir_11', 'משיכיר 11°', 'Misheyakir (11°)', 'Misheyakir 11', 'sunrise', 'solar(11, before_sunrise)', false, 202, 'Misheyakir at 11° solar depression'),
    ('misheyakir_7_65', 'משיכיר 7.65°', 'Misheyakir (7.65°)', 'Misheyakir 7.65', 'sunrise', 'solar(7.65, before_sunrise)', false, 203, 'Misheyakir at 7.65° - lenient opinion'),
    ('sunrise', 'הנץ החמה', 'Sunrise', 'Netz Hachama', 'sunrise', 'sunrise', true, 210, 'Geometric/sea-level sunrise'),
    ('visible_sunrise', 'הנץ הנראה', 'Visible Sunrise', 'Hanetz Hanireh', 'sunrise', 'visible_sunrise', false, 211, 'Actual visible sunrise accounting for refraction'),

    -- ============================================
    -- MORNING (בוקר) - Time Category: morning
    -- ============================================
    ('sof_zman_shma_gra', 'סוף זמן ק"ש גר"א', 'Latest Shema (GRA)', 'Sof Zman Shma GRA', 'morning', 'proportional_hours(3, gra)', true, 300, 'Latest time for Shema - 3 proportional hours (GRA)'),
    ('sof_zman_shma_mga', 'סוף זמן ק"ש מג"א', 'Latest Shema (MGA)', 'Sof Zman Shma MGA', 'morning', 'proportional_hours(3, mga)', false, 301, 'Latest time for Shema - 3 proportional hours (MGA from 72min dawn)'),
    ('sof_zman_shma_mga_90', 'סוף זמן ק"ש מג"א 90', 'Latest Shema (MGA 90)', 'Sof Zman Shma MGA 90', 'morning', 'proportional_hours(3, mga_90)', false, 302, 'Latest time for Shema (MGA from 90min dawn)'),
    ('sof_zman_shma_mga_120', 'סוף זמן ק"ש מג"א 120', 'Latest Shema (MGA 120)', 'Sof Zman Shma MGA 120', 'morning', 'proportional_hours(3, mga_120)', false, 303, 'Latest time for Shema (MGA from 120min dawn)'),
    ('sof_zman_shma_16_1', 'סוף זמן ק"ש 16.1°', 'Latest Shema (16.1°)', 'Sof Zman Shma 16.1', 'morning', 'proportional_hours(3, alos_16_1)', false, 304, 'Latest Shema based on 16.1° alos'),
    ('sof_zman_tfila_gra', 'סוף זמן תפילה גר"א', 'Latest Shacharit (GRA)', 'Sof Zman Tefilla GRA', 'morning', 'proportional_hours(4, gra)', true, 310, 'Latest time for Shacharit - 4 proportional hours (GRA)'),
    ('sof_zman_tfila_mga', 'סוף זמן תפילה מג"א', 'Latest Shacharit (MGA)', 'Sof Zman Tefilla MGA', 'morning', 'proportional_hours(4, mga)', false, 311, 'Latest time for Shacharit - 4 proportional hours (MGA)'),
    ('sof_zman_tfila_mga_90', 'סוף זמן תפילה מג"א 90', 'Latest Shacharit (MGA 90)', 'Sof Zman Tefilla MGA 90', 'morning', 'proportional_hours(4, mga_90)', false, 312, 'Latest Shacharit (MGA from 90min dawn)'),
    ('sof_zman_tfila_mga_120', 'סוף זמן תפילה מג"א 120', 'Latest Shacharit (MGA 120)', 'Sof Zman Tefilla MGA 120', 'morning', 'proportional_hours(4, mga_120)', false, 313, 'Latest Shacharit (MGA from 120min dawn)'),
    ('sof_zman_achilas_chametz_gra', 'סוף זמן אכילת חמץ גר"א', 'Latest Eating Chametz (GRA)', 'Sof Achilat Chametz GRA', 'morning', 'proportional_hours(4, gra)', false, 320, 'Latest time to eat chametz on Erev Pesach (GRA)'),
    ('sof_zman_achilas_chametz_mga', 'סוף זמן אכילת חמץ מג"א', 'Latest Eating Chametz (MGA)', 'Sof Achilat Chametz MGA', 'morning', 'proportional_hours(4, mga)', false, 321, 'Latest time to eat chametz on Erev Pesach (MGA)'),
    ('sof_zman_biur_chametz_gra', 'סוף זמן ביעור חמץ גר"א', 'Latest Burning Chametz (GRA)', 'Sof Biur Chametz GRA', 'morning', 'proportional_hours(5, gra)', false, 322, 'Latest time to burn chametz on Erev Pesach (GRA)'),
    ('sof_zman_biur_chametz_mga', 'סוף זמן ביעור חמץ מג"א', 'Latest Burning Chametz (MGA)', 'Sof Biur Chametz MGA', 'morning', 'proportional_hours(5, mga)', false, 323, 'Latest time to burn chametz on Erev Pesach (MGA)'),

    -- ============================================
    -- MIDDAY (חצות) - Time Category: midday
    -- ============================================
    ('chatzos', 'חצות היום', 'Midday (Chatzos)', 'Chatzos', 'midday', 'solar_noon', true, 400, 'Solar noon - midpoint between sunrise and sunset'),
    ('mincha_gedola', 'מנחה גדולה', 'Earliest Mincha', 'Mincha Gedola', 'midday', 'solar_noon + 30min', true, 410, 'Earliest time for Mincha - 30 minutes after chatzos'),
    ('mincha_gedola_16_1', 'מנחה גדולה 16.1°', 'Earliest Mincha (16.1°)', 'Mincha Gedola 16.1', 'midday', 'proportional_hours(6.5, alos_16_1)', false, 411, 'Earliest Mincha based on 16.1° calculation'),
    ('mincha_gedola_30', 'מנחה גדולה 30 דקות', 'Earliest Mincha (30 min)', 'Mincha Gedola 30', 'midday', 'solar_noon + 30min', false, 412, 'Earliest Mincha - exactly 30 minutes after chatzos'),

    -- ============================================
    -- AFTERNOON (אחר הצהריים) - Time Category: afternoon
    -- ============================================
    ('mincha_ketana', 'מנחה קטנה', 'Mincha Ketana', 'Mincha Ketana', 'afternoon', 'proportional_hours(9.5, gra)', true, 500, 'Mincha Ketana - 9.5 proportional hours'),
    ('mincha_ketana_16_1', 'מנחה קטנה 16.1°', 'Mincha Ketana (16.1°)', 'Mincha Ketana 16.1', 'afternoon', 'proportional_hours(9.5, alos_16_1)', false, 501, 'Mincha Ketana based on 16.1° calculation'),
    ('mincha_ketana_72', 'מנחה קטנה 72 דקות', 'Mincha Ketana (72 min)', 'Mincha Ketana 72', 'afternoon', 'proportional_hours(9.5, mga)', false, 502, 'Mincha Ketana (MGA 72 minute day)'),
    ('samuch_lmincha_ketana', 'סמוך למנחה קטנה', 'Samuch L''Mincha Ketana', 'Samuch LMincha', 'afternoon', 'proportional_hours(9, gra)', false, 505, 'Half hour before Mincha Ketana'),
    ('plag_hamincha', 'פלג המנחה', 'Plag HaMincha', 'Plag Hamincha', 'afternoon', 'proportional_hours(10.75, gra)', true, 510, 'Plag HaMincha - 10.75 proportional hours (1.25 hours before sunset)'),
    ('plag_hamincha_16_1', 'פלג המנחה 16.1°', 'Plag HaMincha (16.1°)', 'Plag Hamincha 16.1', 'afternoon', 'proportional_hours(10.75, alos_16_1)', false, 511, 'Plag HaMincha based on 16.1° calculation'),
    ('plag_hamincha_72', 'פלג המנחה 72 דקות', 'Plag HaMincha (72 min)', 'Plag Hamincha 72', 'afternoon', 'proportional_hours(10.75, mga)', false, 512, 'Plag HaMincha (MGA 72 minute day)'),

    -- ============================================
    -- SUNSET (שקיעה) - Time Category: sunset
    -- ============================================
    ('candle_lighting', 'הדלקת נרות', 'Candle Lighting', 'Hadlakas Neiros', 'sunset', 'sunset - 18min', false, 590, 'Shabbat candle lighting - 18 minutes before sunset'),
    ('candle_lighting_15', 'הדלקת נרות 15 דקות', 'Candle Lighting (15 min)', 'Hadlakas Neiros 15', 'sunset', 'sunset - 15min', false, 591, 'Candle lighting 15 minutes before sunset'),
    ('candle_lighting_18', 'הדלקת נרות 18 דקות', 'Candle Lighting (18 min)', 'Hadlakas Neiros 18', 'sunset', 'sunset - 18min', false, 592, 'Candle lighting 18 minutes before sunset (standard)'),
    ('candle_lighting_20', 'הדלקת נרות 20 דקות', 'Candle Lighting (20 min)', 'Hadlakas Neiros 20', 'sunset', 'sunset - 20min', false, 593, 'Candle lighting 20 minutes before sunset (Jerusalem)'),
    ('candle_lighting_22', 'הדלקת נרות 22 דקות', 'Candle Lighting (22 min)', 'Hadlakas Neiros 22', 'sunset', 'sunset - 22min', false, 594, 'Candle lighting 22 minutes before sunset'),
    ('candle_lighting_30', 'הדלקת נרות 30 דקות', 'Candle Lighting (30 min)', 'Hadlakas Neiros 30', 'sunset', 'sunset - 30min', false, 595, 'Candle lighting 30 minutes before sunset'),
    ('candle_lighting_40', 'הדלקת נרות 40 דקות', 'Candle Lighting (40 min)', 'Hadlakas Neiros 40', 'sunset', 'sunset - 40min', false, 596, 'Candle lighting 40 minutes before sunset (Jerusalem strict)'),
    ('sunset', 'שקיעה', 'Sunset', 'Shkiah', 'sunset', 'sunset', true, 600, 'Geometric/sea-level sunset'),
    ('visible_sunset', 'שקיעה נראית', 'Visible Sunset', 'Shkiah Nireis', 'sunset', 'visible_sunset', false, 601, 'Actual visible sunset'),
    ('shkia_amitis', 'שקיעה אמיתית', 'True Sunset', 'Shkia Amitis', 'sunset', 'sunset', false, 602, 'True sunset accounting for elevation'),
    ('bein_hashmashos_start', 'תחילת בין השמשות', 'Bein Hashmashos Start', 'Bein Hashmashos', 'sunset', 'sunset', false, 610, 'Start of twilight period'),

    -- ============================================
    -- NIGHTFALL (צאת הכוכבים) - Time Category: nightfall
    -- ============================================
    ('tzais', 'צאת הכוכבים', 'Nightfall (Tzais)', 'Tzais Hakochavim', 'nightfall', 'solar(8.5, after_sunset)', true, 700, 'Nightfall - when 3 medium stars are visible (8.5°)'),
    ('tzais_3_stars', 'צאת 3 כוכבים', 'Tzais 3 Stars', 'Tzais 3 Kochavim', 'nightfall', 'solar(8.5, after_sunset)', false, 701, 'Three stars visible - standard nightfall'),
    ('tzais_4_37', 'צאת 4.37°', 'Tzais (4.37°)', 'Tzais 4.37', 'nightfall', 'solar(4.37, after_sunset)', false, 702, 'Nightfall at 4.37° - lenient'),
    ('tzais_4_61', 'צאת 4.61°', 'Tzais (4.61°)', 'Tzais 4.61', 'nightfall', 'solar(4.61, after_sunset)', false, 703, 'Nightfall at 4.61°'),
    ('tzais_4_8', 'צאת 4.8°', 'Tzais (4.8°)', 'Tzais 4.8', 'nightfall', 'solar(4.8, after_sunset)', false, 704, 'Nightfall at 4.8°'),
    ('tzais_5_95', 'צאת 5.95°', 'Tzais (5.95°)', 'Tzais 5.95', 'nightfall', 'solar(5.95, after_sunset)', false, 705, 'Nightfall at 5.95°'),
    ('tzais_6', 'צאת 6°', 'Tzais (6°)', 'Tzais 6', 'nightfall', 'solar(6, after_sunset)', false, 706, 'Civil twilight end (6°)'),
    ('tzais_7_083', 'צאת 7.083°', 'Tzais (7.083°)', 'Tzais 7.083', 'nightfall', 'solar(7.083, after_sunset)', false, 707, 'Nightfall at 7.083° (Rabbeinu Tam geometric)'),
    ('tzais_7_67', 'צאת 7.67°', 'Tzais (7.67°)', 'Tzais 7.67', 'nightfall', 'solar(7.67, after_sunset)', false, 708, 'Nightfall at 7.67°'),
    ('tzais_8_5', 'צאת 8.5°', 'Tzais (8.5°)', 'Tzais 8.5', 'nightfall', 'solar(8.5, after_sunset)', false, 709, 'Standard nightfall at 8.5°'),
    ('tzais_9_3', 'צאת 9.3°', 'Tzais (9.3°)', 'Tzais 9.3', 'nightfall', 'solar(9.3, after_sunset)', false, 710, 'Nightfall at 9.3°'),
    ('tzais_9_75', 'צאת 9.75°', 'Tzais (9.75°)', 'Tzais 9.75', 'nightfall', 'solar(9.75, after_sunset)', false, 711, 'Nightfall at 9.75°'),
    ('tzais_13_5', 'צאת 13.5°', 'Tzais (13.5°)', 'Tzais 13.5', 'nightfall', 'solar(13.5, after_sunset)', false, 712, 'Stringent nightfall at 13.5°'),
    ('tzais_18', 'צאת 18°', 'Tzais (18°)', 'Tzais 18', 'nightfall', 'solar(18, after_sunset)', false, 713, 'Astronomical nightfall (18°)'),
    ('tzais_19_8', 'צאת 19.8°', 'Tzais (19.8°)', 'Tzais 19.8', 'nightfall', 'solar(19.8, after_sunset)', false, 714, 'Very stringent nightfall at 19.8°'),
    ('tzais_26', 'צאת 26°', 'Tzais (26°)', 'Tzais 26', 'nightfall', 'solar(26, after_sunset)', false, 715, 'Extremely stringent nightfall'),
    ('tzais_13_24', 'צאת 13.24°', 'Tzais (13.24 min)', 'Tzais 13.24', 'nightfall', 'sunset + 13min', false, 720, 'Fixed 13.24 minutes after sunset'),
    ('tzais_20', 'צאת 20 דקות', 'Tzais (20 min)', 'Tzais 20', 'nightfall', 'sunset + 20min', false, 721, 'Fixed 20 minutes after sunset'),
    ('tzais_42', 'צאת 42 דקות', 'Tzais (42 min)', 'Tzais 42', 'nightfall', 'sunset + 42min', false, 722, 'Fixed 42 minutes after sunset'),
    ('tzais_50', 'צאת 50 דקות', 'Tzais (50 min)', 'Tzais 50', 'nightfall', 'sunset + 50min', false, 723, 'Fixed 50 minutes after sunset'),
    ('tzais_60', 'צאת 60 דקות', 'Tzais (60 min)', 'Tzais 60', 'nightfall', 'sunset + 60min', false, 724, 'Fixed 60 minutes after sunset'),
    ('tzais_72', 'צאת ר"ת 72 דקות', 'Tzais Rabbeinu Tam (72 min)', 'Tzais RT 72', 'nightfall', 'sunset + 72min', false, 730, 'Rabbeinu Tam - 72 fixed minutes after sunset'),
    ('tzais_90', 'צאת 90 דקות', 'Tzais (90 min)', 'Tzais 90', 'nightfall', 'sunset + 90min', false, 731, 'Fixed 90 minutes after sunset'),
    ('tzais_96', 'צאת 96 דקות', 'Tzais (96 min)', 'Tzais 96', 'nightfall', 'sunset + 96min', false, 732, 'Fixed 96 minutes after sunset'),
    ('tzais_120', 'צאת 120 דקות', 'Tzais (120 min)', 'Tzais 120', 'nightfall', 'sunset + 120min', false, 733, 'Fixed 120 minutes after sunset'),
    ('shabbos_ends', 'מוצאי שבת', 'Shabbos Ends', 'Motzei Shabbos', 'nightfall', 'solar(8.5, after_sunset)', false, 750, 'End of Shabbos - standard tzais'),
    ('shabbos_ends_42', 'מוצאי שבת 42 דקות', 'Shabbos Ends (42 min)', 'Motzei Shabbos 42', 'nightfall', 'sunset + 42min', false, 751, 'End of Shabbos - 42 minutes'),
    ('shabbos_ends_50', 'מוצאי שבת 50 דקות', 'Shabbos Ends (50 min)', 'Motzei Shabbos 50', 'nightfall', 'sunset + 50min', false, 752, 'End of Shabbos - 50 minutes'),
    ('shabbos_ends_72', 'מוצאי שבת 72 דקות', 'Shabbos Ends (72 min)', 'Motzei Shabbos 72', 'nightfall', 'sunset + 72min', false, 753, 'End of Shabbos - Rabbeinu Tam'),
    ('fast_ends', 'סוף הצום', 'Fast Ends', 'Sof Hatzom', 'nightfall', 'solar(8.5, after_sunset)', false, 760, 'End of fast day'),
    ('fast_ends_20', 'סוף הצום 20 דקות', 'Fast Ends (20 min)', 'Sof Hatzom 20', 'nightfall', 'sunset + 20min', false, 761, 'Fast ends 20 minutes after sunset'),
    ('fast_ends_42', 'סוף הצום 42 דקות', 'Fast Ends (42 min)', 'Sof Hatzom 42', 'nightfall', 'sunset + 42min', false, 762, 'Fast ends 42 minutes after sunset'),
    ('fast_ends_50', 'סוף הצום 50 דקות', 'Fast Ends (50 min)', 'Sof Hatzom 50', 'nightfall', 'sunset + 50min', false, 763, 'Fast ends 50 minutes after sunset'),

    -- ============================================
    -- MIDNIGHT (חצות לילה) - Time Category: midnight
    -- ============================================
    ('chatzos_layla', 'חצות לילה', 'Midnight (Chatzos Layla)', 'Chatzos Layla', 'midnight', 'solar_noon + 12hr', false, 800, 'Halachic midnight - 12 hours after solar noon')
ON CONFLICT (zman_key) DO UPDATE SET
    canonical_hebrew_name = EXCLUDED.canonical_hebrew_name,
    canonical_english_name = EXCLUDED.canonical_english_name,
    transliteration = EXCLUDED.transliteration,
    time_category = EXCLUDED.time_category,
    default_formula_dsl = EXCLUDED.default_formula_dsl,
    is_core = EXCLUDED.is_core,
    sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description,
    updated_at = now();

-- ============================================
-- LINK TAGS TO MASTER REGISTRY
-- ============================================

-- Link GRA-based zmanim
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'gra'
AND mr.zman_key IN (
    'sof_zman_shma_gra', 'sof_zman_tfila_gra', 'mincha_ketana', 'plag_hamincha',
    'sof_zman_achilas_chametz_gra', 'sof_zman_biur_chametz_gra', 'samuch_lmincha_ketana'
)
ON CONFLICT DO NOTHING;

-- Link MGA-based zmanim
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'mga'
AND mr.zman_key IN (
    'sof_zman_shma_mga', 'sof_zman_shma_mga_90', 'sof_zman_shma_mga_120',
    'sof_zman_tfila_mga', 'sof_zman_tfila_mga_90', 'sof_zman_tfila_mga_120',
    'sof_zman_achilas_chametz_mga', 'sof_zman_biur_chametz_mga',
    'mincha_ketana_72', 'plag_hamincha_72'
)
ON CONFLICT DO NOTHING;

-- Link Rabbeinu Tam-based zmanim
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'rabbeinu_tam'
AND mr.zman_key IN (
    'tzais_72', 'tzais_7_083', 'shabbos_ends_72'
)
ON CONFLICT DO NOTHING;

-- Link solar angle calculations
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'solar_angle'
AND mr.zman_key LIKE 'alos_%' AND mr.default_formula_dsl LIKE 'solar(%'
ON CONFLICT DO NOTHING;

INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'solar_angle'
AND mr.zman_key LIKE 'tzais_%' AND mr.default_formula_dsl LIKE 'solar(%'
ON CONFLICT DO NOTHING;

-- Link fixed minutes calculations
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'fixed_minutes'
AND (mr.default_formula_dsl LIKE '%- %min' OR mr.default_formula_dsl LIKE '%+ %min')
ON CONFLICT DO NOTHING;

-- Link proportional hours calculations
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'proportional_hours'
AND mr.default_formula_dsl LIKE 'proportional_hours(%'
ON CONFLICT DO NOTHING;
