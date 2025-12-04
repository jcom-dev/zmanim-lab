-- Migration 8: Add jewish_day tag type and Jewish Day Tags with HebCal mappings
-- This migration adds 31 new tags for specific Jewish calendar days

-- ============================================================================
-- STEP 1: Update the tag_type constraint to include 'jewish_day'
-- ============================================================================

ALTER TABLE zman_tags DROP CONSTRAINT IF EXISTS zman_tags_tag_type_check;
ALTER TABLE zman_tags ADD CONSTRAINT zman_tags_tag_type_check
CHECK ((tag_type)::text = ANY (ARRAY['event'::text, 'timing'::text, 'behavior'::text, 'shita'::text, 'calculation'::text, 'category'::text, 'jewish_day'::text]));

-- ============================================================================
-- STEP 2: Insert Jewish Day Tags
-- ============================================================================

INSERT INTO zman_tags (tag_key, name, display_name_hebrew, display_name_english, tag_type, description, sort_order) VALUES
-- Omer Period (49 days from 2nd night Pesach to Shavuos)
('omer', 'omer', 'ספירת העומר', 'Sefirat HaOmer', 'jewish_day', 'During the Omer counting period (49 days)', 300),

-- Chanukah (8 days)
('chanukah', 'chanukah', 'חנוכה', 'Chanukah', 'jewish_day', 'Festival of Lights (8 days)', 310),

-- Purim
('purim', 'purim', 'פורים', 'Purim', 'jewish_day', 'Feast of Lots', 320),
('shushan_purim', 'shushan_purim', 'שושן פורים', 'Shushan Purim', 'jewish_day', 'Purim in walled cities', 321),
('taanis_esther', 'taanis_esther', 'תענית אסתר', 'Taanis Esther', 'jewish_day', 'Fast of Esther', 322),

-- Pesach (HebCal handles 7 vs 8 days for Israel/Diaspora)
-- Note: No "erev_pesach" tag - use day_before() DSL function for erev-specific times
('pesach', 'pesach', 'פסח', 'Pesach', 'jewish_day', 'Passover festival days', 331),
('chol_hamoed_pesach', 'chol_hamoed_pesach', 'חול המועד פסח', 'Chol HaMoed Pesach', 'jewish_day', 'Intermediate days of Pesach', 332),

-- Shavuos (HebCal handles 1 vs 2 days for Israel/Diaspora)
-- Note: No "erev" tags - use day_before() DSL function for erev-specific times
('shavuos', 'shavuos', 'שבועות', 'Shavuos', 'jewish_day', 'Feast of Weeks', 341),

-- Elul & High Holidays
('selichos', 'selichos', 'סליחות', 'Selichos', 'jewish_day', 'Penitential prayer period', 350),
('rosh_hashanah', 'rosh_hashanah', 'ראש השנה', 'Rosh Hashanah', 'jewish_day', 'Jewish New Year (2 days)', 352),
('tzom_gedaliah', 'tzom_gedaliah', 'צום גדליה', 'Tzom Gedaliah', 'jewish_day', 'Fast of Gedaliah', 353),
('aseres_yemei_teshuva', 'aseres_yemei_teshuva', 'עשרת ימי תשובה', 'Ten Days of Repentance', 'jewish_day', 'Period from RH to YK', 354),
('yom_kippur', 'yom_kippur', 'יום כיפור', 'Yom Kippur', 'jewish_day', 'Day of Atonement', 356),

-- Sukkos (HebCal handles Israel/Diaspora differences)
('sukkos', 'sukkos', 'סוכות', 'Sukkos', 'jewish_day', 'Feast of Tabernacles', 361),
('chol_hamoed_sukkos', 'chol_hamoed_sukkos', 'חול המועד סוכות', 'Chol HaMoed Sukkos', 'jewish_day', 'Intermediate days of Sukkos', 362),
('hoshanah_rabbah', 'hoshanah_rabbah', 'הושענא רבה', 'Hoshanah Rabbah', 'jewish_day', '7th day of Sukkos', 363),
('shemini_atzeres', 'shemini_atzeres', 'שמיני עצרת', 'Shemini Atzeres', 'jewish_day', '8th day of assembly', 364),
('simchas_torah', 'simchas_torah', 'שמחת תורה', 'Simchas Torah', 'jewish_day', 'Rejoicing of the Torah (Diaspora: day 2)', 365),

-- Minor Fasts
('asarah_bteves', 'asarah_bteves', 'עשרה בטבת', 'Asarah B''Teves', 'jewish_day', '10th of Teves fast', 370),
('shiva_asar_btamuz', 'shiva_asar_btamuz', 'שבעה עשר בתמוז', 'Shiva Asar B''Tamuz', 'jewish_day', '17th of Tamuz fast', 371),
('tisha_bav', 'tisha_bav', 'תשעה באב', 'Tisha B''Av', 'jewish_day', '9th of Av', 372),
-- Note: No "erev_tisha_bav" tag - use day_before() DSL function

-- Mourning Periods (for restrictions, not zmanim)
('three_weeks', 'three_weeks', 'בין המצרים', 'The Three Weeks', 'jewish_day', 'Period between 17 Tamuz and 9 Av', 380),
('nine_days', 'nine_days', 'תשעת הימים', 'The Nine Days', 'jewish_day', 'First 9 days of Av', 381),

-- Other
('rosh_chodesh', 'rosh_chodesh', 'ראש חודש', 'Rosh Chodesh', 'jewish_day', 'New Moon/Month', 390),
('tu_bshvat', 'tu_bshvat', 'ט"ו בשבט', 'Tu B''Shvat', 'jewish_day', 'New Year for Trees', 391),

-- Diaspora-specific
('yom_tov_sheni', 'yom_tov_sheni', 'יום טוב שני', 'Yom Tov Sheni', 'jewish_day', 'Second day of Yom Tov (Diaspora only)', 395)
ON CONFLICT (tag_key) DO NOTHING;

-- ============================================================================
-- STEP 3: Create HebCal Event Mapping Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS tag_event_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_id UUID NOT NULL REFERENCES zman_tags(id) ON DELETE CASCADE,

    -- HebCal integration (primary method)
    -- Pattern matching against HebCal event names
    -- HebCal automatically handles Israel/Diaspora when called with il=true/false
    hebcal_event_pattern VARCHAR(100),  -- e.g., "Chanukah", "Sukkot VII (Hoshana Raba)"

    -- Hebrew date matching (fallback/alternative)
    hebrew_month INTEGER,               -- 1-13 (13 for Adar II)
    hebrew_day_start INTEGER,           -- Start day
    hebrew_day_end INTEGER,             -- End day (for ranges)

    -- Priority for overlapping matches
    priority INTEGER DEFAULT 100,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Ensure either hebcal pattern or hebrew date is provided
    CONSTRAINT valid_mapping CHECK (
        hebcal_event_pattern IS NOT NULL OR
        (hebrew_month IS NOT NULL AND hebrew_day_start IS NOT NULL)
    )
);

COMMENT ON TABLE tag_event_mappings IS 'Maps zman_tags to HebCal events or Hebrew dates for calendar-based filtering';
COMMENT ON COLUMN tag_event_mappings.hebcal_event_pattern IS 'HebCal event pattern. Use % as wildcard. E.g., "Chanukah%" matches all Chanukah days.';
COMMENT ON COLUMN tag_event_mappings.hebrew_month IS 'Hebrew month number: 1=Nisan...12=Adar, 13=Adar II in leap year';
COMMENT ON COLUMN tag_event_mappings.priority IS 'Higher priority patterns are matched first for overlapping dates';

-- Indexes
CREATE INDEX idx_tag_event_mappings_tag ON tag_event_mappings(tag_id);
CREATE INDEX idx_tag_event_mappings_pattern ON tag_event_mappings(hebcal_event_pattern) WHERE hebcal_event_pattern IS NOT NULL;
CREATE INDEX idx_tag_event_mappings_hebrew_date ON tag_event_mappings(hebrew_month, hebrew_day_start) WHERE hebrew_month IS NOT NULL;

-- ============================================================================
-- STEP 4: Insert HebCal Event Mappings
-- ============================================================================

INSERT INTO tag_event_mappings (tag_id, hebcal_event_pattern)
SELECT id, pattern FROM (VALUES
    -- Sukkos cycle
    ('shemini_atzeres', 'Shmini Atzeret'),
    ('simchas_torah', 'Simchat Torah'),
    ('hoshanah_rabbah', 'Sukkot VII (Hoshana Raba)'),
    ('sukkos', 'Sukkot%'),
    ('chol_hamoed_sukkos', 'Sukkot % (CH''M)'),

    -- Pesach cycle
    ('pesach', 'Pesach%'),
    ('chol_hamoed_pesach', 'Pesach % (CH''M)'),

    -- Shavuos
    ('shavuos', 'Shavuot%'),

    -- High Holidays
    ('rosh_hashanah', 'Rosh Hashana%'),
    ('yom_kippur', 'Yom Kippur'),
    ('tzom_gedaliah', 'Tzom Gedaliah'),

    -- Other holidays
    ('chanukah', 'Chanukah%'),
    ('purim', 'Purim'),
    ('shushan_purim', 'Shushan Purim'),
    ('taanis_esther', 'Ta''anit Esther'),
    ('rosh_chodesh', 'Rosh Chodesh%'),
    ('tu_bshvat', 'Tu BiShvat'),

    -- Fasts
    ('asarah_bteves', 'Asara B''Tevet'),
    ('shiva_asar_btamuz', 'Shiva Asar B''Tamuz'),
    ('tisha_bav', 'Tish''a B''Av'),

    -- Omer (special pattern)
    ('omer', '%day of the Omer'),

    -- Yom Tov Sheni (second days in Diaspora - marked with "II" in HebCal)
    -- Note: This matches Pesach II, Sukkot II, Shavuot II, Rosh Hashana II
    ('yom_tov_sheni', '% II')
) AS mappings(tag_key, pattern)
JOIN zman_tags ON zman_tags.tag_key = mappings.tag_key
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 5: Add Hebrew date-based mappings for periods
-- ============================================================================

-- Selichos: Typically starts around 25 Elul (Ashkenazi) or 1 Elul (Sephardi)
-- We use the common Ashkenazi start of the Saturday night before Rosh Hashanah
INSERT INTO tag_event_mappings (tag_id, hebrew_month, hebrew_day_start, hebrew_day_end, priority)
SELECT id, 6, 25, 29, 50 FROM zman_tags WHERE tag_key = 'selichos'
ON CONFLICT DO NOTHING;

-- Aseres Yemei Teshuva: 1-10 Tishrei
INSERT INTO tag_event_mappings (tag_id, hebrew_month, hebrew_day_start, hebrew_day_end, priority)
SELECT id, 7, 1, 10, 50 FROM zman_tags WHERE tag_key = 'aseres_yemei_teshuva'
ON CONFLICT DO NOTHING;

-- Three Weeks: 17 Tamuz to 9 Av (across month boundary, handled by app logic)
-- We'll use HebCal pattern for the endpoints
INSERT INTO tag_event_mappings (tag_id, hebrew_month, hebrew_day_start, hebrew_day_end, priority)
SELECT id, 4, 17, 29, 40 FROM zman_tags WHERE tag_key = 'three_weeks'
ON CONFLICT DO NOTHING;

INSERT INTO tag_event_mappings (tag_id, hebrew_month, hebrew_day_start, hebrew_day_end, priority)
SELECT id, 5, 1, 9, 40 FROM zman_tags WHERE tag_key = 'three_weeks'
ON CONFLICT DO NOTHING;

-- Nine Days: 1-9 Av
INSERT INTO tag_event_mappings (tag_id, hebrew_month, hebrew_day_start, hebrew_day_end, priority)
SELECT id, 5, 1, 9, 50 FROM zman_tags WHERE tag_key = 'nine_days'
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 6: Update tag_types table (if exists) to include jewish_day
-- ============================================================================

INSERT INTO tag_types (key, display_name_hebrew, display_name_english, color, sort_order)
VALUES ('jewish_day', 'יום יהודי', 'Jewish Day', 'bg-violet-500/10 text-violet-700 border-violet-300 dark:bg-violet-500/20 dark:text-violet-300 dark:border-violet-700', 8)
ON CONFLICT (key) DO NOTHING;
