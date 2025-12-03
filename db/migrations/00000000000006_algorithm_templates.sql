-- Migration 6: Create algorithm_templates table
-- Replaces hardcoded algorithm templates in publisher_algorithm.go

-- Algorithm templates table for bundled algorithm configurations (GRA, MGA, etc.)
CREATE TABLE IF NOT EXISTS public.algorithm_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    template_key text NOT NULL,
    name text NOT NULL,
    description text,
    configuration jsonb NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT algorithm_templates_pkey PRIMARY KEY (id),
    CONSTRAINT algorithm_templates_template_key_key UNIQUE (template_key)
);

COMMENT ON TABLE public.algorithm_templates IS 'System-wide algorithm templates that publishers can use as starting points';
COMMENT ON COLUMN public.algorithm_templates.template_key IS 'Unique identifier (e.g., gra, mga, rabbeinu_tam, custom)';
COMMENT ON COLUMN public.algorithm_templates.configuration IS 'Full algorithm JSON configuration with name, description, and zmanim map';
COMMENT ON COLUMN public.algorithm_templates.sort_order IS 'Display order in the template picker';
COMMENT ON COLUMN public.algorithm_templates.is_active IS 'Whether this template is available for selection';

-- Index for efficient lookups
CREATE INDEX idx_algorithm_templates_key ON public.algorithm_templates USING btree (template_key);
CREATE INDEX idx_algorithm_templates_active ON public.algorithm_templates USING btree (is_active) WHERE is_active = true;

-- Seed the algorithm templates (migrated from hardcoded data in publisher_algorithm.go)
INSERT INTO public.algorithm_templates (template_key, name, description, configuration, sort_order, is_active) VALUES
(
    'gra',
    'GRA (Vilna Gaon)',
    'Standard calculation based on the Vilna Gaon. Uses sunrise to sunset for proportional hours.',
    '{
        "name": "GRA",
        "description": "Vilna Gaon standard calculation",
        "zmanim": {
            "alos_hashachar": {"method": "solar_angle", "params": {"degrees": 16.1}},
            "misheyakir": {"method": "solar_angle", "params": {"degrees": 11.5}},
            "sunrise": {"method": "sunrise", "params": {}},
            "sof_zman_shma_gra": {"method": "proportional", "params": {"hours": 3.0, "base": "gra"}},
            "sof_zman_tfila_gra": {"method": "proportional", "params": {"hours": 4.0, "base": "gra"}},
            "chatzos": {"method": "midpoint", "params": {"start": "sunrise", "end": "sunset"}},
            "mincha_gedola": {"method": "proportional", "params": {"hours": 6.5, "base": "gra"}},
            "mincha_ketana": {"method": "proportional", "params": {"hours": 9.5, "base": "gra"}},
            "plag_hamincha": {"method": "proportional", "params": {"hours": 10.75, "base": "gra"}},
            "sunset": {"method": "sunset", "params": {}},
            "tzais": {"method": "solar_angle", "params": {"degrees": 8.5}}
        }
    }'::jsonb,
    1,
    true
),
(
    'mga',
    'MGA (Magen Avraham)',
    'Magen Avraham calculation. Uses 72 minutes before sunrise to 72 minutes after sunset for proportional hours.',
    '{
        "name": "MGA",
        "description": "Magen Avraham calculation",
        "zmanim": {
            "alos_hashachar": {"method": "fixed_minutes", "params": {"minutes": -72.0, "from": "sunrise"}},
            "misheyakir": {"method": "solar_angle", "params": {"degrees": 11.5}},
            "sunrise": {"method": "sunrise", "params": {}},
            "sof_zman_shma_mga": {"method": "proportional", "params": {"hours": 3.0, "base": "mga"}},
            "sof_zman_tfila_mga": {"method": "proportional", "params": {"hours": 4.0, "base": "mga"}},
            "chatzos": {"method": "midpoint", "params": {"start": "sunrise", "end": "sunset"}},
            "mincha_gedola": {"method": "proportional", "params": {"hours": 6.5, "base": "mga"}},
            "mincha_ketana": {"method": "proportional", "params": {"hours": 9.5, "base": "mga"}},
            "plag_hamincha": {"method": "proportional", "params": {"hours": 10.75, "base": "mga"}},
            "sunset": {"method": "sunset", "params": {}},
            "tzeis_72": {"method": "fixed_minutes", "params": {"minutes": 72.0, "from": "sunset"}}
        }
    }'::jsonb,
    2,
    true
),
(
    'rabbeinu_tam',
    'Rabbeinu Tam',
    'Uses 72 minutes after sunset for tzeis based on Rabbeinu Tam''s opinion.',
    '{
        "name": "Rabbeinu Tam",
        "description": "Rabbeinu Tam calculation for tzeis",
        "zmanim": {
            "alos_hashachar": {"method": "solar_angle", "params": {"degrees": 16.1}},
            "misheyakir": {"method": "solar_angle", "params": {"degrees": 11.5}},
            "sunrise": {"method": "sunrise", "params": {}},
            "sof_zman_shma_gra": {"method": "proportional", "params": {"hours": 3.0, "base": "gra"}},
            "sof_zman_tfila_gra": {"method": "proportional", "params": {"hours": 4.0, "base": "gra"}},
            "chatzos": {"method": "midpoint", "params": {"start": "sunrise", "end": "sunset"}},
            "mincha_gedola": {"method": "proportional", "params": {"hours": 6.5, "base": "gra"}},
            "mincha_ketana": {"method": "proportional", "params": {"hours": 9.5, "base": "gra"}},
            "plag_hamincha": {"method": "proportional", "params": {"hours": 10.75, "base": "gra"}},
            "sunset": {"method": "sunset", "params": {}},
            "tzais": {"method": "solar_angle", "params": {"degrees": 8.5}},
            "tzeis_72": {"method": "fixed_minutes", "params": {"minutes": 72.0, "from": "sunset"}}
        }
    }'::jsonb,
    3,
    true
),
(
    'custom',
    'Custom',
    'Start with basic times and customize each zman according to your minhag.',
    '{
        "name": "Custom",
        "description": "Custom algorithm",
        "zmanim": {
            "sunrise": {"method": "sunrise", "params": {}},
            "chatzos": {"method": "midpoint", "params": {"start": "sunrise", "end": "sunset"}},
            "sunset": {"method": "sunset", "params": {}}
        }
    }'::jsonb,
    4,
    true
);
