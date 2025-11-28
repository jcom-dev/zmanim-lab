-- Migration: Add bilingual naming support for zmanim
-- Story: 4-3 Bilingual Naming System

-- Create zman_definitions table for standard zman names
CREATE TABLE IF NOT EXISTS zman_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    name_hebrew TEXT NOT NULL,
    name_english TEXT NOT NULL,
    transliteration TEXT,
    category VARCHAR(50) NOT NULL DEFAULT 'general',
    sort_order INT DEFAULT 0,
    is_standard BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hebrew_name CHECK (name_hebrew ~ '[א-ת]')
);

CREATE INDEX idx_zman_definitions_key ON zman_definitions(key);
CREATE INDEX idx_zman_definitions_category ON zman_definitions(category);

-- Create trigger for updated_at
CREATE TRIGGER update_zman_definitions_updated_at BEFORE UPDATE ON zman_definitions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Add bilingual fields to publisher_algorithms zmanim configuration
-- (This is handled in JSONB, no schema change needed)

-- Seed standard zman definitions (20+ common zmanim)
INSERT INTO zman_definitions (key, name_hebrew, name_english, transliteration, category, sort_order, is_standard) VALUES
-- Morning/Dawn
('alos_hashachar', 'עלות השחר', 'Dawn', 'Alos HaShachar', 'dawn', 10, true),
('alos_16_1', 'עלות השחר 16.1°', 'Dawn (16.1°)', 'Alos 16.1', 'dawn', 11, true),
('alos_72', 'עלות השחר 72 דקות', 'Dawn (72 minutes)', 'Alos 72', 'dawn', 12, true),
('alos_90', 'עלות השחר 90 דקות', 'Dawn (90 minutes)', 'Alos 90', 'dawn', 13, true),
('misheyakir', 'משיכיר', 'Misheyakir', 'Misheyakir', 'dawn', 20, true),
('misheyakir_10_2', 'משיכיר 10.2°', 'Misheyakir (10.2°)', 'Misheyakir 10.2', 'dawn', 21, true),

-- Sunrise
('sunrise', 'נץ החמה', 'Sunrise', 'Netz HaChama', 'sunrise', 30, true),
('visible_sunrise', 'נץ החמה הנראה', 'Visible Sunrise', 'Netz HaChama HaNireh', 'sunrise', 31, true),

-- Morning Times
('sof_zman_shma_gra', 'סוף זמן שמע גר״א', 'Latest Shema (GRA)', 'Sof Zman Shma GRA', 'morning', 40, true),
('sof_zman_shma_mga', 'סוף זמן שמע מג״א', 'Latest Shema (MGA)', 'Sof Zman Shma MGA', 'morning', 41, true),
('sof_zman_tefilla_gra', 'סוף זמן תפילה גר״א', 'Latest Shacharit (GRA)', 'Sof Zman Tefilla GRA', 'morning', 50, true),
('sof_zman_tefilla_mga', 'סוף זמן תפילה מג״א', 'Latest Shacharit (MGA)', 'Sof Zman Tefilla MGA', 'morning', 51, true),

-- Midday
('chatzos', 'חצות היום', 'Midday', 'Chatzos HaYom', 'midday', 60, true),
('chatzos_hayom', 'חצות היום', 'Solar Noon', 'Chatzos HaYom', 'midday', 61, true),

-- Afternoon
('mincha_gedola', 'מנחה גדולה', 'Earliest Mincha', 'Mincha Gedolah', 'afternoon', 70, true),
('mincha_gedola_30', 'מנחה גדולה 30 דקות', 'Earliest Mincha (30 min)', 'Mincha Gedolah 30', 'afternoon', 71, true),
('mincha_ketana', 'מנחה קטנה', 'Mincha Ketana', 'Mincha Ketanah', 'afternoon', 80, true),
('plag_hamincha', 'פלג המנחה', 'Plag HaMincha', 'Plag HaMincha', 'afternoon', 90, true),

-- Sunset
('sunset', 'שקיעת החמה', 'Sunset', 'Shkias HaChama', 'sunset', 100, true),
('shkiah', 'שקיעה', 'Sunset', 'Shkiah', 'sunset', 101, true),

-- Nightfall
('bein_hashmashos', 'בין השמשות', 'Twilight', 'Bein HaShmashos', 'nightfall', 110, true),
('tzeis_hakochavim', 'צאת הכוכבים', 'Nightfall', 'Tzeis HaKochavim', 'nightfall', 120, true),
('tzeis_8_5', 'צאת הכוכבים 8.5°', 'Nightfall (8.5°)', 'Tzeis 8.5', 'nightfall', 121, true),
('tzeis_72', 'צאת הכוכבים 72 דקות', 'Nightfall (72 minutes)', 'Tzeis 72', 'nightfall', 122, true),
('tzeis_rabbeinu_tam', 'צאת הכוכבים רבינו תם', 'Nightfall (Rabbeinu Tam)', 'Tzeis Rabbeinu Tam', 'nightfall', 123, true),

-- Midnight
('chatzos_laila', 'חצות הלילה', 'Midnight', 'Chatzos HaLailah', 'midnight', 130, true),

-- Shabbat/Holiday specific
('candle_lighting', 'הדלקת נרות', 'Candle Lighting', 'Hadlakas Neiros', 'shabbat', 140, true),
('motzei_shabbat', 'מוצאי שבת', 'End of Shabbat', 'Motzei Shabbat', 'shabbat', 150, true),

-- Fast days
('fast_begins', 'תחילת הצום', 'Fast Begins', 'Techilas HaTzom', 'fast', 160, true),
('fast_ends', 'סיום הצום', 'Fast Ends', 'Siyum HaTzom', 'fast', 170, true)

ON CONFLICT (key) DO UPDATE SET
    name_hebrew = EXCLUDED.name_hebrew,
    name_english = EXCLUDED.name_english,
    transliteration = EXCLUDED.transliteration,
    category = EXCLUDED.category,
    sort_order = EXCLUDED.sort_order,
    is_standard = EXCLUDED.is_standard,
    updated_at = NOW();
