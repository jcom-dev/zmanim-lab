-- Migration: Seed zman_tags with event/timing/behavior tags
-- and auto-assign to existing master zmanim

-- ===========================================
-- Seed: Event Tags (which events a zman applies to)
-- ===========================================
INSERT INTO zman_tags (tag_key, name, display_name_hebrew, display_name_english, tag_type, description, sort_order) VALUES
    ('shabbos', 'shabbos', 'שבת', 'Shabbos', 'event', 'Applies to Shabbos', 10),
    ('yom_tov', 'yom_tov', 'יום טוב', 'Yom Tov', 'event', 'Applies to Yom Tov (major holidays)', 20),
    ('yom_kippur', 'yom_kippur', 'יום כיפור', 'Yom Kippur', 'event', 'Applies to Yom Kippur', 30),
    ('fast_day', 'fast_day', 'תענית', 'Fast Day', 'event', 'Applies to minor fast days', 40),
    ('tisha_bav', 'tisha_bav', 'תשעה באב', 'Tisha B''Av', 'event', 'Applies to Tisha B''Av', 50),
    ('pesach', 'pesach', 'ערב פסח', 'Erev Pesach', 'event', 'Applies to Erev Pesach (chametz times)', 60)
ON CONFLICT (name) DO UPDATE SET
    tag_key = EXCLUDED.tag_key,
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    tag_type = EXCLUDED.tag_type,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order;

-- ===========================================
-- Seed: Timing Tags (when to display relative to event)
-- ===========================================
INSERT INTO zman_tags (tag_key, name, display_name_hebrew, display_name_english, tag_type, description, sort_order) VALUES
    ('day_before', 'day_before', 'יום לפני', 'Day Before', 'timing', 'Display on the day before the event (e.g., candle lighting)', 100),
    ('day_of', 'day_of', 'יום של', 'Day Of', 'timing', 'Display on the day of the event', 110),
    ('night_after', 'night_after', 'לילה אחרי', 'Night After', 'timing', 'Display on the night after the event (e.g., havdalah)', 120)
ON CONFLICT (name) DO UPDATE SET
    tag_key = EXCLUDED.tag_key,
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    tag_type = EXCLUDED.tag_type,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order;

-- ===========================================
-- Seed: Behavior Tags (special handling)
-- ===========================================
INSERT INTO zman_tags (tag_key, name, display_name_hebrew, display_name_english, tag_type, description, sort_order) VALUES
    ('is_candle_lighting', 'is_candle_lighting', 'הדלקת נרות', 'Candle Lighting', 'behavior', 'This is a candle lighting time', 200),
    ('is_havdalah', 'is_havdalah', 'הבדלה', 'Havdalah', 'behavior', 'This is a havdalah/end of Shabbos time', 210),
    ('is_fast_start', 'is_fast_start', 'תחילת צום', 'Fast Begins', 'behavior', 'This marks when a fast begins', 220),
    ('is_fast_end', 'is_fast_end', 'סוף צום', 'Fast Ends', 'behavior', 'This marks when a fast ends', 230)
ON CONFLICT (name) DO UPDATE SET
    tag_key = EXCLUDED.tag_key,
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    tag_type = EXCLUDED.tag_type,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order;

-- ===========================================
-- Auto-assign tags to existing master zmanim
-- ===========================================

-- Candle lighting zmanim -> shabbos, yom_tov, day_before, is_candle_lighting
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mz.id, t.id
FROM master_zmanim_registry mz
CROSS JOIN zman_tags t
WHERE mz.zman_key LIKE 'candle_lighting%'
  AND t.tag_key IN ('shabbos', 'yom_tov', 'day_before', 'is_candle_lighting')
ON CONFLICT DO NOTHING;

-- Shabbos ends / havdalah zmanim -> shabbos, yom_tov, yom_kippur, night_after, is_havdalah
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mz.id, t.id
FROM master_zmanim_registry mz
CROSS JOIN zman_tags t
WHERE (mz.zman_key LIKE 'shabbos_ends%' OR mz.zman_key LIKE 'havdalah%')
  AND t.tag_key IN ('shabbos', 'yom_tov', 'yom_kippur', 'night_after', 'is_havdalah')
ON CONFLICT DO NOTHING;

-- Fast day zmanim -> fast_day, tisha_bav, day_of
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mz.id, t.id
FROM master_zmanim_registry mz
CROSS JOIN zman_tags t
WHERE mz.zman_key LIKE 'fast_%'
  AND t.tag_key IN ('fast_day', 'tisha_bav', 'day_of')
ON CONFLICT DO NOTHING;

-- Fast begins -> is_fast_start
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mz.id, t.id
FROM master_zmanim_registry mz
CROSS JOIN zman_tags t
WHERE mz.zman_key LIKE 'fast_begin%'
  AND t.tag_key = 'is_fast_start'
ON CONFLICT DO NOTHING;

-- Fast ends -> is_fast_end
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mz.id, t.id
FROM master_zmanim_registry mz
CROSS JOIN zman_tags t
WHERE mz.zman_key LIKE 'fast_end%'
  AND t.tag_key = 'is_fast_end'
ON CONFLICT DO NOTHING;

-- Pesach / chametz zmanim -> pesach, day_of
INSERT INTO master_zman_tags (master_zman_id, tag_id)
SELECT mz.id, t.id
FROM master_zmanim_registry mz
CROSS JOIN zman_tags t
WHERE mz.zman_key LIKE '%chametz%'
  AND t.tag_key IN ('pesach', 'day_of')
ON CONFLICT DO NOTHING;

-- ===========================================
-- Create view for zmanim with tags
-- ===========================================
CREATE OR REPLACE VIEW master_zmanim_with_tags AS
SELECT
    mz.*,
    COALESCE(
        (SELECT json_agg(json_build_object(
            'tag_key', t.tag_key,
            'display_name_hebrew', t.display_name_hebrew,
            'display_name_english', t.display_name_english,
            'tag_type', t.tag_type
        ) ORDER BY t.sort_order)
        FROM master_zman_tags mzt
        JOIN zman_tags t ON mzt.tag_id = t.id
        WHERE mzt.master_zman_id = mz.id),
        '[]'::json
    ) AS tags
FROM master_zmanim_registry mz;

COMMENT ON VIEW master_zmanim_with_tags IS 'Master zmanim registry with their associated tags';
