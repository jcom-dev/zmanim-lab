-- Add missing country column to cities table (required by sqlc queries)

ALTER TABLE cities ADD COLUMN IF NOT EXISTS country TEXT;

-- Update existing cities with country names based on country_code
UPDATE cities SET country = CASE country_code
    WHEN 'US' THEN 'United States'
    WHEN 'IL' THEN 'Israel'
    WHEN 'GB' THEN 'United Kingdom'
    WHEN 'CA' THEN 'Canada'
    WHEN 'AU' THEN 'Australia'
    WHEN 'FR' THEN 'France'
    WHEN 'ZA' THEN 'South Africa'
    WHEN 'AR' THEN 'Argentina'
    WHEN 'MX' THEN 'Mexico'
    WHEN 'DE' THEN 'Germany'
    ELSE country_code
END WHERE country IS NULL;

-- Make country NOT NULL after populating
ALTER TABLE cities ALTER COLUMN country SET NOT NULL;
