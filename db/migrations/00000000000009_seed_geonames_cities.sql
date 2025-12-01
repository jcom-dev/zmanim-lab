-- GeoNames Cities Database Import
-- This migration is a placeholder - actual city data is imported via the Go import tool
-- See: api/cmd/import-cities/main.go
--
-- The Go importer handles:
-- - Downloading GeoNames data from cities1000.zip
-- - Parsing TSV data with proper encoding
-- - Batch inserting 163,000+ cities with elevation and continent data
--
-- Run the importer with: go run cmd/import-cities/main.go
-- This runs automatically in CI after migrations complete.

-- No-op: Cities are imported via Go tool to handle large dataset efficiently
SELECT 1;
