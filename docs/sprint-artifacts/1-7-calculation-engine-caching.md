# Story 1.7: Calculation Engine & Caching

Status: ready-for-dev

## Story

As the **system**,
I want **to calculate accurate zmanim times**,
so that **users receive correct prayer times based on publisher algorithms**.

## Acceptance Criteria

1. System calculates all standard zmanim for given location/date
2. Solar angle method calculates time when sun is N degrees below horizon
3. Fixed minutes method calculates time N minutes from sunrise/sunset
4. Proportional method calculates shaos zmaniyos (GRA or MGA base)
5. Formula details are included in response for each zman
6. Same calculation within 24hrs returns cached result (<100ms)
7. Algorithm publish invalidates publisher's cached calculations
8. Cache miss triggers calculation, caches result with 24hr TTL

## Tasks / Subtasks

- [ ] Task 1: Create astronomy calculation package (AC: 1, 2, 3)
  - [ ] 1.1 Create api/internal/astro/sun.go
  - [ ] 1.2 Implement sunrise/sunset using NOAA algorithms
  - [ ] 1.3 Create api/internal/astro/angles.go
  - [ ] 1.4 Implement solar depression angle calculations
  - [ ] 1.5 Create api/internal/astro/times.go
  - [ ] 1.6 Implement time arithmetic helpers

- [ ] Task 2: Create algorithm parser (AC: 1, 5)
  - [ ] 2.1 Create api/internal/services/algorithm/parser.go
  - [ ] 2.2 Parse JSON DSL to Algorithm struct
  - [ ] 2.3 Validate algorithm configuration
  - [ ] 2.4 Extract formula metadata for each zman

- [ ] Task 3: Create algorithm executor (AC: 1-4)
  - [ ] 3.1 Create api/internal/services/algorithm/executor.go
  - [ ] 3.2 Implement solar_angle method
  - [ ] 3.3 Implement fixed_minutes method
  - [ ] 3.4 Implement proportional method (GRA base)
  - [ ] 3.5 Implement proportional method (MGA base)
  - [ ] 3.6 Implement sunrise/sunset base methods
  - [ ] 3.7 Implement midpoint calculation (chatzos)

- [ ] Task 4: Create cache service (AC: 6-8)
  - [ ] 4.1 Create api/internal/services/cache_service.go
  - [ ] 4.2 Implement Upstash Redis REST client
  - [ ] 4.3 Get with key format zmanim:{publisher}:{city}:{date}
  - [ ] 4.4 Set with 24hr TTL
  - [ ] 4.5 Implement InvalidatePublisher (pattern delete)
  - [ ] 4.6 Handle cache unavailable gracefully

- [ ] Task 5: Create zmanim service (AC: 1, 5-8)
  - [ ] 5.1 Create api/internal/services/zmanim_service.go
  - [ ] 5.2 Orchestrate: check cache → calculate → store
  - [ ] 5.3 Include formula details in response
  - [ ] 5.4 Handle missing algorithm (default/error)

- [ ] Task 6: Create zmanim API endpoint (AC: all)
  - [ ] 6.1 Add handler in api/internal/handlers/zmanim.go
  - [ ] 6.2 GET /api/zmanim?cityId={}&publisherId={}&date={}
  - [ ] 6.3 Validate parameters
  - [ ] 6.4 Return zmanim list with formula details

- [ ] Task 7: Write calculation tests (AC: 1-4)
  - [ ] 7.1 Table-driven tests against known values
  - [ ] 7.2 Test each calculation method
  - [ ] 7.3 Compare with MyZmanim/Chabad.org references
  - [ ] 7.4 Test edge cases (Arctic, DST transitions)

- [ ] Task 8: Write cache tests (AC: 6-8)
  - [ ] 8.1 Test cache hit scenario
  - [ ] 8.2 Test cache miss scenario
  - [ ] 8.3 Test invalidation
  - [ ] 8.4 Test cache unavailable fallback

## Dev Notes

### Architecture Patterns

- **Calculation Engine:** Pure Go implementation in api/internal/astro/
- **Algorithm DSL:** JSON format parsed to executable config
- **Caching:** Upstash Redis REST API with 24hr TTL
- **Cache Key:** `zmanim:{publisher_id}:{city_id}:{date}`

### Algorithm DSL Format

```json
{
  "name": "Custom Algorithm",
  "zmanim": {
    "alos": {"method": "solar_angle", "params": {"degrees": 16.1}},
    "sunrise": {"method": "sunrise", "params": {}},
    "sof_zman_shma": {"method": "proportional", "params": {"hours": 3, "base": "gra"}},
    "sunset": {"method": "sunset", "params": {}},
    "tzeis": {"method": "fixed_minutes", "params": {"minutes": 72, "from": "sunset"}}
  }
}
```

### Calculation Methods

| Method | Description | Parameters |
|--------|-------------|------------|
| sunrise | Sunrise time | - |
| sunset | Sunset time | - |
| solar_angle | Sun N° below horizon | degrees |
| fixed_minutes | N minutes from base | minutes, from |
| proportional | Shaos zmaniyos | hours, base (gra/mga) |
| midpoint | Midpoint of two times | start, end |

### Response Format

```json
{
  "data": {
    "date": "2025-11-25",
    "timezone": "America/New_York",
    "zmanim": [
      {
        "name": "Alos HaShachar",
        "time": "05:23:00",
        "formula": {
          "method": "solar_angle",
          "display_name": "Solar Depression Angle",
          "parameters": {"degrees": 16.1},
          "explanation": "Dawn when sun is 16.1° below horizon"
        }
      }
    ]
  }
}
```

### References

- [Source: docs/architecture.md#ADR-001-Custom-Calculation-Engine]
- [Source: docs/architecture.md#ADR-003-Upstash-Redis-Caching]
- [Source: docs/epics.md#Story-1.7-Calculation-Engine-Caching]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.7]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
