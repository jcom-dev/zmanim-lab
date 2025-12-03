-- Migration 3: Database-driven zmanim categories
-- Creates time_categories, event_categories, and tag_types tables
-- to replace hardcoded frontend configurations

-- ============================================================================
-- TIME CATEGORIES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.time_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    display_name_hebrew VARCHAR(100) NOT NULL,
    display_name_english VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    icon_name VARCHAR(50),
    color VARCHAR(50),
    sort_order INTEGER NOT NULL,
    is_everyday BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.time_categories IS 'Time of day categories for grouping zmanim (dawn, sunrise, morning, etc.)';
COMMENT ON COLUMN public.time_categories.key IS 'Unique identifier matching master_zmanim_registry.time_category';
COMMENT ON COLUMN public.time_categories.icon_name IS 'Lucide icon name (e.g., Sunrise, Moon, Clock)';
COMMENT ON COLUMN public.time_categories.color IS 'Tailwind color class (e.g., purple, amber, indigo)';
COMMENT ON COLUMN public.time_categories.is_everyday IS 'True if this category applies to everyday zmanim';

CREATE INDEX IF NOT EXISTS idx_time_categories_sort ON public.time_categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_time_categories_key ON public.time_categories(key);

-- ============================================================================
-- EVENT CATEGORIES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.event_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    display_name_hebrew VARCHAR(100) NOT NULL,
    display_name_english VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    icon_name VARCHAR(50),
    color VARCHAR(50),
    sort_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.event_categories IS 'Event-based categories for special zmanim (candles, havdalah, fasts, etc.)';
COMMENT ON COLUMN public.event_categories.key IS 'Unique identifier for the event category';
COMMENT ON COLUMN public.event_categories.icon_name IS 'Lucide icon name';
COMMENT ON COLUMN public.event_categories.color IS 'Tailwind color class';

CREATE INDEX IF NOT EXISTS idx_event_categories_sort ON public.event_categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_event_categories_key ON public.event_categories(key);

-- ============================================================================
-- TAG TYPES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.tag_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    display_name_hebrew VARCHAR(100) NOT NULL,
    display_name_english VARCHAR(100) NOT NULL,
    color VARCHAR(255),
    sort_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.tag_types IS 'Types of tags used to categorize zmanim (timing, event, shita, method, behavior)';
COMMENT ON COLUMN public.tag_types.key IS 'Unique identifier matching zman_tags.tag_type';
COMMENT ON COLUMN public.tag_types.color IS 'Tailwind CSS classes for badge styling';

CREATE INDEX IF NOT EXISTS idx_tag_types_sort ON public.tag_types(sort_order);
CREATE INDEX IF NOT EXISTS idx_tag_types_key ON public.tag_types(key);

-- ============================================================================
-- SEED DATA: TIME CATEGORIES
-- ============================================================================

INSERT INTO public.time_categories (key, display_name_hebrew, display_name_english, description, icon_name, color, sort_order, is_everyday)
VALUES
    ('dawn', 'שחר', 'Dawn', 'Alos HaShachar variants', 'Sunrise', 'purple', 1, true),
    ('sunrise', 'זריחה', 'Sunrise', 'Sunrise and early morning', 'Sun', 'amber', 2, true),
    ('morning', 'בוקר', 'Morning', 'Shema and Tefillah times', 'Clock', 'yellow', 3, true),
    ('midday', 'צהריים', 'Midday', 'Chatzos and Mincha Gedolah', 'Sun', 'orange', 4, true),
    ('afternoon', 'אחה"צ', 'Afternoon', 'Mincha and Plag times', 'Clock', 'rose', 5, true),
    ('sunset', 'שקיעה', 'Sunset', 'Shkiah', 'Sunset', 'rose', 6, true),
    ('nightfall', 'צאת הכוכבים', 'Nightfall', 'Tzeis HaKochavim variants', 'Moon', 'indigo', 7, true),
    ('midnight', 'חצות לילה', 'Midnight', 'Chatzos Layla', 'Moon', 'slate', 8, true)
ON CONFLICT (key) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order,
    is_everyday = EXCLUDED.is_everyday;

-- ============================================================================
-- SEED DATA: EVENT CATEGORIES
-- ============================================================================

INSERT INTO public.event_categories (key, display_name_hebrew, display_name_english, description, icon_name, color, sort_order)
VALUES
    ('candles', 'הדלקת נרות', 'Candle Lighting', 'Shabbos, Yom Tov, and Yom Kippur', 'Flame', 'amber', 1),
    ('havdalah', 'הבדלה', 'Havdalah', 'End of Shabbos and Yom Tov', 'Flame', 'purple', 2),
    ('yom_kippur', 'יום כיפור', 'Yom Kippur', 'Fast start and end times', 'Moon', 'slate', 3),
    ('fast_day', 'תענית', 'Fast Days', 'Fast end times (regular fasts)', 'Timer', 'gray', 4),
    ('tisha_bav', 'תשעה באב', 'Tisha B''Av', 'Fast starts at sunset, ends at nightfall', 'Moon', 'slate', 5),
    ('pesach', 'פסח', 'Pesach', 'Chametz eating and burning times', 'Utensils', 'green', 6)
ON CONFLICT (key) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order;

-- ============================================================================
-- SEED DATA: TAG TYPES
-- ============================================================================

INSERT INTO public.tag_types (key, display_name_hebrew, display_name_english, color, sort_order)
VALUES
    ('timing', 'זמן', 'Time of Day', 'bg-green-500/10 text-green-700 border-green-300 dark:bg-green-500/20 dark:text-green-300 dark:border-green-700', 1),
    ('event', 'אירוע', 'Event Type', 'bg-blue-500/10 text-blue-700 border-blue-300 dark:bg-blue-500/20 dark:text-blue-300 dark:border-blue-700', 2),
    ('shita', 'שיטה', 'Shita (Halachic Opinion)', 'bg-cyan-500/10 text-cyan-700 border-cyan-300 dark:bg-cyan-500/20 dark:text-cyan-300 dark:border-cyan-700', 3),
    ('method', 'שיטת חישוב', 'Calculation Method', 'bg-purple-500/10 text-purple-700 border-purple-300 dark:bg-purple-500/20 dark:text-purple-300 dark:border-purple-700', 4),
    ('behavior', 'התנהגות', 'Behavior', 'bg-orange-500/10 text-orange-700 border-orange-300 dark:bg-orange-500/20 dark:text-orange-300 dark:border-orange-700', 5),
    ('category', 'קטגוריה', 'Category', 'bg-gray-500/10 text-gray-700 border-gray-300 dark:bg-gray-500/20 dark:text-gray-300 dark:border-gray-700', 6),
    ('calculation', 'חישוב', 'Calculation', 'bg-indigo-500/10 text-indigo-700 border-indigo-300 dark:bg-indigo-500/20 dark:text-indigo-300 dark:border-indigo-700', 7)
ON CONFLICT (key) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order;
