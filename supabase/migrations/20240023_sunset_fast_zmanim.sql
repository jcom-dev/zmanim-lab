-- Migration: Add Sunset-Based Fast Zmanim (Yom Kippur & Tisha B'Av)
-- These fasts start at sunset (not dawn like regular fasts)
-- Publishers need to configure when the fast begins and ends

-- ============================================
-- PART 1: ADD EREV TISHA B'AV DAY TYPE
-- ============================================

INSERT INTO day_types (name, display_name_hebrew, display_name_english, description, parent_type, sort_order) VALUES
    ('erev_tisha_bav', 'ערב תשעה באב', 'Erev Tisha B''Av', 'Evening before Tisha B''Av when the fast begins at sunset', 'taanis', 115)
ON CONFLICT (name) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    description = EXCLUDED.description,
    parent_type = EXCLUDED.parent_type,
    sort_order = EXCLUDED.sort_order;

-- ============================================
-- PART 2: ADD SUNSET-BASED FAST ZMANIM
-- ============================================

INSERT INTO master_zmanim_registry (zman_key, canonical_hebrew_name, canonical_english_name, transliteration, time_category, default_formula_dsl, is_fundamental, sort_order, description, halachic_notes) VALUES
    -- Yom Kippur Fast Start (at sunset or slightly before)
    ('yom_kippur_starts', 'כניסת יום כיפור', 'Yom Kippur Begins', 'Knisat Yom Kippur', 'sunset', 'sunset', false, 598, 'When Yom Kippur begins and the fast starts', 'The fast of Yom Kippur begins at sunset. Many have the custom to add time (tosefes Yom Kippur) before sunset.'),
    ('yom_kippur_starts_early', 'תוספת יום כיפור', 'Tosefes Yom Kippur', 'Tosefes Yom Kippur', 'sunset', 'sunset - 5min', false, 597, 'Adding to Yom Kippur - accepting the fast early', 'The mitzvah to add from the weekday onto Yom Kippur. Common custom is 5-10 minutes before sunset.'),

    -- Yom Kippur Ends
    ('yom_kippur_ends', 'צאת יום כיפור', 'Yom Kippur Ends', 'Tzeis Yom Kippur', 'nightfall', 'solar(8.5, after_sunset)', false, 754, 'End of Yom Kippur fast', 'Standard nightfall for ending Yom Kippur'),
    ('yom_kippur_ends_42', 'צאת יום כיפור 42 דקות', 'Yom Kippur Ends (42 min)', 'Tzeis Yom Kippur 42', 'nightfall', 'sunset + 42min', false, 755, 'End of Yom Kippur - 42 minutes after sunset', 'Common stringent opinion for ending Yom Kippur'),
    ('yom_kippur_ends_50', 'צאת יום כיפור 50 דקות', 'Yom Kippur Ends (50 min)', 'Tzeis Yom Kippur 50', 'nightfall', 'sunset + 50min', false, 756, 'End of Yom Kippur - 50 minutes after sunset', 'Stringent opinion for ending Yom Kippur'),
    ('yom_kippur_ends_72', 'צאת יום כיפור 72 דקות', 'Yom Kippur Ends (72 min)', 'Tzeis Yom Kippur 72', 'nightfall', 'sunset + 72min', false, 757, 'End of Yom Kippur - Rabbeinu Tam', 'Very stringent opinion following Rabbeinu Tam'),

    -- Tisha B'Av Fast Start (at sunset)
    ('tisha_bav_starts', 'תחילת צום תשעה באב', 'Tisha B''Av Fast Begins', 'Techilat Tzom Tisha B''Av', 'sunset', 'sunset', false, 599, 'When the Tisha B''Av fast begins at sunset', 'Unlike other fasts, Tisha B''Av begins at sunset the night before.'),

    -- Tisha B'Av Ends (specific times, may differ from regular fast ends)
    ('tisha_bav_ends', 'צאת תשעה באב', 'Tisha B''Av Ends', 'Tzeis Tisha B''Av', 'nightfall', 'solar(8.5, after_sunset)', false, 764, 'End of Tisha B''Av fast', 'Standard nightfall for ending Tisha B''Av'),
    ('tisha_bav_ends_42', 'צאת תשעה באב 42 דקות', 'Tisha B''Av Ends (42 min)', 'Tzeis Tisha B''Av 42', 'nightfall', 'sunset + 42min', false, 765, 'End of Tisha B''Av - 42 minutes', 'Common opinion for ending Tisha B''Av'),
    ('tisha_bav_ends_50', 'צאת תשעה באב 50 דקות', 'Tisha B''Av Ends (50 min)', 'Tzeis Tisha B''Av 50', 'nightfall', 'sunset + 50min', false, 766, 'End of Tisha B''Av - 50 minutes', 'Stringent opinion for ending Tisha B''Av')
ON CONFLICT (zman_key) DO UPDATE SET
    canonical_hebrew_name = EXCLUDED.canonical_hebrew_name,
    canonical_english_name = EXCLUDED.canonical_english_name,
    transliteration = EXCLUDED.transliteration,
    time_category = EXCLUDED.time_category,
    default_formula_dsl = EXCLUDED.default_formula_dsl,
    is_fundamental = EXCLUDED.is_fundamental,
    sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description,
    halachic_notes = EXCLUDED.halachic_notes,
    updated_at = now();

-- ============================================
-- PART 3: LINK ZMANIM TO DAY TYPES
-- ============================================

-- Yom Kippur start times - on Erev Yom Kippur
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key IN ('yom_kippur_starts', 'yom_kippur_starts_early')
AND dt.name = 'erev_yom_kippur'
ON CONFLICT DO NOTHING;

-- Yom Kippur end times - on Yom Kippur day
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'yom_kippur_ends%'
AND dt.name = 'yom_kippur'
ON CONFLICT DO NOTHING;

-- Tisha B'Av start - on Erev Tisha B'Av
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key = 'tisha_bav_starts'
AND dt.name = 'erev_tisha_bav'
ON CONFLICT DO NOTHING;

-- Tisha B'Av end times - on Tisha B'Av day
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'tisha_bav_ends%'
AND dt.name = 'tisha_bav'
ON CONFLICT DO NOTHING;

-- Also link candle lighting to Erev Yom Kippur specifically
-- (it's already linked to erev_yom_tov, but explicit is better)
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'candle_lighting%'
AND dt.name = 'erev_yom_kippur'
ON CONFLICT DO NOTHING;

-- ============================================
-- PART 4: ADD RABBEINU TAM TAG TO YOM KIPPUR 72
-- ============================================

INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mr.id, t.id
FROM master_zmanim_registry mr, zman_tags t
WHERE t.name = 'rabbeinu_tam'
AND mr.zman_key IN ('yom_kippur_ends_72')
ON CONFLICT DO NOTHING;

-- ============================================
-- PART 5: COMMENTS
-- ============================================

COMMENT ON COLUMN master_zmanim_registry.halachic_notes IS 'Halachic background and reasoning for this zman';
