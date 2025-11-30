-- Migration: Restructure Event Zmanim with event_category
-- Based on HebCal's approach: separate daily zmanim from event-specific times
-- Event zmanim are grouped by PURPOSE (candles, havdalah, fast_times, etc.)
-- not by day type (which causes duplication)

-- ============================================
-- PART 1: ADD EVENT_CATEGORY FIELD
-- ============================================

-- Add event_category to master_zmanim_registry
-- NULL = everyday zman (solar calculation)
-- Non-null = event-specific zman grouped by purpose
ALTER TABLE master_zmanim_registry
ADD COLUMN IF NOT EXISTS event_category VARCHAR(50);

-- Add index for querying by event_category
CREATE INDEX IF NOT EXISTS idx_master_registry_event_category
ON master_zmanim_registry(event_category) WHERE event_category IS NOT NULL;

-- ============================================
-- PART 2: SET EVENT CATEGORIES
-- ============================================

-- Candle Lighting - applies to Shabbos, Yom Tov, Yom Kippur
UPDATE master_zmanim_registry
SET event_category = 'candles'
WHERE zman_key LIKE 'candle_lighting%';

-- Havdalah / End Times - Shabbos and Yom Tov ends
UPDATE master_zmanim_registry
SET event_category = 'havdalah'
WHERE zman_key LIKE 'shabbos_ends%';

-- Yom Kippur specific times
UPDATE master_zmanim_registry
SET event_category = 'yom_kippur'
WHERE zman_key LIKE 'yom_kippur%';

-- Regular Fast Day times (not Tisha B'Av)
UPDATE master_zmanim_registry
SET event_category = 'fast_day'
WHERE zman_key LIKE 'fast_ends%';

-- Tisha B'Av specific times (starts at sunset unlike other fasts)
UPDATE master_zmanim_registry
SET event_category = 'tisha_bav'
WHERE zman_key LIKE 'tisha_bav%';

-- Pesach / Chametz times
UPDATE master_zmanim_registry
SET event_category = 'pesach'
WHERE zman_key LIKE 'sof_zman_achilas_chametz%'
   OR zman_key LIKE 'sof_zman_biur_chametz%';

-- ============================================
-- PART 3: ADD COMMENTS
-- ============================================

COMMENT ON COLUMN master_zmanim_registry.event_category IS
'Category for event-specific zmanim. NULL means everyday zman. Values: candles, havdalah, yom_kippur, fast_day, tisha_bav, pesach';

-- ============================================
-- PART 4: VERIFY DATA
-- ============================================

-- This should show all event zmanim grouped by category
-- SELECT event_category, array_agg(zman_key ORDER BY sort_order) as zmanim
-- FROM master_zmanim_registry
-- WHERE event_category IS NOT NULL
-- GROUP BY event_category
-- ORDER BY event_category;
