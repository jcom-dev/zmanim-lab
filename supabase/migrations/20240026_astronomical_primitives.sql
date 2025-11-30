-- ============================================
-- ASTRONOMICAL PRIMITIVES REGISTRY
-- ============================================
-- Defines the canonical set of astronomical times that can be referenced
-- in DSL formulas. These are the "atoms" of the zmanim calculation system.
--
-- Each primitive has:
--   - A unique variable_name (snake_case) for use in formulas
--   - Scientific and display names
--   - The formula/calculation definition
--   - Category for grouping in UI

CREATE TABLE IF NOT EXISTS astronomical_primitives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- The unique variable name used in formulas (e.g., 'sunrise', 'nautical_dawn')
    -- This is what users type in DSL formulas
    variable_name VARCHAR(50) UNIQUE NOT NULL,

    -- Display names for UI
    display_name TEXT NOT NULL,                    -- e.g., 'Sunrise (Center)'
    description TEXT,                              -- e.g., 'Sun center crosses horizon'

    -- The DSL formula that calculates this primitive
    -- For base primitives, this is the primitive name itself
    -- For derived primitives, this shows how it's calculated
    formula_dsl TEXT NOT NULL,                     -- e.g., 'solar(6, before_sunrise)' or 'sunrise'

    -- Category for grouping in UI dropdowns
    category VARCHAR(50) NOT NULL,                 -- e.g., 'horizon', 'civil_twilight', 'nautical_twilight', 'astronomical_twilight', 'solar_position'

    -- Calculation parameters (metadata for documentation/validation)
    calculation_type VARCHAR(30) NOT NULL,         -- 'horizon', 'solar_angle', 'transit'
    solar_angle DECIMAL(5,2),                      -- Degrees below horizon (NULL for horizon events)
    is_dawn BOOLEAN,                               -- true = morning, false = evening, NULL = n/a (solar_noon)
    edge_type VARCHAR(20) DEFAULT 'center',        -- 'center', 'top_edge', 'bottom_edge'

    -- Ordering
    sort_order INT DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,

    -- Constraints
    CONSTRAINT chk_calculation_type CHECK (calculation_type IN ('horizon', 'solar_angle', 'transit')),
    CONSTRAINT chk_edge_type CHECK (edge_type IN ('center', 'top_edge', 'bottom_edge')),
    CONSTRAINT chk_category CHECK (category IN (
        'horizon',
        'civil_twilight',
        'nautical_twilight',
        'astronomical_twilight',
        'solar_position'
    )),
    -- Solar angle required for solar_angle type
    CONSTRAINT chk_solar_angle CHECK (
        (calculation_type = 'solar_angle' AND solar_angle IS NOT NULL) OR
        (calculation_type != 'solar_angle')
    )
);

-- Create index for fast lookups by variable_name (used in formula parsing)
CREATE INDEX idx_astronomical_primitives_variable_name ON astronomical_primitives(variable_name);
CREATE INDEX idx_astronomical_primitives_category ON astronomical_primitives(category);

-- ============================================
-- SEED DATA: All astronomical primitives
-- ============================================
-- Each primitive has a unique variable_name and the DSL formula to calculate it

INSERT INTO astronomical_primitives (variable_name, display_name, description, formula_dsl, category, calculation_type, solar_angle, is_dawn, edge_type, sort_order) VALUES
-- ============================================
-- HORIZON EVENTS (sun crosses 0° horizon)
-- ============================================
('sunrise', 'Sunrise', 'Geometric sunrise - sun center crosses the horizon (0°)', 'sunrise', 'horizon', 'horizon', NULL, true, 'center', 100),
('sunset', 'Sunset', 'Geometric sunset - sun center crosses the horizon (0°)', 'sunset', 'horizon', 'horizon', NULL, false, 'center', 101),
('sunrise_visible', 'Sunrise (Visible)', 'First visible edge of sun appears above horizon (accounting for refraction)', 'visible_sunrise', 'horizon', 'horizon', NULL, true, 'top_edge', 102),
('sunset_visible', 'Sunset (Visible)', 'Last visible edge of sun disappears below horizon (accounting for refraction)', 'visible_sunset', 'horizon', 'horizon', NULL, false, 'top_edge', 103),

-- ============================================
-- CIVIL TWILIGHT (6° below horizon)
-- ============================================
('civil_dawn', 'Civil Dawn', 'Sun 6° below horizon - enough light for outdoor activities without artificial light', 'solar(6, before_sunrise)', 'civil_twilight', 'solar_angle', 6.0, true, 'center', 200),
('civil_dusk', 'Civil Dusk', 'Sun 6° below horizon - artificial light needed for outdoor activities', 'solar(6, after_sunset)', 'civil_twilight', 'solar_angle', 6.0, false, 'center', 201),

-- ============================================
-- NAUTICAL TWILIGHT (12° below horizon)
-- ============================================
('nautical_dawn', 'Nautical Dawn', 'Sun 12° below horizon - horizon visible at sea for navigation', 'solar(12, before_sunrise)', 'nautical_twilight', 'solar_angle', 12.0, true, 'center', 300),
('nautical_dusk', 'Nautical Dusk', 'Sun 12° below horizon - horizon no longer visible at sea', 'solar(12, after_sunset)', 'nautical_twilight', 'solar_angle', 12.0, false, 'center', 301),

-- ============================================
-- ASTRONOMICAL TWILIGHT (18° below horizon)
-- ============================================
('astronomical_dawn', 'Astronomical Dawn', 'Sun 18° below horizon - sky completely dark before this, first hint of light', 'solar(18, before_sunrise)', 'astronomical_twilight', 'solar_angle', 18.0, true, 'center', 400),
('astronomical_dusk', 'Astronomical Dusk', 'Sun 18° below horizon - sky becomes completely dark after this', 'solar(18, after_sunset)', 'astronomical_twilight', 'solar_angle', 18.0, false, 'center', 401),

-- ============================================
-- SOLAR POSITION (transit events)
-- ============================================
('solar_noon', 'Solar Noon', 'Sun at highest point in the sky (transit/meridian crossing)', 'solar_noon', 'solar_position', 'transit', NULL, NULL, 'center', 500),
('solar_midnight', 'Solar Midnight', 'Sun at lowest point (anti-transit) - opposite side of Earth', 'solar_midnight', 'solar_position', 'transit', NULL, NULL, 'center', 501);

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE astronomical_primitives IS 'Canonical registry of astronomical times that can be referenced in DSL formulas. These are pure astronomical calculations with no halachic interpretation.';
COMMENT ON COLUMN astronomical_primitives.variable_name IS 'The unique identifier used in DSL formulas (e.g., sunrise, nautical_dawn). Must be snake_case.';
COMMENT ON COLUMN astronomical_primitives.formula_dsl IS 'The DSL formula that calculates this time. Base primitives use their own name, derived use solar() function.';
COMMENT ON COLUMN astronomical_primitives.calculation_type IS 'How to compute: horizon (0° crossing), solar_angle (degrees below horizon), transit (noon/midnight)';
COMMENT ON COLUMN astronomical_primitives.solar_angle IS 'Degrees below horizon for solar_angle calculations (6° civil, 12° nautical, 18° astronomical)';
COMMENT ON COLUMN astronomical_primitives.is_dawn IS 'True for morning events (dawn/sunrise), false for evening events (dusk/sunset), NULL for position events (noon/midnight)';
COMMENT ON COLUMN astronomical_primitives.edge_type IS 'Which part of the sun: center (geometric), top_edge (visible sunrise/sunset), bottom_edge';
