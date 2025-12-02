-- Add logo_data column for storing base64 encoded logo images
-- This replaces the file-based logo_url approach

ALTER TABLE publishers ADD COLUMN IF NOT EXISTS logo_data TEXT;

-- Add comment for documentation
COMMENT ON COLUMN publishers.logo_data IS 'Base64 encoded logo image (PNG format, data:image/png;base64,...)';
