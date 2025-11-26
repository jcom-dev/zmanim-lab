-- Update algorithms table for Story 1.8: Algorithm Editor
-- Adds configuration column (JSONB for algorithm DSL)
-- Renames validation_status to status for clarity

-- Add configuration column if not exists
ALTER TABLE algorithms ADD COLUMN IF NOT EXISTS configuration JSONB;

-- Update status check constraint to include draft/published/deprecated
ALTER TABLE algorithms DROP CONSTRAINT IF EXISTS algorithms_validation_status_check;
ALTER TABLE algorithms DROP CONSTRAINT IF EXISTS algorithms_status_check;

-- Rename validation_status to status if it exists and status doesn't
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'algorithms' AND column_name = 'validation_status')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'algorithms' AND column_name = 'status') THEN
        ALTER TABLE algorithms RENAME COLUMN validation_status TO status;
    END IF;
END $$;

-- Add status column if it still doesn't exist
ALTER TABLE algorithms ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'draft';

-- Add check constraint for status values
ALTER TABLE algorithms ADD CONSTRAINT algorithms_status_check
    CHECK (status IN ('draft', 'pending', 'published', 'deprecated'));

-- Create index on status for efficient queries
CREATE INDEX IF NOT EXISTS idx_algorithms_status ON algorithms(status);

-- Add default algorithm template data for each new publisher (via trigger)
-- Note: This is handled at application level when publisher is created
