-- NO-OP: event_category has been replaced by the tag-based system
-- See migration 00000000000014_zman_tags.sql for the new tag system
-- This migration previously populated event_category but that column no longer exists
SELECT 1;
