-- Migration: Cleanup Invitations
-- Part of unified user management refactor
-- Removes all pending invitations as we now use direct user creation

-- Delete all publisher invitations
DELETE FROM publisher_invitations;

-- Add a comment explaining the change
COMMENT ON TABLE publisher_invitations IS 'DEPRECATED: This table is no longer used. User management now creates users directly via Clerk instead of using invitations. Table kept for historical reference but will be empty.';
