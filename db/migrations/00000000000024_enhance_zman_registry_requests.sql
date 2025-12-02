-- Migration: Enhance Zman Registry Requests for Epic 5 Workflow
-- Epic 5, Story 5.0: Database Schema for Publisher Aliases & Zman Requests
-- Date: 2025-12-02

-- Add new columns to zman_registry_requests for richer request data
ALTER TABLE zman_registry_requests
    ADD COLUMN IF NOT EXISTS transliteration TEXT,
    ADD COLUMN IF NOT EXISTS description TEXT,
    ADD COLUMN IF NOT EXISTS halachic_notes TEXT,
    ADD COLUMN IF NOT EXISTS halachic_source TEXT,
    ADD COLUMN IF NOT EXISTS publisher_email TEXT,
    ADD COLUMN IF NOT EXISTS publisher_name TEXT,
    ADD COLUMN IF NOT EXISTS auto_add_on_approval BOOLEAN DEFAULT true;

COMMENT ON COLUMN zman_registry_requests.transliteration IS 'Transliteration of the Hebrew name';
COMMENT ON COLUMN zman_registry_requests.description IS 'Brief description of the zman';
COMMENT ON COLUMN zman_registry_requests.halachic_notes IS 'Halachic context or notes';
COMMENT ON COLUMN zman_registry_requests.halachic_source IS 'Source references (seforim, poskim)';
COMMENT ON COLUMN zman_registry_requests.publisher_email IS 'Contact email for the requesting publisher';
COMMENT ON COLUMN zman_registry_requests.publisher_name IS 'Display name of the requesting publisher';
COMMENT ON COLUMN zman_registry_requests.auto_add_on_approval IS 'If true, automatically add this zman to publisher''s list when approved';

-- Zman Request Tags: Associate existing tags or request new tags with a zman request
-- Supports the "Request New Zman" workflow with guided tag selection
CREATE TABLE IF NOT EXISTS zman_request_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES zman_registry_requests(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES zman_tags(id) ON DELETE SET NULL,
    requested_tag_name TEXT,
    requested_tag_type TEXT CHECK (requested_tag_type IS NULL OR requested_tag_type IN ('event', 'timing', 'behavior', 'shita', 'method')),
    is_new_tag_request BOOLEAN DEFAULT false NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,

    -- Ensure either existing tag OR new tag request, never both/neither
    CONSTRAINT tag_reference_check CHECK (
        (tag_id IS NOT NULL AND requested_tag_name IS NULL AND is_new_tag_request = false) OR
        (tag_id IS NULL AND requested_tag_name IS NOT NULL AND is_new_tag_request = true)
    )
);

-- Indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_zman_request_tags_request ON zman_request_tags(request_id);
CREATE INDEX IF NOT EXISTS idx_zman_request_tags_tag ON zman_request_tags(tag_id) WHERE tag_id IS NOT NULL;

COMMENT ON TABLE zman_request_tags IS 'Tags associated with zman registry requests. Supports both existing tag references and new tag requests.';
COMMENT ON COLUMN zman_request_tags.tag_id IS 'Reference to existing tag (if using existing tag)';
COMMENT ON COLUMN zman_request_tags.requested_tag_name IS 'Name of requested new tag (if requesting new tag)';
COMMENT ON COLUMN zman_request_tags.requested_tag_type IS 'Type of requested new tag: event, timing, behavior, shita, method';
COMMENT ON COLUMN zman_request_tags.is_new_tag_request IS 'True if this is a request for a new tag to be created';
