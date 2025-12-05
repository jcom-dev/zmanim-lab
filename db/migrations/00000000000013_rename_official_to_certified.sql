-- Rename is_official to is_certified (better terminology)
-- "Source" column header with "Certified" vs "Community" badges

-- Rename the column
ALTER TABLE public.publishers
RENAME COLUMN is_official TO is_certified;

-- Update the comment
COMMENT ON COLUMN public.publishers.is_certified IS 'Whether this publisher is a certified/authoritative source for zmanim calculations. Non-certified publishers are community-contributed.';

-- Drop and recreate the index with new name
DROP INDEX IF EXISTS idx_publishers_is_official;
CREATE INDEX IF NOT EXISTS idx_publishers_is_certified ON public.publishers USING btree (is_certified);
