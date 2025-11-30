-- Migration: Master Zmanim Registry and Per-Zman Version History
-- Redesigns zmanim management with:
-- 1. Master registry of all canonical zmanim (no custom zmanim allowed)
-- 2. Per-zman version history (max 7 versions, formula changes only)
-- 3. Soft delete with restore capability
-- 4. Tagging system for shitos and grouping

-- ============================================
-- PART 1: MASTER ZMANIM REGISTRY
-- ============================================

-- Create master_zmanim_registry table - canonical list of ALL zmanim
CREATE TABLE IF NOT EXISTS master_zmanim_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zman_key VARCHAR(100) UNIQUE NOT NULL,
    canonical_hebrew_name TEXT NOT NULL,
    canonical_english_name TEXT NOT NULL,
    transliteration TEXT,
    description TEXT,
    halachic_notes TEXT,
    halachic_source VARCHAR(500),
    time_category VARCHAR(50) NOT NULL,  -- dawn, sunrise, morning, midday, afternoon, sunset, nightfall, midnight
    default_formula_dsl TEXT NOT NULL,
    is_fundamental BOOLEAN DEFAULT false,  -- sunrise, sunset, etc. - cannot be removed from registry
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_time_category CHECK (time_category IN ('dawn', 'sunrise', 'morning', 'midday', 'afternoon', 'sunset', 'nightfall', 'midnight'))
);

CREATE INDEX IF NOT EXISTS idx_master_registry_key ON master_zmanim_registry(zman_key);
CREATE INDEX IF NOT EXISTS idx_master_registry_category ON master_zmanim_registry(time_category);
CREATE INDEX IF NOT EXISTS idx_master_registry_sort ON master_zmanim_registry(time_category, sort_order);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_master_registry_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS master_registry_updated_at ON master_zmanim_registry;
CREATE TRIGGER master_registry_updated_at
    BEFORE UPDATE ON master_zmanim_registry
    FOR EACH ROW
    EXECUTE FUNCTION update_master_registry_updated_at();

-- ============================================
-- PART 2: TAGGING SYSTEM
-- ============================================

-- Create zman_tags table for shitos and other classifications
CREATE TABLE IF NOT EXISTS zman_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    display_name_hebrew TEXT NOT NULL,
    display_name_english TEXT NOT NULL,
    tag_type VARCHAR(50) NOT NULL,  -- 'shita', 'calculation_method'
    description TEXT,
    color VARCHAR(7),  -- Hex color for UI display
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_zman_tags_type ON zman_tags(tag_type);

-- Create master_zman_tags join table
CREATE TABLE IF NOT EXISTS master_zman_tags (
    master_zman_id UUID NOT NULL REFERENCES master_zmanim_registry(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES zman_tags(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (master_zman_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_master_zman_tags_zman ON master_zman_tags(master_zman_id);
CREATE INDEX IF NOT EXISTS idx_master_zman_tags_tag ON master_zman_tags(tag_id);

-- ============================================
-- PART 3: PER-ZMAN VERSION HISTORY
-- ============================================

-- Create publisher_zman_versions table (max 7 versions, formula only)
CREATE TABLE IF NOT EXISTS publisher_zman_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_zman_id UUID NOT NULL REFERENCES publisher_zmanim(id) ON DELETE CASCADE,
    version_number INT NOT NULL,
    formula_dsl TEXT NOT NULL,
    created_by VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    UNIQUE(publisher_zman_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_zman_versions_lookup ON publisher_zman_versions(publisher_zman_id, version_number DESC);

-- Function to get next version number for a publisher_zman
CREATE OR REPLACE FUNCTION get_next_zman_version(p_publisher_zman_id UUID)
RETURNS INT AS $$
DECLARE
    max_version INT;
BEGIN
    SELECT COALESCE(MAX(version_number), 0) INTO max_version
    FROM publisher_zman_versions
    WHERE publisher_zman_id = p_publisher_zman_id;

    RETURN max_version + 1;
END;
$$ LANGUAGE plpgsql;

-- Function to prune old versions (keep only 7)
CREATE OR REPLACE FUNCTION prune_zman_versions()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM publisher_zman_versions
    WHERE publisher_zman_id = NEW.publisher_zman_id
    AND id NOT IN (
        SELECT id
        FROM publisher_zman_versions
        WHERE publisher_zman_id = NEW.publisher_zman_id
        ORDER BY version_number DESC
        LIMIT 7
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prune_versions_trigger ON publisher_zman_versions;
CREATE TRIGGER prune_versions_trigger
    AFTER INSERT ON publisher_zman_versions
    FOR EACH ROW
    EXECUTE FUNCTION prune_zman_versions();

-- ============================================
-- PART 4: MODIFY PUBLISHER_ZMANIM TABLE
-- ============================================

-- Add master_zman_id column (will be NOT NULL after migration)
ALTER TABLE publisher_zmanim
ADD COLUMN IF NOT EXISTS master_zman_id UUID REFERENCES master_zmanim_registry(id);

-- Add current_version tracking
ALTER TABLE publisher_zmanim
ADD COLUMN IF NOT EXISTS current_version INT DEFAULT 1;

-- Add soft delete columns
ALTER TABLE publisher_zmanim
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE publisher_zmanim
ADD COLUMN IF NOT EXISTS deleted_by VARCHAR(255);

-- Create indexes for soft delete queries
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_active ON publisher_zmanim(publisher_id)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_deleted ON publisher_zmanim(publisher_id, deleted_at)
    WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_publisher_zmanim_master ON publisher_zmanim(master_zman_id);

-- ============================================
-- PART 5: ZMAN REQUEST TABLE (for edge cases)
-- ============================================

CREATE TABLE IF NOT EXISTS zman_registry_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    requested_key VARCHAR(100) NOT NULL,
    requested_hebrew_name TEXT NOT NULL,
    requested_english_name TEXT NOT NULL,
    requested_formula_dsl TEXT,
    time_category VARCHAR(50) NOT NULL,
    justification TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL,  -- pending, approved, rejected
    reviewed_by VARCHAR(255),
    reviewed_at TIMESTAMPTZ,
    reviewer_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    CONSTRAINT chk_request_status CHECK (status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_zman_requests_publisher ON zman_registry_requests(publisher_id);
CREATE INDEX IF NOT EXISTS idx_zman_requests_status ON zman_registry_requests(status);

-- ============================================
-- PART 6: SEED TAGS
-- ============================================

INSERT INTO zman_tags (name, display_name_hebrew, display_name_english, tag_type, color, sort_order) VALUES
    -- Shita tags
    ('gra', 'גר"א', 'GRA (Vilna Gaon)', 'shita', '#3B82F6', 1),
    ('mga', 'מג"א', 'MGA (Magen Avraham)', 'shita', '#8B5CF6', 2),
    ('rabbeinu_tam', 'ר"ת', 'Rabbeinu Tam', 'shita', '#F59E0B', 3),
    ('baal_hatanya', 'בעל התניא', 'Baal HaTanya', 'shita', '#10B981', 4),

    -- Calculation method tags
    ('fixed_minutes', 'דקות קבועות', 'Fixed Minutes', 'calculation_method', '#6366F1', 10),
    ('solar_angle', 'זווית שמש', 'Solar Angle', 'calculation_method', '#EC4899', 11),
    ('proportional_hours', 'שעות זמניות', 'Proportional Hours', 'calculation_method', '#14B8A6', 12)
ON CONFLICT (name) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    tag_type = EXCLUDED.tag_type,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order;

-- ============================================
-- PART 7: SEED COMPREHENSIVE MASTER REGISTRY
-- ============================================

INSERT INTO master_zmanim_registry (zman_key, canonical_hebrew_name, canonical_english_name, transliteration, time_category, default_formula_dsl, is_fundamental, sort_order, description) VALUES
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
    ('sof_zman_shma_gra', 'סוף זמן ק"ש גר"א', 'Latest Shema (GRA)', 'Sof Zman Shma GRA', 'morning', 'shaos(3, gra)', true, 300, 'Latest time for Shema - 3 proportional hours (GRA)'),
    ('sof_zman_shma_mga', 'סוף זמן ק"ש מג"א', 'Latest Shema (MGA)', 'Sof Zman Shma MGA', 'morning', 'shaos(3, mga)', false, 301, 'Latest time for Shema - 3 proportional hours (MGA from 72min dawn)'),
    ('sof_zman_shma_mga_90', 'סוף זמן ק"ש מג"א 90', 'Latest Shema (MGA 90)', 'Sof Zman Shma MGA 90', 'morning', 'shaos(3, mga_90)', false, 302, 'Latest time for Shema (MGA from 90min dawn)'),
    ('sof_zman_shma_mga_120', 'סוף זמן ק"ש מג"א 120', 'Latest Shema (MGA 120)', 'Sof Zman Shma MGA 120', 'morning', 'shaos(3, mga_120)', false, 303, 'Latest time for Shema (MGA from 120min dawn)'),
    ('sof_zman_shma_16_1', 'סוף זמן ק"ש 16.1°', 'Latest Shema (16.1°)', 'Sof Zman Shma 16.1', 'morning', 'shaos(3, alos_16_1)', false, 304, 'Latest Shema based on 16.1° alos'),
    ('sof_zman_tfila_gra', 'סוף זמן תפילה גר"א', 'Latest Shacharit (GRA)', 'Sof Zman Tefilla GRA', 'morning', 'shaos(4, gra)', true, 310, 'Latest time for Shacharit - 4 proportional hours (GRA)'),
    ('sof_zman_tfila_mga', 'סוף זמן תפילה מג"א', 'Latest Shacharit (MGA)', 'Sof Zman Tefilla MGA', 'morning', 'shaos(4, mga)', false, 311, 'Latest time for Shacharit - 4 proportional hours (MGA)'),
    ('sof_zman_tfila_mga_90', 'סוף זמן תפילה מג"א 90', 'Latest Shacharit (MGA 90)', 'Sof Zman Tefilla MGA 90', 'morning', 'shaos(4, mga_90)', false, 312, 'Latest Shacharit (MGA from 90min dawn)'),
    ('sof_zman_tfila_mga_120', 'סוף זמן תפילה מג"א 120', 'Latest Shacharit (MGA 120)', 'Sof Zman Tefilla MGA 120', 'morning', 'shaos(4, mga_120)', false, 313, 'Latest Shacharit (MGA from 120min dawn)'),
    ('sof_zman_achilas_chametz_gra', 'סוף זמן אכילת חמץ גר"א', 'Latest Eating Chametz (GRA)', 'Sof Achilat Chametz GRA', 'morning', 'shaos(4, gra)', false, 320, 'Latest time to eat chametz on Erev Pesach (GRA)'),
    ('sof_zman_achilas_chametz_mga', 'סוף זמן אכילת חמץ מג"א', 'Latest Eating Chametz (MGA)', 'Sof Achilat Chametz MGA', 'morning', 'shaos(4, mga)', false, 321, 'Latest time to eat chametz on Erev Pesach (MGA)'),
    ('sof_zman_biur_chametz_gra', 'סוף זמן ביעור חמץ גר"א', 'Latest Burning Chametz (GRA)', 'Sof Biur Chametz GRA', 'morning', 'shaos(5, gra)', false, 322, 'Latest time to burn chametz on Erev Pesach (GRA)'),
    ('sof_zman_biur_chametz_mga', 'סוף זמן ביעור חמץ מג"א', 'Latest Burning Chametz (MGA)', 'Sof Biur Chametz MGA', 'morning', 'shaos(5, mga)', false, 323, 'Latest time to burn chametz on Erev Pesach (MGA)'),

    -- ============================================
    -- MIDDAY (חצות) - Time Category: midday
    -- ============================================
    ('chatzos', 'חצות היום', 'Midday (Chatzos)', 'Chatzos', 'midday', 'solar_noon', true, 400, 'Solar noon - midpoint between sunrise and sunset'),
    ('mincha_gedola', 'מנחה גדולה', 'Earliest Mincha', 'Mincha Gedola', 'midday', 'solar_noon + 30min', true, 410, 'Earliest time for Mincha - 30 minutes after chatzos'),
    ('mincha_gedola_16_1', 'מנחה גדולה 16.1°', 'Earliest Mincha (16.1°)', 'Mincha Gedola 16.1', 'midday', 'shaos(6.5, alos_16_1)', false, 411, 'Earliest Mincha based on 16.1° calculation'),
    ('mincha_gedola_30', 'מנחה גדולה 30 דקות', 'Earliest Mincha (30 min)', 'Mincha Gedola 30', 'midday', 'solar_noon + 30min', false, 412, 'Earliest Mincha - exactly 30 minutes after chatzos'),

    -- ============================================
    -- AFTERNOON (אחר הצהריים) - Time Category: afternoon
    -- ============================================
    ('mincha_ketana', 'מנחה קטנה', 'Mincha Ketana', 'Mincha Ketana', 'afternoon', 'shaos(9.5, gra)', true, 500, 'Mincha Ketana - 9.5 proportional hours'),
    ('mincha_ketana_16_1', 'מנחה קטנה 16.1°', 'Mincha Ketana (16.1°)', 'Mincha Ketana 16.1', 'afternoon', 'shaos(9.5, alos_16_1)', false, 501, 'Mincha Ketana based on 16.1° calculation'),
    ('mincha_ketana_72', 'מנחה קטנה 72 דקות', 'Mincha Ketana (72 min)', 'Mincha Ketana 72', 'afternoon', 'shaos(9.5, mga)', false, 502, 'Mincha Ketana (MGA 72 minute day)'),
    ('samuch_lmincha_ketana', 'סמוך למנחה קטנה', 'Samuch L''Mincha Ketana', 'Samuch LMincha', 'afternoon', 'shaos(9, gra)', false, 505, 'Half hour before Mincha Ketana'),
    ('plag_hamincha', 'פלג המנחה', 'Plag HaMincha', 'Plag Hamincha', 'afternoon', 'shaos(10.75, gra)', true, 510, 'Plag HaMincha - 10.75 proportional hours (1.25 hours before sunset)'),
    ('plag_hamincha_16_1', 'פלג המנחה 16.1°', 'Plag HaMincha (16.1°)', 'Plag Hamincha 16.1', 'afternoon', 'shaos(10.75, alos_16_1)', false, 511, 'Plag HaMincha based on 16.1° calculation'),
    ('plag_hamincha_72', 'פלג המנחה 72 דקות', 'Plag HaMincha (72 min)', 'Plag Hamincha 72', 'afternoon', 'shaos(10.75, mga)', false, 512, 'Plag HaMincha (MGA 72 minute day)'),

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
    is_fundamental = EXCLUDED.is_fundamental,
    sort_order = EXCLUDED.sort_order,
    description = EXCLUDED.description,
    updated_at = now();

-- ============================================
-- PART 8: LINK TAGS TO MASTER REGISTRY
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
AND mr.default_formula_dsl LIKE 'shaos(%'
ON CONFLICT DO NOTHING;

-- ============================================
-- PART 9: COMMENTS
-- ============================================

COMMENT ON TABLE master_zmanim_registry IS 'Canonical list of all zmanim - publishers must select from this registry';
COMMENT ON COLUMN master_zmanim_registry.zman_key IS 'Unique identifier for this zman type';
COMMENT ON COLUMN master_zmanim_registry.time_category IS 'Time of day grouping for UI display';
COMMENT ON COLUMN master_zmanim_registry.is_fundamental IS 'If true, this zman cannot be removed from the registry';
COMMENT ON TABLE zman_tags IS 'Tags for categorizing zmanim by shita or calculation method';
COMMENT ON TABLE master_zman_tags IS 'Many-to-many relationship between zmanim and tags';
COMMENT ON TABLE publisher_zman_versions IS 'Version history for each publisher zman (max 7 versions, formula changes only)';
COMMENT ON TABLE zman_registry_requests IS 'Requests from publishers to add new zmanim to the master registry';
