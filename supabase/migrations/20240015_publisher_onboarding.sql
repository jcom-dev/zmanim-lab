-- Migration: Publisher Onboarding State for Story 4-11
-- Tracks onboarding wizard progress for new publishers

CREATE TABLE IF NOT EXISTS publisher_onboarding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID NOT NULL REFERENCES publishers(id) ON DELETE CASCADE,
    current_step INT DEFAULT 0,
    completed_steps INT[] DEFAULT '{}',
    wizard_data JSONB DEFAULT '{}',
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    skipped BOOLEAN DEFAULT false,

    UNIQUE(publisher_id)
);

-- Index for efficient lookup
CREATE INDEX IF NOT EXISTS idx_onboarding_publisher
ON publisher_onboarding(publisher_id);

-- Comments
COMMENT ON TABLE publisher_onboarding IS 'Tracks onboarding wizard state for publishers';
COMMENT ON COLUMN publisher_onboarding.wizard_data IS 'JSON data containing template selection, customizations, and coverage';
COMMENT ON COLUMN publisher_onboarding.skipped IS 'True if publisher skipped the wizard';
