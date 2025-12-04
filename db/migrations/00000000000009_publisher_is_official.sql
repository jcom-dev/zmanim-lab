-- Add is_official flag to publishers table
-- Distinguishes between official/authoritative publishers and community/unofficial ones

ALTER TABLE public.publishers
ADD COLUMN IF NOT EXISTS is_official boolean DEFAULT false NOT NULL;

COMMENT ON COLUMN public.publishers.is_official IS 'Whether this publisher is an official/authoritative source for zmanim calculations. Unofficial publishers are community-contributed.';

-- Add index for filtering by official status
CREATE INDEX IF NOT EXISTS idx_publishers_is_official ON public.publishers USING btree (is_official);
