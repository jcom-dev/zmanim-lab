-- Add suspension_reason column to publishers table
-- Stores the reason why a publisher was suspended (for admin reference)

ALTER TABLE public.publishers
ADD COLUMN IF NOT EXISTS suspension_reason text;

COMMENT ON COLUMN public.publishers.suspension_reason IS 'The reason provided when this publisher was suspended. Cleared when reactivated.';
