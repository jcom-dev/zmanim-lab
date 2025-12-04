-- Add soft delete columns to publishers table
-- Allows restoring deleted publishers instead of permanently removing them

ALTER TABLE public.publishers
ADD COLUMN IF NOT EXISTS deleted_at timestamptz,
ADD COLUMN IF NOT EXISTS deleted_by text;

COMMENT ON COLUMN public.publishers.deleted_at IS 'Timestamp when the publisher was soft-deleted. NULL means active.';
COMMENT ON COLUMN public.publishers.deleted_by IS 'The admin user ID who performed the soft delete.';

-- Create index for efficient filtering of active vs deleted publishers
CREATE INDEX IF NOT EXISTS idx_publishers_deleted_at ON public.publishers(deleted_at) WHERE deleted_at IS NULL;
