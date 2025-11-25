# Story 1.5: Global Location System

Status: ready-for-dev

## Story

As a **user**,
I want **to find my location quickly**,
so that **I can see relevant zmanim publishers**.

## Acceptance Criteria

1. Location search returns autocomplete suggestions for cities
2. Search for "Brooklyn" shows "Brooklyn, New York, USA"
3. Search for "London" shows "London, Greater London, United Kingdom"
4. "Use My Location" resolves coordinates to nearest city
5. Global cities work with locale-appropriate region types

## Tasks / Subtasks

- [ ] Task 1: Create cities database table (AC: 1-5)
  - [ ] 1.1 Create migration for cities table
  - [ ] 1.2 Add indexes for search (name, country, region)
  - [ ] 1.3 Add spatial index for nearby queries
  - [ ] 1.4 Run migration in Supabase

- [ ] Task 2: Seed city database (AC: 2, 3, 5)
  - [ ] 2.1 Choose data source (GeoNames or SimpleMaps)
  - [ ] 2.2 Create scripts/seed-cities.sql or seed script
  - [ ] 2.3 Include major cities globally (target: 10,000+)
  - [ ] 2.4 Ensure region_type varies by country (state/county/province/district)
  - [ ] 2.5 Verify timezone data for all cities

- [ ] Task 3: Implement city search API (AC: 1, 2, 3)
  - [ ] 3.1 Create api/internal/handlers/cities.go
  - [ ] 3.2 GET /api/cities?search={query}
  - [ ] 3.3 Implement fuzzy search with ranking
  - [ ] 3.4 Return full hierarchy (city, region, country)
  - [ ] 3.5 Limit results to top 10

- [ ] Task 4: Implement reverse geocoding API (AC: 4)
  - [ ] 4.1 GET /api/cities/nearby?lat={lat}&lng={lng}
  - [ ] 4.2 Find nearest city using Haversine formula
  - [ ] 4.3 Return single closest city

- [ ] Task 5: Create LocationPicker component (AC: 1, 4)
  - [ ] 5.1 Create web/components/shared/LocationPicker.tsx
  - [ ] 5.2 Use shadcn/ui Command (combobox) for search
  - [ ] 5.3 Debounced search as user types
  - [ ] 5.4 Display results with full hierarchy

- [ ] Task 6: Implement geolocation button (AC: 4)
  - [ ] 6.1 "Use My Location" button in LocationPicker
  - [ ] 6.2 Request browser geolocation permission
  - [ ] 6.3 Call /api/cities/nearby with coordinates
  - [ ] 6.4 Handle permission denied gracefully

- [ ] Task 7: Store selected location (AC: all)
  - [ ] 7.1 Save last selected city to localStorage
  - [ ] 7.2 Restore on return visit
  - [ ] 7.3 Clear option available

## Dev Notes

### Architecture Patterns

- **Search:** PostgreSQL ILIKE with trigram index for fuzzy matching
- **Geolocation:** Browser Geolocation API + reverse geocode endpoint
- **State:** localStorage for persistence, no user accounts needed

### Database Schema

```sql
CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    country TEXT NOT NULL,
    region TEXT,
    region_type TEXT, -- state, county, province, district, prefecture
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    timezone TEXT NOT NULL,
    population INTEGER,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_cities_search ON cities USING gin(name gin_trgm_ops);
CREATE INDEX idx_cities_country ON cities(country);
```

### City Data Requirements

- Minimum 10,000 cities globally
- Coverage: US, Israel, UK, Canada, Australia, major cities worldwide
- Required fields: name, country, region, lat/lng, timezone
- Region types by country:
  - US: state
  - UK: county/region
  - Israel: district
  - Canada: province
  - Australia: state

### References

- [Source: docs/architecture.md#ADR-002-City-Based-Coverage]
- [Source: docs/epics.md#Story-1.5-Global-Location-System]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.5]
- [Source: docs/ux-design-specification.md#Location-Picker]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
