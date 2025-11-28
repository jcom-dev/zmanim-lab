-- Epic 4: Publisher Zmanim Refactor
-- Migrate from JSON-based algorithm config to individual zman rows with DSL formulas

-- Create publisher_zmanim table
CREATE TABLE IF NOT EXISTS publisher_zmanim (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
  zman_key TEXT NOT NULL,
  hebrew_name TEXT NOT NULL,
  english_name TEXT NOT NULL,
  formula_dsl TEXT NOT NULL,
  ai_explanation TEXT,
  publisher_comment TEXT,
  is_enabled BOOLEAN DEFAULT true NOT NULL,
  is_visible BOOLEAN DEFAULT true NOT NULL,
  is_custom BOOLEAN DEFAULT false NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('essential', 'optional', 'custom')),
  dependencies TEXT[] DEFAULT '{}' NOT NULL,
  sort_order INTEGER DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

  UNIQUE(publisher_id, zman_key)
);

-- Create indexes for performance
CREATE INDEX idx_publisher_zmanim_publisher ON publisher_zmanim(publisher_id);
CREATE INDEX idx_publisher_zmanim_enabled ON publisher_zmanim(publisher_id, is_enabled) WHERE is_enabled = true;
CREATE INDEX idx_publisher_zmanim_category ON publisher_zmanim(category);
CREATE INDEX idx_publisher_zmanim_custom ON publisher_zmanim(publisher_id, is_custom) WHERE is_custom = true;

-- Add RLS (Row Level Security) policies
ALTER TABLE publisher_zmanim ENABLE ROW LEVEL SECURITY;

-- Publishers can view their own zmanim
CREATE POLICY "Publishers can view own zmanim"
  ON publisher_zmanim
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM publisher_users
      WHERE publisher_users.publisher_id = publisher_zmanim.publisher_id
      AND publisher_users.user_id = auth.uid()
    )
  );

-- Publishers can insert their own zmanim
CREATE POLICY "Publishers can create own zmanim"
  ON publisher_zmanim
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM publisher_users
      WHERE publisher_users.publisher_id = publisher_zmanim.publisher_id
      AND publisher_users.user_id = auth.uid()
    )
  );

-- Publishers can update their own zmanim
CREATE POLICY "Publishers can update own zmanim"
  ON publisher_zmanim
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM publisher_users
      WHERE publisher_users.publisher_id = publisher_zmanim.publisher_id
      AND publisher_users.user_id = auth.uid()
    )
  );

-- Publishers can delete only custom zmanim
CREATE POLICY "Publishers can delete custom zmanim"
  ON publisher_zmanim
  FOR DELETE
  USING (
    is_custom = true
    AND EXISTS (
      SELECT 1 FROM publisher_users
      WHERE publisher_users.publisher_id = publisher_zmanim.publisher_id
      AND publisher_users.user_id = auth.uid()
    )
  );

-- Anyone can view public zmanim for browsing/copying
CREATE POLICY "Public zmanim visible to all authenticated users"
  ON publisher_zmanim
  FOR SELECT
  USING (is_visible = true AND auth.role() = 'authenticated');

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_publisher_zmanim_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER publisher_zmanim_updated_at
  BEFORE UPDATE ON publisher_zmanim
  FOR EACH ROW
  EXECUTE FUNCTION update_publisher_zmanim_updated_at();

-- Create zmanim_templates table for system defaults
CREATE TABLE IF NOT EXISTS zmanim_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zman_key TEXT UNIQUE NOT NULL,
  hebrew_name TEXT NOT NULL,
  english_name TEXT NOT NULL,
  formula_dsl TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('essential', 'optional')),
  description TEXT,
  is_required BOOLEAN DEFAULT false NOT NULL,
  sort_order INTEGER DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX idx_zmanim_templates_category ON zmanim_templates(category);
CREATE INDEX idx_zmanim_templates_sort ON zmanim_templates(sort_order);

-- Seed essential zmanim templates
INSERT INTO zmanim_templates (zman_key, hebrew_name, english_name, formula_dsl, category, is_required, sort_order) VALUES
  -- Essential Zmanim
  ('alos_hashachar', 'עלות השחר', 'Alos Hashachar', 'solar(16.1, before_sunrise)', 'essential', true, 1),
  ('misheyakir', 'משיכיר', 'Misheyakir', 'solar(11.5, before_sunrise)', 'essential', true, 2),
  ('sunrise', 'הנץ החמה', 'Sunrise', 'sunrise', 'essential', true, 3),
  ('sof_zman_shma_gra', 'סוף זמן ק"ש גר"א', 'Sof Zman Shma (GRA)', 'sunrise + shaos(3, gra)', 'essential', true, 4),
  ('sof_zman_tfila_gra', 'סוף זמן תפילה גר"א', 'Sof Zman Tfila (GRA)', 'sunrise + shaos(4, gra)', 'essential', true, 5),
  ('chatzos', 'חצות', 'Chatzos', 'solar_noon', 'essential', true, 6),
  ('mincha_gedola', 'מנחה גדולה', 'Mincha Gedola', 'solar_noon + 30min', 'essential', true, 7),
  ('mincha_ketana', 'מנחה קטנה', 'Mincha Ketana', 'sunrise + shaos(9.5, gra)', 'essential', true, 8),
  ('plag_hamincha', 'פלג המנחה', 'Plag Hamincha', 'sunrise + shaos(10.75, gra)', 'essential', true, 9),
  ('sunset', 'שקיעה', 'Sunset', 'sunset', 'essential', true, 10),
  ('tzais', 'צאת הכוכבים', 'Tzais', 'solar(8.5, after_sunset)', 'essential', true, 11),

  -- Optional Zmanim
  ('sof_zman_shma_mga', 'סוף זמן ק"ש מג"א', 'Sof Zman Shma (MGA)', 'sunrise - 72min + shaos(3, mga)', 'optional', false, 20),
  ('sof_zman_tfila_mga', 'סוף זמן תפילה מג"א', 'Sof Zman Tfila (MGA)', 'sunrise - 72min + shaos(4, mga)', 'optional', false, 21),
  ('alos_72', 'עלות 72 דקות', 'Alos 72 Minutes', 'sunrise - 72min', 'optional', false, 22),
  ('alos_90', 'עלות 90 דקות', 'Alos 90 Minutes', 'sunrise - 90min', 'optional', false, 23),
  ('tzais_72', 'צאת 72 דקות', 'Tzais 72 Minutes (Rabbeinu Tam)', 'sunset + 72min', 'optional', false, 24),
  ('tzais_42', 'צאת 42 דקות', 'Tzais 42 Minutes', 'sunset + 42min', 'optional', false, 25),
  ('candle_lighting', 'הדלקת נרות', 'Candle Lighting', 'sunset - 18min', 'optional', false, 26)
ON CONFLICT (zman_key) DO NOTHING;

-- Comment on tables
COMMENT ON TABLE publisher_zmanim IS 'Individual zmanim formulas for each publisher using DSL syntax (Epic 4)';
COMMENT ON TABLE zmanim_templates IS 'System-wide default zmanim formulas that publishers can copy from';
COMMENT ON COLUMN publisher_zmanim.formula_dsl IS 'DSL formula string (e.g., "sunrise + shaos(3, gra)")';
COMMENT ON COLUMN publisher_zmanim.dependencies IS 'Auto-extracted @references from formula_dsl';
COMMENT ON COLUMN publisher_zmanim.category IS 'essential = always enabled, optional = can toggle, custom = user created';
