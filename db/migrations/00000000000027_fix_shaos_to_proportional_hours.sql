-- Fix invalid shaos() function calls to use proportional_hours()
-- The DSL uses proportional_hours() not shaos() for proportional hour calculations

-- Fix publisher_zmanim formulas
UPDATE publisher_zmanim
SET formula_dsl = REPLACE(formula_dsl, 'shaos(', 'proportional_hours('),
    updated_at = NOW()
WHERE formula_dsl LIKE '%shaos(%';

-- Fix zmanim_templates if any exist with shaos
UPDATE zmanim_templates
SET formula_dsl = REPLACE(formula_dsl, 'shaos(', 'proportional_hours('),
    updated_at = NOW()
WHERE formula_dsl LIKE '%shaos(%';

-- Fix master_zmanim_registry if any exist with shaos
UPDATE master_zmanim_registry
SET default_formula_dsl = REPLACE(default_formula_dsl, 'shaos(', 'proportional_hours('),
    updated_at = NOW()
WHERE default_formula_dsl LIKE '%shaos(%';

-- Fix astronomical_primitives if any exist with shaos
UPDATE astronomical_primitives
SET formula_dsl = REPLACE(formula_dsl, 'shaos(', 'proportional_hours('),
    updated_at = NOW()
WHERE formula_dsl LIKE '%shaos(%';
