-- Migration: Update algorithms table for algorithm editor
-- Story: 1.8 Algorithm Editor
-- Date: 2025-11-25

-- Add status column for draft/published/deprecated states
ALTER TABLE algorithms
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'draft';

-- Add check constraint for status values
ALTER TABLE algorithms
ADD CONSTRAINT algorithms_status_check
CHECK (status IN ('draft', 'published', 'deprecated'));

-- Add alias column 'config' pointing to formula_definition for backward compatibility
-- This allows code to use 'config' as per architecture spec while maintaining existing data
ALTER TABLE algorithms
ADD COLUMN IF NOT EXISTS config JSONB;

-- Copy existing formula_definition to config if config is null
UPDATE algorithms
SET config = formula_definition
WHERE config IS NULL AND formula_definition IS NOT NULL;

-- Create index for status to speed up queries for draft/published algorithms
CREATE INDEX IF NOT EXISTS idx_algorithms_status ON algorithms(status);

-- Create compound index for publisher + status (common query pattern)
CREATE INDEX IF NOT EXISTS idx_algorithms_publisher_status ON algorithms(publisher_id, status);

-- Add comment to clarify the status workflow
COMMENT ON COLUMN algorithms.status IS 'Algorithm lifecycle: draft (editable), published (active for users), deprecated (archived old version)';

-- Add comment to clarify config vs formula_definition
COMMENT ON COLUMN algorithms.config IS 'Algorithm configuration JSON (preferred field name per architecture spec)';
COMMENT ON COLUMN algorithms.formula_definition IS 'Legacy field, use config instead';
