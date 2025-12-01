-- Migration: Additional city seeding (superseded by migration 00000000000009)
-- This migration originally seeded more cities but is now replaced by the comprehensive
-- GeoNames import in migration 00000000000009_seed_geonames_cities.sql
-- which includes 163,000+ cities with elevation and continent data.
-- Keeping this file for migration history consistency.

-- No-op: All city data is now handled by migration 00000000000009
SELECT 1;
