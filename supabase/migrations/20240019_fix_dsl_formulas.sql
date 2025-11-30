-- Fix DSL formulas: shaos() returns absolute Time, not Duration
-- The formula "sunrise + shaos(3, gra)" is incorrect because shaos(3, gra)
-- already calculates the absolute time 3 hours after sunrise.
-- Similarly, "shaos(3, mga)" returns the time 3 hours after dawn (72min before sunrise).

-- Delete all existing templates and re-insert with correct formulas
DELETE FROM zmanim_templates;

-- Insert corrected zmanim templates
-- Note: shaos(N, gra) = N proportional hours after sunrise (GRA method)
--       shaos(N, mga) = N proportional hours after dawn/alos (MGA method, 72-minute dawn)
INSERT INTO zmanim_templates (zman_key, hebrew_name, english_name, formula_dsl, category, is_required, sort_order) VALUES
  -- ============================================
  -- ESSENTIAL ZMANIM (Always shown by default)
  -- ============================================

  -- Dawn/Alos - When the first light appears
  ('alos_hashachar', 'עלות השחר', 'Alos Hashachar (Dawn)', 'solar(16.1, before_sunrise)', 'essential', true, 1),

  -- Misheyakir - Earliest time for tallit/tefillin
  ('misheyakir', 'משיכיר', 'Misheyakir', 'solar(11.5, before_sunrise)', 'essential', true, 2),

  -- Sunrise - Visible sunrise
  ('sunrise', 'הנץ החמה', 'Sunrise', 'sunrise', 'essential', true, 3),

  -- Latest Shema (GRA) - 3 proportional hours into the day
  ('sof_zman_shma_gra', 'סוף זמן ק"ש גר"א', 'Latest Shema (GRA)', 'shaos(3, gra)', 'essential', true, 4),

  -- Latest Shema (MGA) - 3 proportional hours from 72-min dawn
  ('sof_zman_shma_mga', 'סוף זמן ק"ש מג"א', 'Latest Shema (MGA)', 'shaos(3, mga)', 'essential', true, 5),

  -- Latest Shacharit (GRA) - 4 proportional hours into the day
  ('sof_zman_tfila_gra', 'סוף זמן תפילה גר"א', 'Latest Shacharit (GRA)', 'shaos(4, gra)', 'essential', true, 6),

  -- Chatzos - Solar noon / midday
  ('chatzos', 'חצות היום', 'Chatzos (Midday)', 'solar_noon', 'essential', true, 7),

  -- Mincha Gedola - Earliest Mincha, 30 min after chatzos
  ('mincha_gedola', 'מנחה גדולה', 'Mincha Gedola', 'solar_noon + 30min', 'essential', true, 8),

  -- Mincha Ketana - 9.5 proportional hours
  ('mincha_ketana', 'מנחה קטנה', 'Mincha Ketana', 'shaos(9.5, gra)', 'essential', true, 9),

  -- Plag HaMincha - 10.75 proportional hours (1.25 hours before sunset)
  ('plag_hamincha', 'פלג המנחה', 'Plag HaMincha', 'shaos(10.75, gra)', 'essential', true, 10),

  -- Sunset - Visible sunset
  ('sunset', 'שקיעה', 'Sunset', 'sunset', 'essential', true, 11),

  -- Tzais - Nightfall when 3 stars visible
  ('tzais', 'צאת הכוכבים', 'Tzais (Nightfall)', 'solar(8.5, after_sunset)', 'essential', true, 12),

  -- ============================================
  -- OPTIONAL ZMANIM (User can enable)
  -- ============================================

  -- Latest Shacharit (MGA) - 4 hours from 72-min dawn
  ('sof_zman_tfila_mga', 'סוף זמן תפילה מג"א', 'Latest Shacharit (MGA)', 'shaos(4, mga)', 'optional', false, 20),

  -- Alos 72 Minutes - Fixed 72 minutes before sunrise
  ('alos_72', 'עלות 72 דקות', 'Alos 72 Minutes', 'sunrise - 72min', 'optional', false, 21),

  -- Alos 90 Minutes - Fixed 90 minutes before sunrise
  ('alos_90', 'עלות 90 דקות', 'Alos 90 Minutes', 'sunrise - 90min', 'optional', false, 22),

  -- Alos 120 Minutes - Fixed 120 minutes before sunrise
  ('alos_120', 'עלות 120 דקות', 'Alos 120 Minutes', 'sunrise - 120min', 'optional', false, 23),

  -- Tzais Rabbeinu Tam - 72 minutes after sunset
  ('tzais_72', 'צאת ר"ת', 'Tzais Rabbeinu Tam (72 min)', 'sunset + 72min', 'optional', false, 24),

  -- Tzais 42 Minutes
  ('tzais_42', 'צאת 42 דקות', 'Tzais 42 Minutes', 'sunset + 42min', 'optional', false, 25),

  -- Tzais 50 Minutes
  ('tzais_50', 'צאת 50 דקות', 'Tzais 50 Minutes', 'sunset + 50min', 'optional', false, 26),

  -- Tzais 3 Stars (stricter, ~8.5 degrees)
  ('tzais_3_stars', 'צאת 3 כוכבים', 'Tzais 3 Stars', 'solar(8.5, after_sunset)', 'optional', false, 27),

  -- Candle Lighting - 18 minutes before sunset
  ('candle_lighting', 'הדלקת נרות', 'Candle Lighting', 'sunset - 18min', 'optional', false, 28),

  -- Candle Lighting 20 min (Jerusalem custom)
  ('candle_lighting_20', 'הדלקת נרות (ירושלים)', 'Candle Lighting (Jerusalem)', 'sunset - 20min', 'optional', false, 29),

  -- Candle Lighting 40 min (Jerusalem strict)
  ('candle_lighting_40', 'הדלקת נרות (40 דקות)', 'Candle Lighting (40 min)', 'sunset - 40min', 'optional', false, 30),

  -- Shkia Amitis - "True" sunset accounting for elevation
  ('shkia_amitis', 'שקיעה אמיתית', 'True Sunset', 'sunset', 'optional', false, 31),

  -- Chatzos Layla - Midnight (12 hours from solar noon)
  ('chatzos_layla', 'חצות לילה', 'Chatzos Layla (Midnight)', 'solar_noon + 12hr', 'optional', false, 32),

  -- Samuch L'Mincha Ketana - Close to Mincha Ketana (9 hours)
  ('samuch_lmincha', 'סמוך למנחה קטנה', 'Samuch L''Mincha Ketana', 'shaos(9, gra)', 'optional', false, 33),

  -- Bein Hashmashos - Twilight period start
  ('bein_hashmashos', 'בין השמשות', 'Bein Hashmashos', 'sunset', 'optional', false, 34),

  -- Earliest Kiddush Levana (3 days after molad)
  -- Note: This is a placeholder - actual calculation needs lunar data
  ('kiddush_levana_earliest', 'קידוש לבנה מוקדם', 'Earliest Kiddush Levana', 'sunset + 72min', 'optional', false, 40),

  -- Latest Kiddush Levana (15 days after molad)
  -- Note: This is a placeholder - actual calculation needs lunar data
  ('kiddush_levana_latest', 'סוף קידוש לבנה', 'Latest Kiddush Levana', 'sunset', 'optional', false, 41)
ON CONFLICT (zman_key) DO UPDATE SET
  hebrew_name = EXCLUDED.hebrew_name,
  english_name = EXCLUDED.english_name,
  formula_dsl = EXCLUDED.formula_dsl,
  category = EXCLUDED.category,
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order,
  updated_at = now();

-- Also fix any existing publisher_zmanim that have incorrect formulas
-- Update formulas that incorrectly use "sunrise + shaos(...)"
UPDATE publisher_zmanim
SET formula_dsl = 'shaos(3, gra)', updated_at = now()
WHERE formula_dsl = 'sunrise + shaos(3, gra)';

UPDATE publisher_zmanim
SET formula_dsl = 'shaos(4, gra)', updated_at = now()
WHERE formula_dsl = 'sunrise + shaos(4, gra)';

UPDATE publisher_zmanim
SET formula_dsl = 'shaos(6.5, gra)', updated_at = now()
WHERE formula_dsl = 'solar_noon + shaos(0.5, gra)';

UPDATE publisher_zmanim
SET formula_dsl = 'shaos(9.5, gra)', updated_at = now()
WHERE formula_dsl = 'sunrise + shaos(9.5, gra)';

UPDATE publisher_zmanim
SET formula_dsl = 'shaos(10.75, gra)', updated_at = now()
WHERE formula_dsl = 'sunrise + shaos(10.75, gra)';

-- Fix MGA formulas
UPDATE publisher_zmanim
SET formula_dsl = 'shaos(3, mga)', updated_at = now()
WHERE formula_dsl = 'sunrise - 72min + shaos(3, mga)';

UPDATE publisher_zmanim
SET formula_dsl = 'shaos(4, mga)', updated_at = now()
WHERE formula_dsl = 'sunrise - 72min + shaos(4, mga)';

-- Fix any formula using "sunset - shaos(...)" pattern
UPDATE publisher_zmanim
SET formula_dsl = 'shaos(9.5, gra)', updated_at = now()
WHERE formula_dsl = 'sunset - shaos(2.5, gra)';

UPDATE publisher_zmanim
SET formula_dsl = 'shaos(10.75, gra)', updated_at = now()
WHERE formula_dsl = 'sunset - shaos(1.25, gra)';

-- Update comment to reflect correct formula syntax
COMMENT ON COLUMN publisher_zmanim.formula_dsl IS 'DSL formula string. Examples: "shaos(3, gra)" for 3 hours after sunrise, "solar(16.1, before_sunrise)" for dawn';
COMMENT ON COLUMN zmanim_templates.formula_dsl IS 'DSL formula string. shaos(N, gra) returns absolute time N hours after sunrise. shaos(N, mga) returns N hours after dawn (72min before sunrise).';
