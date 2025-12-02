-- Migration: Remove deprecated justification column
-- The 'justification' column is replaced by 'description' which was added in migration 24
-- Date: 2025-12-02

-- Drop the justification column from zman_registry_requests
ALTER TABLE zman_registry_requests DROP COLUMN IF EXISTS justification;
