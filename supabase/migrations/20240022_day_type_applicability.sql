-- Migration: Day Type Applicability for Zmanim
-- Links zmanim to specific day types (Shabbos, Yom Tov, Taanis, etc.)
-- This allows publishers to configure which zmanim appear on which days

-- ============================================
-- PART 1: DAY TYPES TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS day_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name_hebrew TEXT NOT NULL,
    display_name_english TEXT NOT NULL,
    description TEXT,
    parent_type VARCHAR(100),  -- for hierarchical types (e.g., erev_yom_tov -> yom_tov)
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_day_types_name ON day_types(name);
CREATE INDEX IF NOT EXISTS idx_day_types_parent ON day_types(parent_type);

-- ============================================
-- PART 2: JUNCTION TABLE FOR MASTER REGISTRY
-- ============================================

-- Link master zmanim to applicable day types
CREATE TABLE IF NOT EXISTS master_zman_day_types (
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    day_type_id UUID NOT NULL REFERENCES day_types(id) ON DELETE CASCADE,
    is_default BOOLEAN DEFAULT true,  -- whether this is shown by default on this day type
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (master_zman_id, day_type_id)
);

CREATE INDEX IF NOT EXISTS idx_master_zman_day_types_zman ON master_zman_day_types(master_zman_id);
CREATE INDEX IF NOT EXISTS idx_master_zman_day_types_day ON master_zman_day_types(day_type_id);

-- ============================================
-- PART 3: PUBLISHER OVERRIDES
-- ============================================

-- Allow publishers to override day type visibility for their zmanim
CREATE TABLE IF NOT EXISTS publisher_zman_day_types (
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    day_type_id UUID NOT NULL REFERENCES day_types(id) ON DELETE CASCADE,
    is_visible BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (publisher_zman_id, day_type_id)
);

CREATE INDEX IF NOT EXISTS idx_pub_zman_day_types_zman ON publisher_zman_day_types(publisher_zman_id);
CREATE INDEX IF NOT EXISTS idx_pub_zman_day_types_day ON publisher_zman_day_types(day_type_id);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_publisher_zman_day_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS publisher_zman_day_types_updated_at ON publisher_zman_day_types;
CREATE TRIGGER publisher_zman_day_types_updated_at
    BEFORE UPDATE ON publisher_zman_day_types
    FOR EACH ROW
    EXECUTE FUNCTION update_publisher_zman_day_types_updated_at();

-- ============================================
-- PART 4: SEED DAY TYPES
-- ============================================

INSERT INTO day_types (name, display_name_hebrew, display_name_english, description, parent_type, sort_order) VALUES
    -- Regular days
    ('weekday', 'יום חול', 'Weekday', 'Regular weekday (Sunday-Thursday)', NULL, 10),
    ('friday', 'יום שישי', 'Friday', 'Friday (Erev Shabbos)', 'weekday', 15),

    -- Shabbos
    ('erev_shabbos', 'ערב שבת', 'Erev Shabbos', 'Friday afternoon before Shabbos', NULL, 20),
    ('shabbos', 'שבת', 'Shabbos', 'Shabbat day', NULL, 25),
    ('motzei_shabbos', 'מוצאי שבת', 'Motzei Shabbos', 'Saturday night after Shabbos', NULL, 30),

    -- Yom Tov
    ('erev_yom_tov', 'ערב יום טוב', 'Erev Yom Tov', 'Day before Yom Tov', NULL, 40),
    ('yom_tov', 'יום טוב', 'Yom Tov', 'Festival day (Pesach, Shavuos, Sukkos, etc.)', NULL, 45),
    ('motzei_yom_tov', 'מוצאי יום טוב', 'Motzei Yom Tov', 'Night after Yom Tov', NULL, 50),
    ('chol_hamoed', 'חול המועד', 'Chol HaMoed', 'Intermediate festival days', NULL, 55),

    -- Specific holidays
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

    -- Fast days
    ('taanis', 'תענית', 'Fast Day', 'General fast day', NULL, 100),
    ('taanis_start', 'תחילת תענית', 'Beginning of Fast', 'Start of a fast day', 'taanis', 101),
    ('taanis_end', 'סוף תענית', 'End of Fast', 'End of a fast day', 'taanis', 102),
    ('tzom_gedaliah', 'צום גדליה', 'Tzom Gedaliah', 'Fast of Gedaliah', 'taanis', 110),
    ('asarah_bteves', 'עשרה בטבת', 'Asarah B''Teves', '10th of Teves', 'taanis', 111),
    ('taanis_esther', 'תענית אסתר', 'Taanis Esther', 'Fast of Esther', 'taanis', 112),
    ('shiva_asar_btamuz', 'שבעה עשר בתמוז', 'Shiva Asar B''Tamuz', '17th of Tamuz', 'taanis', 113),
    ('tisha_bav', 'תשעה באב', 'Tisha B''Av', '9th of Av', 'taanis', 114),

    -- Other special days
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
-- PART 5: LINK DEFAULT DAY TYPES TO ZMANIM
-- ============================================

-- Candle lighting - only on Erev Shabbos and Erev Yom Tov
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'candle_lighting%'
AND dt.name IN ('erev_shabbos', 'erev_yom_tov')
ON CONFLICT DO NOTHING;

-- Shabbos/Yom Tov ends - only on Motzei Shabbos/Yom Tov
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'shabbos_ends%'
AND dt.name = 'motzei_shabbos'
ON CONFLICT DO NOTHING;

INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'shabbos_ends%'
AND dt.name = 'motzei_yom_tov'
ON CONFLICT DO NOTHING;

-- Fast ends - only on fast days
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key LIKE 'fast_ends%'
AND dt.name IN ('taanis', 'taanis_end')
ON CONFLICT DO NOTHING;

-- Chametz times - only on Erev Pesach
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE (mr.zman_key LIKE 'sof_zman_achilas_chametz%' OR mr.zman_key LIKE 'sof_zman_biur_chametz%')
AND dt.name = 'erev_pesach'
ON CONFLICT DO NOTHING;

-- Standard zmanim (sunrise, sunset, shema, tefilla, etc.) - weekday + shabbos + yom tov
INSERT INTO master_zman_day_types (master_zman_id, day_type_id, is_default)
SELECT mr.id, dt.id, true
FROM master_zmanim_registry mr, day_types dt
WHERE mr.zman_key IN (
    'sunrise', 'visible_sunrise', 'sunset', 'visible_sunset',
    'sof_zman_shma_gra', 'sof_zman_shma_mga',
    'sof_zman_tfila_gra', 'sof_zman_tfila_mga',
    'chatzos', 'mincha_gedola', 'mincha_ketana', 'plag_hamincha',
    'tzais', 'tzais_3_stars', 'chatzos_layla',
    'alos_hashachar', 'misheyakir'
)
AND dt.name IN ('weekday', 'shabbos', 'yom_tov', 'chol_hamoed')
ON CONFLICT DO NOTHING;

-- ============================================
-- PART 6: COMMENTS
-- ============================================

COMMENT ON TABLE day_types IS 'Types of days for which zmanim can be configured (Shabbos, Yom Tov, Taanis, etc.)';
COMMENT ON COLUMN day_types.parent_type IS 'Parent type name for hierarchical day types';
COMMENT ON TABLE master_zman_day_types IS 'Default day type applicability for master registry zmanim';
COMMENT ON COLUMN master_zman_day_types.is_default IS 'If true, this zman is shown by default on this day type';
COMMENT ON TABLE publisher_zman_day_types IS 'Publisher overrides for day type visibility';
