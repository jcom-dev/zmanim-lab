-- Migration: Event Times Redesign
-- Redesigns the day_types model to properly handle Jewish events and display timing
--
-- KEY CONCEPTS:
-- 1. jewish_events - What event a zman is associated with (Shabbos, Yom Kippur, etc.)
-- 2. display_offset - When to display relative to event's Gregorian start (day_before, day_of)
-- 3. zman_display_contexts - Context-specific display names (same calculation, different labels)
--
-- RATIONALE:
-- Jewish days start at sunset, so "Erev Shabbos" in Jewish terms IS Shabbos.
-- But for display on a Gregorian calendar, we need to show times on the correct civil day.
-- Example: Candle lighting is associated with Shabbos but displays on Friday.

-- ============================================
-- PART 1: JEWISH EVENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS jewish_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name_hebrew TEXT NOT NULL,
    name_english TEXT NOT NULL,
    event_type VARCHAR(30) NOT NULL,  -- 'weekly', 'yom_tov', 'fast', 'informational'
    duration_days_israel INT DEFAULT 1,
    duration_days_diaspora INT DEFAULT 1,
    fast_start_type VARCHAR(20),  -- 'dawn' or 'sunset' for fasts
    parent_event_code VARCHAR(50),
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_event_type CHECK (event_type IN ('weekly', 'yom_tov', 'fast', 'informational')),
    CONSTRAINT chk_fast_start_type CHECK (fast_start_type IS NULL OR fast_start_type IN ('dawn', 'sunset'))
);

CREATE INDEX IF NOT EXISTS idx_jewish_events_code ON jewish_events(code);
CREATE INDEX IF NOT EXISTS idx_jewish_events_type ON jewish_events(event_type);
CREATE INDEX IF NOT EXISTS idx_jewish_events_parent ON jewish_events(parent_event_code);

-- ============================================
-- PART 2: SEED JEWISH EVENTS
-- ============================================

INSERT INTO jewish_events (code, name_hebrew, name_english, event_type, duration_days_israel, duration_days_diaspora, fast_start_type, parent_event_code, sort_order) VALUES
    -- Weekly
    ('shabbos', 'שבת', 'Shabbos', 'weekly', 1, 1, NULL, NULL, 10),

    -- Fasts (grouped by start type)
    ('yom_kippur', 'יום כיפור', 'Yom Kippur', 'fast', 1, 1, 'sunset', NULL, 20),
    ('tisha_bav', 'תשעה באב', 'Tisha B''Av', 'fast', 1, 1, 'sunset', NULL, 21),
    ('tzom_gedaliah', 'צום גדליה', 'Tzom Gedaliah', 'fast', 1, 1, 'dawn', NULL, 30),
    ('asarah_bteves', 'עשרה בטבת', 'Asarah B''Teves', 'fast', 1, 1, 'dawn', NULL, 31),
    ('shiva_asar_btamuz', 'שבעה עשר בתמוז', 'Shiva Asar B''Tamuz', 'fast', 1, 1, 'dawn', NULL, 32),
    ('taanis_esther', 'תענית אסתר', 'Taanis Esther', 'fast', 1, 1, 'dawn', NULL, 33),

    -- Yom Tov (with Israel/Diaspora duration differences)
    ('rosh_hashanah', 'ראש השנה', 'Rosh Hashanah', 'yom_tov', 2, 2, NULL, NULL, 40),  -- 2 days everywhere
    ('sukkos', 'סוכות', 'Sukkos', 'yom_tov', 1, 2, NULL, NULL, 50),  -- First day(s)
    ('shemini_atzeres', 'שמיני עצרת', 'Shemini Atzeres', 'yom_tov', 1, 2, NULL, NULL, 51),  -- Includes Simchas Torah in diaspora
    ('pesach_first', 'פסח (ראשון)', 'Pesach (First Days)', 'yom_tov', 1, 2, NULL, NULL, 60),
    ('pesach_last', 'פסח (אחרון)', 'Pesach (Last Days)', 'yom_tov', 1, 2, NULL, NULL, 61),
    ('shavuos', 'שבועות', 'Shavuos', 'yom_tov', 1, 2, NULL, NULL, 70),

    -- Informational (no linked zmanim, for display only)
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
-- PART 3: ADD DISPLAY_OFFSET TO MASTER REGISTRY
-- ============================================

-- Add display_offset column to master_zmanim_registry
-- 'day_before' = show on Gregorian day before event starts (e.g., candle lighting on Friday)
-- 'day_of' = show on Gregorian day of event (e.g., fast ends, Shabbos ends)
ALTER TABLE master_zmanim_registry
ADD COLUMN IF NOT EXISTS display_offset VARCHAR(20) DEFAULT 'day_of';

-- Add constraint for valid values
ALTER TABLE master_zmanim_registry
DROP CONSTRAINT IF EXISTS chk_display_offset;

ALTER TABLE master_zmanim_registry
ADD CONSTRAINT chk_display_offset CHECK (display_offset IN ('day_before', 'day_of', 'day_after'));

-- ============================================
-- PART 4: MASTER ZMAN EVENTS JUNCTION TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS master_zman_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    jewish_event_id UUID NOT NULL REFERENCES jewish_events(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT true,
    applies_to_day INT,  -- NULL = all days, 1 = day 1 only, 2 = day 2 only, etc.
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(master_zman_id, jewish_event_id, applies_to_day)
);

CREATE INDEX IF NOT EXISTS idx_master_zman_events_zman ON master_zman_events(master_zman_id);
CREATE INDEX IF NOT EXISTS idx_master_zman_events_event ON master_zman_events(jewish_event_id);

-- ============================================
-- PART 5: ZMAN DISPLAY CONTEXTS TABLE
-- ============================================

-- Context-specific display names for zmanim that have the same calculation
-- but different labels depending on the context (e.g., "Shabbos Ends" vs "Yom Tov Ends")
CREATE TABLE IF NOT EXISTS zman_display_contexts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    context_code VARCHAR(50) NOT NULL,  -- matches jewish_events.code or special values
    display_name_hebrew TEXT NOT NULL,
    display_name_english TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(master_zman_id, context_code)
);

CREATE INDEX IF NOT EXISTS idx_zman_display_contexts_zman ON zman_display_contexts(master_zman_id);
CREATE INDEX IF NOT EXISTS idx_zman_display_contexts_context ON zman_display_contexts(context_code);

-- ============================================
-- PART 6: PUBLISHER OVERRIDES FOR EVENTS
-- ============================================

-- Allow publishers to override event associations for their zmanim
CREATE TABLE IF NOT EXISTS publisher_zman_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    jewish_event_id UUID NOT NULL REFERENCES jewish_events(id) ON DELETE CASCADE,
    is_enabled BOOLEAN DEFAULT true,
    applies_to_day INT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(publisher_zman_id, jewish_event_id, applies_to_day)
);

CREATE INDEX IF NOT EXISTS idx_publisher_zman_events_zman ON publisher_zman_events(publisher_zman_id);
CREATE INDEX IF NOT EXISTS idx_publisher_zman_events_event ON publisher_zman_events(jewish_event_id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_publisher_zman_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS publisher_zman_events_updated_at ON publisher_zman_events;
CREATE TRIGGER publisher_zman_events_updated_at
    BEFORE UPDATE ON publisher_zman_events
    FOR EACH ROW
    EXECUTE FUNCTION update_publisher_zman_events_updated_at();

-- ============================================
-- PART 7: ADD NEW EVENT-BASED ZMANIM
-- ============================================

-- Insert new zmanim for Yom Tov Sheni candle lighting
INSERT INTO master_zmanim_registry (
    zman_key, canonical_hebrew_name, canonical_english_name, transliteration,
    description, halachic_notes, time_category, default_formula_dsl,
    display_offset, is_fundamental, sort_order
) VALUES
    ('candle_lighting_yomtov_sheni', 'הדלקת נרות יו״ט שני', 'Candle Lighting (Yom Tov Sheni)',
     'Hadlakas Neiros Yom Tov Sheni',
     'Candle lighting time for the second day of Yom Tov (Diaspora) or when transitioning from Shabbos/Yom Tov',
     'Must wait until after tzeis (nightfall) since one cannot light from an existing flame during Shabbos or Yom Tov itself. This applies to: Yom Tov Day 2 in Diaspora, Shabbos going into Yom Tov, and consecutive Yom Tov days.',
     'nightfall', 'tzeis', 'day_before', false, 5),

    ('fast_starts_dawn', 'תחילת הצום - עלות', 'Fast Begins (Dawn)',
     'Techilas HaTzom - Alos',
     'Start time for regular fast days that begin at dawn',
     'Applies to Tzom Gedaliah, Asarah B''Teves, Shiva Asar B''Tamuz, and Taanis Esther. The fast begins at alos hashachar (dawn).',
     'dawn', 'alos', 'day_of', false, 1),

    ('fast_starts_sunset', 'תחילת הצום - שקיעה', 'Fast Begins (Sunset)',
     'Techilas HaTzom - Shkiah',
     'Start time for fasts that begin at sunset (Yom Kippur, Tisha B''Av)',
     'Yom Kippur and Tisha B''Av begin at sunset the evening before, unlike regular fasts which begin at dawn.',
     'sunset', 'sunset', 'day_before', false, 1)
ON CONFLICT (zman_key) DO UPDATE SET
    canonical_hebrew_name = EXCLUDED.canonical_hebrew_name,
    canonical_english_name = EXCLUDED.canonical_english_name,
    transliteration = EXCLUDED.transliteration,
    description = EXCLUDED.description,
    halachic_notes = EXCLUDED.halachic_notes,
    time_category = EXCLUDED.time_category,
    default_formula_dsl = EXCLUDED.default_formula_dsl,
    display_offset = EXCLUDED.display_offset;

-- ============================================
-- PART 8: UPDATE EXISTING ZMANIM DISPLAY_OFFSET
-- ============================================

-- Candle lighting shows on day BEFORE the event (Friday for Shabbos, Erev YT for Yom Tov)
UPDATE master_zmanim_registry
SET display_offset = 'day_before'
WHERE zman_key LIKE 'candle_lighting%';

-- Fast starts (sunset-based) show on day BEFORE the fast day
UPDATE master_zmanim_registry
SET display_offset = 'day_before'
WHERE zman_key IN ('yom_kippur_starts', 'yom_kippur_starts_early', 'tisha_bav_starts', 'fast_starts_sunset');

-- Fast starts (dawn-based) show on day OF the fast
UPDATE master_zmanim_registry
SET display_offset = 'day_of'
WHERE zman_key = 'fast_starts_dawn';

-- Everything else (shabbos ends, fast ends, regular zmanim) shows on day OF
UPDATE master_zmanim_registry
SET display_offset = 'day_of'
WHERE display_offset IS NULL OR display_offset = '';

-- ============================================
-- PART 9: RENAME shabbos_ends TO shabbos_yomtov_ends
-- ============================================

-- Update existing zmanim to unified names (keep old keys for compatibility)
-- These have the same calculation but different display names based on context
UPDATE master_zmanim_registry
SET
    canonical_hebrew_name = 'צאת שבת/יו״ט',
    canonical_english_name = 'Shabbos/Yom Tov Ends',
    transliteration = 'Tzeis Shabbos/Yom Tov',
    description = 'End time for Shabbos or Yom Tov. The same calculation applies to both.',
    halachic_notes = COALESCE(halachic_notes, '') || E'\nThis time applies to both Shabbos and Yom Tov endings.'
WHERE zman_key = 'shabbos_ends';

UPDATE master_zmanim_registry
SET
    canonical_hebrew_name = 'צאת שבת/יו״ט (ר״ת)',
    canonical_english_name = 'Shabbos/Yom Tov Ends (R"T)',
    transliteration = 'Tzeis Shabbos/Yom Tov (Rabbeinu Tam)'
WHERE zman_key = 'shabbos_ends_rt' OR zman_key = 'shabbos_ends_72';

-- ============================================
-- PART 10: LINK ZMANIM TO EVENTS
-- ============================================

-- Helper: Get event ID by code
CREATE OR REPLACE FUNCTION get_event_id(p_code VARCHAR) RETURNS UUID AS $$
    SELECT id FROM jewish_events WHERE code = p_code;
$$ LANGUAGE sql STABLE;

-- Helper: Get zman ID by key
CREATE OR REPLACE FUNCTION get_zman_id(p_key VARCHAR) RETURNS UUID AS $$
    SELECT id FROM master_zmanim_registry WHERE zman_key = p_key;
$$ LANGUAGE sql STABLE;

-- Candle lighting (standard) - applies to Shabbos and all Yom Tovim (day 1 only in diaspora)
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default, applies_to_day)
SELECT get_zman_id('candle_lighting'), id, true, NULL
FROM jewish_events
WHERE code IN ('shabbos', 'rosh_hashanah', 'sukkos', 'shemini_atzeres', 'pesach_first', 'pesach_last', 'shavuos', 'yom_kippur')
ON CONFLICT DO NOTHING;

-- Candle lighting Yom Tov Sheni - applies to day 2 of 2-day Yom Tovim
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default, applies_to_day, notes)
SELECT get_zman_id('candle_lighting_yomtov_sheni'), id, true, 2, 'Day 2 in Diaspora - must light after tzeis'
FROM jewish_events
WHERE code IN ('rosh_hashanah', 'sukkos', 'shemini_atzeres', 'pesach_first', 'pesach_last', 'shavuos')
ON CONFLICT DO NOTHING;

-- Shabbos/Yom Tov ends - applies to Shabbos and all Yom Tovim (final day only)
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default, applies_to_day)
SELECT mr.id, je.id, true, NULL
FROM master_zmanim_registry mr, jewish_events je
WHERE mr.zman_key LIKE 'shabbos_ends%'
AND je.code IN ('shabbos', 'rosh_hashanah', 'sukkos', 'shemini_atzeres', 'pesach_first', 'pesach_last', 'shavuos', 'yom_kippur')
ON CONFLICT DO NOTHING;

-- Fast starts (sunset) - Yom Kippur and Tisha B'Av
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT mr.id, je.id, true
FROM master_zmanim_registry mr, jewish_events je
WHERE mr.zman_key IN ('yom_kippur_starts', 'yom_kippur_starts_early', 'fast_starts_sunset')
AND je.code = 'yom_kippur'
ON CONFLICT DO NOTHING;

INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT mr.id, je.id, true
FROM master_zmanim_registry mr, jewish_events je
WHERE mr.zman_key IN ('tisha_bav_starts', 'fast_starts_sunset')
AND je.code = 'tisha_bav'
ON CONFLICT DO NOTHING;

-- Fast starts (dawn) - minor fasts
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT get_zman_id('fast_starts_dawn'), id, true
FROM jewish_events
WHERE code IN ('tzom_gedaliah', 'asarah_bteves', 'shiva_asar_btamuz', 'taanis_esther')
ON CONFLICT DO NOTHING;

-- Fast ends - all fasts
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT mr.id, je.id, true
FROM master_zmanim_registry mr, jewish_events je
WHERE mr.zman_key LIKE 'fast_ends%'
AND je.event_type = 'fast'
ON CONFLICT DO NOTHING;

-- Yom Kippur specific ends
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT mr.id, je.id, true
FROM master_zmanim_registry mr, jewish_events je
WHERE mr.zman_key LIKE 'yom_kippur_ends%'
AND je.code = 'yom_kippur'
ON CONFLICT DO NOTHING;

-- Tisha B'Av specific ends
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT mr.id, je.id, true
FROM master_zmanim_registry mr, jewish_events je
WHERE mr.zman_key LIKE 'tisha_bav_ends%'
AND je.code = 'tisha_bav'
ON CONFLICT DO NOTHING;

-- Chametz times - Pesach
INSERT INTO master_zman_events (master_zman_id, jewish_event_id, is_default)
SELECT mr.id, je.id, true
FROM master_zmanim_registry mr, jewish_events je
WHERE (mr.zman_key LIKE 'sof_zman_achilas_chametz%' OR mr.zman_key LIKE 'sof_zman_biur_chametz%')
AND je.code = 'pesach_first'
ON CONFLICT DO NOTHING;

-- ============================================
-- PART 11: POPULATE DISPLAY CONTEXTS
-- ============================================

-- Shabbos/Yom Tov ends - different display names for different contexts
INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'shabbos', 'מוצאי שבת', 'Shabbos Ends', 1
FROM master_zmanim_registry WHERE zman_key = 'shabbos_ends'
ON CONFLICT DO NOTHING;

INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'yom_tov', 'מוצאי יום טוב', 'Yom Tov Ends', 2
FROM master_zmanim_registry WHERE zman_key = 'shabbos_ends'
ON CONFLICT DO NOTHING;

INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'yom_kippur', 'צאת יום כיפור', 'Yom Kippur Ends', 3
FROM master_zmanim_registry WHERE zman_key = 'shabbos_ends'
ON CONFLICT DO NOTHING;

INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'tisha_bav', 'צאת תשעה באב', 'Tisha B''Av Ends', 4
FROM master_zmanim_registry WHERE zman_key = 'shabbos_ends'
ON CONFLICT DO NOTHING;

-- R"T versions
INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'shabbos', 'מוצאי שבת (ר״ת)', 'Shabbos Ends (R"T)', 1
FROM master_zmanim_registry WHERE zman_key IN ('shabbos_ends_rt', 'shabbos_ends_72')
ON CONFLICT DO NOTHING;

INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'yom_tov', 'מוצאי יום טוב (ר״ת)', 'Yom Tov Ends (R"T)', 2
FROM master_zmanim_registry WHERE zman_key IN ('shabbos_ends_rt', 'shabbos_ends_72')
ON CONFLICT DO NOTHING;

INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'yom_kippur', 'צאת יום כיפור (ר״ת)', 'Yom Kippur Ends (R"T)', 3
FROM master_zmanim_registry WHERE zman_key IN ('shabbos_ends_rt', 'shabbos_ends_72')
ON CONFLICT DO NOTHING;

-- Fast ends - context-specific names
INSERT INTO zman_display_contexts (master_zman_id, context_code, display_name_hebrew, display_name_english, sort_order)
SELECT id, 'fast', 'צאת הצום', 'Fast Ends', 1
FROM master_zmanim_registry WHERE zman_key = 'fast_ends'
ON CONFLICT DO NOTHING;

-- ============================================
-- PART 12: DROP HELPER FUNCTIONS
-- ============================================

DROP FUNCTION IF EXISTS get_event_id(VARCHAR);
DROP FUNCTION IF EXISTS get_zman_id(VARCHAR);

-- ============================================
-- PART 13: ADD COMMENTS
-- ============================================

COMMENT ON TABLE jewish_events IS 'Canonical list of Jewish events (Shabbos, Yom Tov, fasts, etc.) with Israel/Diaspora duration differences';
COMMENT ON COLUMN jewish_events.event_type IS 'Type of event: weekly (Shabbos), yom_tov, fast, or informational (no linked zmanim)';
COMMENT ON COLUMN jewish_events.duration_days_israel IS 'Number of days this event lasts in Israel';
COMMENT ON COLUMN jewish_events.duration_days_diaspora IS 'Number of days this event lasts in the Diaspora';
COMMENT ON COLUMN jewish_events.fast_start_type IS 'For fasts: dawn (regular fasts) or sunset (Yom Kippur, Tisha B''Av)';

COMMENT ON COLUMN master_zmanim_registry.display_offset IS 'When to display this zman relative to the event: day_before (candle lighting), day_of (most zmanim), day_after (rare)';

COMMENT ON TABLE master_zman_events IS 'Links zmanim to the Jewish events they apply to';
COMMENT ON COLUMN master_zman_events.applies_to_day IS 'NULL = all days of event, 1 = day 1 only, 2 = day 2 only (for 2-day Yom Tov in Diaspora)';

COMMENT ON TABLE zman_display_contexts IS 'Context-specific display names for zmanim with the same calculation but different labels';
COMMENT ON COLUMN zman_display_contexts.context_code IS 'Context identifier - matches jewish_events.code or special values';

COMMENT ON TABLE publisher_zman_events IS 'Publisher overrides for which events their zmanim apply to';

-- ============================================
-- PART 14: DEPRECATION NOTICE FOR OLD TABLES
-- ============================================

COMMENT ON TABLE day_types IS 'DEPRECATED: Use jewish_events instead. This table will be removed in a future migration.';
COMMENT ON TABLE master_zman_day_types IS 'DEPRECATED: Use master_zman_events instead. This table will be removed in a future migration.';
COMMENT ON TABLE publisher_zman_day_types IS 'DEPRECATED: Use publisher_zman_events instead. This table will be removed in a future migration.';
