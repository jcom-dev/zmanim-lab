-- Migration 4: Display Groups for UI Grouping
-- Creates display_groups table to replace hardcoded UI section groupings
-- This table maps multiple time_categories to a single UI display group

-- ============================================================================
-- DISPLAY GROUPS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.display_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(50) UNIQUE NOT NULL,
    display_name_hebrew VARCHAR(100) NOT NULL,
    display_name_english VARCHAR(100) NOT NULL,
    description VARCHAR(255),
    icon_name VARCHAR(50),
    color VARCHAR(50),
    sort_order INTEGER NOT NULL,
    time_categories TEXT[] NOT NULL, -- Maps time_categories to this group
    created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.display_groups IS 'UI display groups that aggregate multiple time_categories for visual presentation';
COMMENT ON COLUMN public.display_groups.key IS 'Unique identifier for the display group (dawn, morning, midday, evening)';
COMMENT ON COLUMN public.display_groups.icon_name IS 'Lucide icon name (e.g., Moon, Sun, Clock, Sunset)';
COMMENT ON COLUMN public.display_groups.time_categories IS 'Array of time_category keys that belong to this display group';

CREATE INDEX IF NOT EXISTS idx_display_groups_sort ON public.display_groups(sort_order);
CREATE INDEX IF NOT EXISTS idx_display_groups_key ON public.display_groups(key);

-- ============================================================================
-- SEED DATA: DISPLAY GROUPS
-- ============================================================================

INSERT INTO public.display_groups (key, display_name_hebrew, display_name_english, description, icon_name, color, sort_order, time_categories)
VALUES
    ('dawn', 'שחר', 'Dawn', 'Pre-sunrise zmanim', 'Moon', 'purple', 1, ARRAY['dawn']),
    ('morning', 'בוקר', 'Morning', 'Sunrise through late morning zmanim', 'Sun', 'amber', 2, ARRAY['sunrise', 'morning']),
    ('midday', 'צהריים', 'Midday', 'Midday and afternoon zmanim', 'Clock', 'orange', 3, ARRAY['midday', 'afternoon']),
    ('evening', 'ערב', 'Evening', 'Sunset through nightfall zmanim', 'Sunset', 'rose', 4, ARRAY['sunset', 'nightfall', 'midnight'])
ON CONFLICT (key) DO UPDATE SET
    display_name_hebrew = EXCLUDED.display_name_hebrew,
    display_name_english = EXCLUDED.display_name_english,
    description = EXCLUDED.description,
    icon_name = EXCLUDED.icon_name,
    color = EXCLUDED.color,
    sort_order = EXCLUDED.sort_order,
    time_categories = EXCLUDED.time_categories;
