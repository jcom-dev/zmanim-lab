-- Migration 5: Add havdalah entry to master_zmanim_registry
-- The zmanim.go handler looks up 'havdalah' for Hebrew name but it didn't exist

-- Add havdalah as a distinct zman entry
INSERT INTO master_zmanim_registry (zman_key, canonical_hebrew_name, canonical_english_name, transliteration, description, time_category, default_formula_dsl, is_core, is_hidden)
VALUES
    ('havdalah', 'הבדלה', 'Havdalah', 'Havdalah', 'End of Shabbos/Yom Tov - default 42 minutes after sunset', 'nightfall', 'sunset + 42min', false, false)
ON CONFLICT (zman_key) DO UPDATE SET
    canonical_hebrew_name = EXCLUDED.canonical_hebrew_name,
    canonical_english_name = EXCLUDED.canonical_english_name,
    transliteration = EXCLUDED.transliteration,
    description = EXCLUDED.description,
    time_category = EXCLUDED.time_category,
    default_formula_dsl = EXCLUDED.default_formula_dsl;
