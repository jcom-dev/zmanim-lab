# Story 1.6: Publisher Coverage

Status: ready-for-dev

## Story

As a **publisher**,
I want **to define my geographic coverage areas**,
so that **users in those locations can find me**.

## Acceptance Criteria

1. Publisher sees current coverage areas on map
2. Publisher can add coverage at country, region, or city level
3. Selecting country includes all cities in that country
4. Selecting region includes all cities in that region
5. Publisher can set priority (1-10) per coverage area
6. Publisher can toggle coverage areas active/inactive

## Tasks / Subtasks

- [ ] Task 1: Create coverage database tables (AC: 2-6)
  - [ ] 1.1 Create migration for publisher_cities table
  - [ ] 1.2 Create migration for publisher_coverage table
  - [ ] 1.3 Add indexes for publisher_id and city_id
  - [ ] 1.4 Run migrations in Supabase

- [ ] Task 2: Implement coverage API (AC: 2-6)
  - [ ] 2.1 Create api/internal/handlers/coverage.go
  - [ ] 2.2 GET /api/publisher/coverage - list own coverage
  - [ ] 2.3 POST /api/publisher/coverage - add coverage area
  - [ ] 2.4 PUT /api/publisher/coverage/{id} - update priority/active
  - [ ] 2.5 DELETE /api/publisher/coverage/{id} - remove coverage

- [ ] Task 3: Implement coverage expansion logic (AC: 3, 4)
  - [ ] 3.1 When adding country coverage, mark all cities
  - [ ] 3.2 When adding region coverage, mark region cities
  - [ ] 3.3 When adding city coverage, mark single city
  - [ ] 3.4 Handle overlapping coverage gracefully

- [ ] Task 4: Create coverage management page (AC: 1, 5, 6)
  - [ ] 4.1 Create web/app/publisher/coverage/page.tsx
  - [ ] 4.2 Display current coverage in list form
  - [ ] 4.3 Priority slider/input (1-10)
  - [ ] 4.4 Active toggle switch
  - [ ] 4.5 Delete button with confirmation

- [ ] Task 5: Create coverage map visualization (AC: 1)
  - [ ] 5.1 Install Leaflet or Mapbox library
  - [ ] 5.2 Create web/components/publisher/CoverageMap.tsx
  - [ ] 5.3 Display selected coverage areas
  - [ ] 5.4 Highlight countries/regions/cities

- [ ] Task 6: Create CitySelector component (AC: 2-4)
  - [ ] 6.1 Create web/components/publisher/CitySelector.tsx
  - [ ] 6.2 Level selector: Country / Region / City
  - [ ] 6.3 Cascading dropdowns for selection
  - [ ] 6.4 Search within each level

- [ ] Task 7: Implement publisher lookup by city (AC: all)
  - [ ] 7.1 GET /api/cities/{cityId}/publishers
  - [ ] 7.2 Query publisher_cities + publisher_coverage
  - [ ] 7.3 Return publishers sorted by priority
  - [ ] 7.4 Filter to active coverage only

## Dev Notes

### Architecture Patterns

- **Multi-level Coverage:** Country → Region → City hierarchy
- **Priority System:** Higher priority appears first in user searches
- **Join Tables:** publisher_cities for direct, publisher_coverage for hierarchical

### Database Schema

```sql
CREATE TABLE publisher_cities (
    publisher_id UUID REFERENCES publishers(id) ON DELETE CASCADE,
    city_id UUID REFERENCES cities(id) ON DELETE CASCADE,
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (publisher_id, city_id)
);

CREATE TABLE publisher_coverage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id UUID REFERENCES publishers(id) ON DELETE CASCADE,
    level TEXT NOT NULL, -- country, region, city
    geo_value TEXT NOT NULL, -- country code, region name, or city_id
    priority INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### Coverage Resolution

1. Check publisher_cities for direct city match
2. Check publisher_coverage for region match
3. Check publisher_coverage for country match
4. Use highest priority match

### References

- [Source: docs/architecture.md#ADR-002-City-Based-Coverage]
- [Source: docs/epics.md#Story-1.6-Publisher-Coverage]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.6]
- [Source: docs/prd.md#FR16-FR20]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
