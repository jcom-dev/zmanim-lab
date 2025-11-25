-- Migration: Update publishers table for admin management
-- Story: 1.3 Admin Publisher Management
-- Date: 2025-11-25

-- Add missing columns to publishers table
ALTER TABLE publishers
ADD COLUMN IF NOT EXISTS clerk_user_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS bio TEXT;

-- Update status column to use the new status values
-- Note: The existing status column has different values, so we'll add a constraint
ALTER TABLE publishers DROP CONSTRAINT IF EXISTS publishers_status_check;
ALTER TABLE publishers
ADD CONSTRAINT publishers_status_check
CHECK (status IN ('pending', 'verified', 'suspended', 'pending_verification', 'active', 'retired'));

-- Create index for clerk_user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_publishers_clerk_user ON publishers(clerk_user_id);

-- Update the status column default to match story requirements
ALTER TABLE publishers ALTER COLUMN status SET DEFAULT 'pending';

-- Add comment to clarify status values
COMMENT ON COLUMN publishers.status IS 'Publisher status: pending (newly created), verified (approved by admin), suspended (deactivated), or legacy values (pending_verification, active, retired)';
