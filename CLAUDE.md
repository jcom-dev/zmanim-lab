# CLAUDE.md

## ⚠️ MANDATORY: Read `docs/coding-standards.md` before ANY task

---

## What is Zmanim Lab?

Multi-publisher platform for Jewish prayer times (zmanim). Rabbinic authorities ("publishers") define calculation formulas; users get times for their location.

**Core flow:** User selects city → System finds publishers covering that area → Executes DSL formulas → Returns calculated times

## Tech Stack

| Layer | Stack |
|-------|-------|
| Backend | Go 1.24+, Chi router, pgx, SQLc |
| Frontend | Next.js 16, React 19, Tailwind, shadcn/ui |
| Database | PostgreSQL + PostGIS (geographic queries) |
| Auth | Clerk (roles: admin, publisher, user) |
| Cache | Redis (24hr TTL for calculations) |

## Domain Concepts

**Publisher** - Rabbinic authority who publishes zmanim (e.g., "OU", "Chabad")
**Zman** (pl. zmanim) - A Jewish prayer time (e.g., sunrise, candle lighting)
**Master Registry** - Canonical list of all possible zmanim with default formulas
**Publisher Zman** - Publisher's version of a zman (MUST link to master_registry or another publisher_zman)
**DSL Formula** - Text formula like `sunrise + 72min` or `solar(-16.1)`
**Coverage** - Geographic areas a publisher serves (city/region/country level)

## DSL Formula Syntax

```
sunrise                      # Primitive (sunrise, sunset, noon, midnight)
solar(-16.1)                 # Solar angle (degrees below horizon)
sunrise + 72min              # Time arithmetic
sunset - 18min
proportional_hours(3)        # Shaos zmaniyos (halachic hours)
@alos_hashachar + 30min      # Reference another zman
midpoint(@sunrise, @sunset)  # Midpoint between two times
```

## Key Tables

```
publishers              → Publisher profiles (status: pending/active/suspended)
master_zmanim_registry  → Canonical zman definitions
publisher_zmanim        → Publisher's zmanim (MUST have master_zman_id OR linked_publisher_zman_id)
publisher_coverage      → Geographic coverage (city_id, country_code, region)
cities                  → ~163k cities with PostGIS geometry
```

## Structure

```
api/
├── cmd/api/              # Entry point
├── internal/
│   ├── handlers/         # HTTP handlers (6-step pattern)
│   ├── services/         # Business logic
│   ├── db/queries/       # SQLc SQL files
│   ├── db/sqlcgen/       # Generated Go code
│   ├── dsl/              # Formula parser/executor
│   └── astro/            # Solar calculations

web/
├── app/                  # Next.js pages
│   ├── admin/            # Admin dashboard
│   ├── publisher/        # Publisher management (algorithm, coverage, profile)
│   └── zmanim/           # Public zmanim display
├── components/           # ui/ (shadcn), admin/, publisher/, shared/
├── lib/api-client.ts     # Unified API client (useApi hook)
└── lib/hooks/            # React Query hooks
```

## Commands

```bash
./restart.sh                    # Start/restart ALL services (ALWAYS use this)
./scripts/migrate.sh            # Run migrations
cd api && sqlc generate         # After schema changes
cd api && go test ./...         # Backend tests
cd web && npm run type-check    # Frontend type check
cd tests && npx playwright test # E2E tests
```

## Key Patterns

**Backend handler (6 steps):**
```go
pc := h.publisherResolver.MustResolve(w, r)  // 1. Resolve publisher context
id := chi.URLParam(r, "id")                   // 2. URL params
json.NewDecoder(r.Body).Decode(&req)          // 3. Parse body
// validate                                    // 4. Validate
result, err := h.db.Queries.X(ctx, params)    // 5. SQLc query (no raw SQL)
RespondJSON(w, r, http.StatusOK, result)      // 6. Respond
```

**Frontend API:**
```tsx
const api = useApi();
await api.get('/endpoint');           // Auth + X-Publisher-Id header
await api.public.get('/countries');   // No auth
await api.admin.get('/admin/stats');  // Auth only (no X-Publisher-Id)
```

## URLs

| Service | URL |
|---------|-----|
| Web | http://localhost:3001 |
| API | http://localhost:8080 |
| Swagger UI | http://localhost:8080/swagger/index.html |
| OpenAPI JSON | http://localhost:8080/swagger/doc.json |
