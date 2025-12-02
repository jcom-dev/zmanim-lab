# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zmanim Lab is a multi-publisher platform for calculating Jewish prayer times (zmanim) using custom halachic algorithms. The system enables rabbinic authorities to publish their own calculation methods and geographic coverage, while end users can discover and consume accurate prayer times for their locations.

**Tech Stack:**
- **Backend:** Go 1.24+ with Chi router, pgx database driver, SQLc for type-safe queries
- **Frontend:** Next.js 16 with React 19, TypeScript, Tailwind CSS, shadcn/ui components
- **Database:** PostgreSQL (Xata) with PostGIS for geographic data
- **Auth:** Clerk for authentication and role-based access control
- **Cache:** Upstash Redis (24hr TTL for zmanim calculations)
- **Testing:** Playwright for E2E tests, Vitest for unit tests

## Development Commands

### Running Services

**In Coder environment (recommended):**
```bash
# Start both API and Web in tmux
./.coder/start-services.sh

# Restart all services
./restart.sh

# View logs / attach to tmux
tmux attach -t zmanim
# Ctrl+B then 0 -> API logs
# Ctrl+B then 1 -> Web logs
# Ctrl+B then D -> Detach

# Restart individual service
tmux send-keys -t zmanim:api C-c
tmux send-keys -t zmanim:api "go run cmd/api/main.go" Enter
```

**Local development:**
```bash
# Backend (runs on port 8080)
cd api
go run ./cmd/api

# Frontend (runs on port 3001)
cd web
npm run dev

# Both services must be running for full functionality
```

### Building & Testing

**Backend:**
```bash
cd api

# Build the API
go build ./cmd/api

# Run all tests
go test ./...

# Run tests for specific package
go test ./internal/handlers
go test ./internal/services

# Generate SQLc code after schema changes
go run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate
```

**Frontend:**
```bash
cd web

# Type check
npm run type-check

# Lint
npm run lint

# Run unit tests
npm test
npm run test:watch  # watch mode

# Build production bundle
npm run build
```

**E2E Tests:**
```bash
cd tests

# Install dependencies (first time only)
npm install
npx playwright install chromium

# Run all E2E tests (requires app running on localhost:3001)
npx playwright test

# Run with UI mode
npx playwright test --ui

# Run specific test file
npx playwright test homepage.spec.ts

# View test report
npx playwright show-report test-results/html-report
```

### Database Migrations

**Run migrations in Coder environment:**
```bash
# Use the migrate script (auto-detects environment)
./scripts/migrate.sh

# Migrations are tracked in schema_migrations table
# Already-applied migrations are skipped automatically
```

**After schema changes:**
```bash
# 1. Create migration file in db/migrations/
#    Format: YYYYMMDDHHMMSS_description.sql
#    Example: 20250101120000_add_user_preferences.sql

# 2. Run the migration
./scripts/migrate.sh

# 3. Regenerate SQLc queries
cd api
go run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate

# 4. Rebuild Go code
go build ./...
```

## Architecture Overview

### Monorepo Structure

```
zmanim-lab/
├── api/                    # Go backend (Chi router + SQLc)
│   ├── cmd/
│   │   ├── api/           # Main API server entry point
│   │   ├── seed-geo/      # Geographic data importer
│   │   └── migrate/       # Migration runner
│   ├── internal/
│   │   ├── handlers/      # HTTP request handlers (6-step pattern)
│   │   ├── services/      # Business logic layer
│   │   ├── middleware/    # Auth, CORS, logging
│   │   ├── db/
│   │   │   ├── queries/   # SQLc query definitions (*.sql)
│   │   │   └── sqlcgen/   # Generated type-safe Go code
│   │   ├── dsl/           # Zmanim formula DSL engine
│   │   ├── algorithm/     # Calculation engine
│   │   ├── cache/         # Redis caching layer
│   │   └── models/        # Shared data types
│   └── sqlc.yaml          # SQLc configuration
├── web/                    # Next.js frontend
│   ├── app/               # App Router pages
│   │   ├── admin/         # Admin dashboard
│   │   ├── publisher/     # Publisher management
│   │   └── zmanim/        # User-facing pages
│   ├── components/
│   │   ├── ui/            # shadcn/ui base components (don't modify)
│   │   ├── admin/         # Admin-specific components
│   │   ├── publisher/     # Publisher-specific components
│   │   └── shared/        # Shared components
│   ├── lib/
│   │   ├── api-client.ts  # Unified API client (useApi hook)
│   │   └── hooks/         # React Query factory hooks
│   ├── providers/         # React context providers
│   └── types/             # TypeScript type definitions
├── tests/                  # E2E tests (Playwright)
│   ├── e2e/               # Test specs
│   └── utils/             # Test helpers and fixtures
├── db/
│   └── migrations/        # Database schema migrations
├── docs/                   # Architecture and API documentation
└── scripts/               # Development scripts
```

### Backend Architecture

**Handler Pattern (6 Steps):**
All API handlers follow this consistent structure:

1. **Resolve publisher context** - Use `PublisherResolver.MustResolve()` to extract and validate publisher ID from X-Publisher-Id header
2. **Extract URL parameters** - Get path parameters using `chi.URLParam()`
3. **Parse request body** - Decode JSON for POST/PUT requests
4. **Validate inputs** - Check required fields and return 400 with details if invalid
5. **Execute business logic** - Use SQLc-generated queries or service layer methods
6. **Respond** - Use response helpers (`RespondJSON`, `RespondInternalError`, etc.)

**Key Backend Patterns:**
- **SQLc for database access:** All queries are in `api/internal/db/queries/*.sql` and compiled to type-safe Go code
- **PublisherResolver:** Handles X-Publisher-Id validation and multi-tenancy (replaces manual auth checks)
- **Service layer:** Business logic lives in `api/internal/services/`, not handlers
- **Structured logging:** Use `slog` with context fields, log at handler boundary
- **Response helpers:** Consistent error/success responses via `api/internal/handlers/response.go`

**Critical Backend Rules:**
- NEVER write raw SQL in handlers - use SQLc queries
- ALWAYS use `PublisherResolver.MustResolve()` for publisher endpoints
- ALWAYS log errors with context (user_id, publisher_id, etc.)
- NEVER expose internal errors to users (generic messages for 500s)

### Frontend Architecture

**Unified API Client:**
ALL API requests MUST use the `useApi()` hook from `web/lib/api-client.ts`:

```tsx
import { useApi } from '@/lib/api-client';

const api = useApi();
const data = await api.get('/publisher/profile');  // Auto-adds auth + X-Publisher-Id
await api.post('/endpoint', { body: JSON.stringify(data) });

// Public endpoints (no auth)
const countries = await api.public.get('/countries');

// Admin endpoints (auth but no X-Publisher-Id)
const stats = await api.admin.get('/admin/stats');
```

**React Query Hooks:**
For data fetching with caching, use factory hooks from `web/lib/hooks/`:

```tsx
import { usePublisherQuery, usePublisherMutation } from '@/lib/hooks';

// Query with automatic caching and publisher context
const { data, isLoading, error } = usePublisherQuery<ProfileData>(
  'publisher-profile',
  '/publisher/profile'
);

// Mutation with cache invalidation
const updateProfile = usePublisherMutation<Profile, UpdateRequest>(
  '/publisher/profile',
  'PUT',
  { invalidateKeys: ['publisher-profile'] }
);
```

**Authentication Patterns:**
- ALWAYS check `isLoaded` before accessing Clerk user data
- ALWAYS verify token exists before making authenticated requests
- Use `usePublisherContext()` for multi-publisher scenarios

**Critical Frontend Rules:**
- NEVER use raw `fetch()` - always use `useApi()` hook
- NEVER define `API_BASE` in components - it's in api-client.ts
- NEVER hardcode colors - use Tailwind design tokens (text-foreground, bg-primary, etc.)
- ALWAYS display times in 12-hour AM/PM format (never 24-hour)
- ALWAYS check `isLoaded` before accessing Clerk user/token

### Database Schema

**Core Tables:**
- `publishers` - Publisher profiles and verification status
- `publisher_algorithms` - Algorithm versions and DSL formulas
- `publisher_zmanim` - Published zman definitions (which calculations to show)
- `publisher_coverage` - Geographic coverage areas (countries, regions, continents)
- `cities` - GeoNames dataset (~163k cities with lat/long, PostGIS geometry)
- `zman_categories` - Category taxonomy (event_based, solar, seasonal, etc.)
- `master_registry` - Master list of all possible zmanim with metadata

**Key Relationships:**
- Publishers have many algorithms (versions)
- Publishers have many coverage areas
- Publishers publish many zmanim (publisher_zmanim)
- Each zman references a master_registry entry and links to other zmanim
- Cities use PostGIS for efficient geographic queries

**SQLc Integration:**
- Query definitions: `api/internal/db/queries/*.sql`
- Generated Go code: `api/internal/db/sqlcgen/`
- Regenerate after schema changes: `cd api && sqlc generate`

## Critical Coding Standards

### Backend Standards

**Handler Structure:**
```go
func (h *Handlers) HandlerName(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // Step 1: Resolve publisher context
    pc := h.publisherResolver.MustResolve(w, r)
    if pc == nil {
        return // Response already sent
    }

    // Step 2: Extract URL params
    id := chi.URLParam(r, "id")

    // Step 3: Parse request body (POST/PUT)
    var req RequestType
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondBadRequest(w, r, "Invalid request body")
        return
    }

    // Step 4: Validate inputs
    if req.Field == "" {
        RespondValidationError(w, r, "Field is required", nil)
        return
    }

    // Step 5: Use SQLc queries
    result, err := h.db.Queries.GetSomething(ctx, sqlcgen.GetSomethingParams{
        PublisherID: pc.PublisherID,
    })
    if err != nil {
        slog.Error("operation failed", "error", err, "publisher_id", pc.PublisherID)
        RespondInternalError(w, r, "Failed to process request")
        return
    }

    // Step 6: Respond
    RespondJSON(w, r, http.StatusOK, result)
}
```

**Error Handling:**
```go
// Wrap errors with context
if err != nil {
    return nil, fmt.Errorf("failed to fetch publisher: %w", err)
}

// Log at handler boundary with context
slog.Error("operation failed", "error", err, "user_id", userID, "publisher_id", publisherID)

// User-friendly messages (never expose internals)
RespondInternalError(w, r, "Failed to process request")
```

**Response Format:**
All responses are wrapped by `RespondJSON()`:
```json
{
  "data": <your_data>,
  "meta": {
    "timestamp": "2025-11-27T10:30:00Z",
    "request_id": "uuid"
  }
}
```

NEVER double-wrap - pass data directly to `RespondJSON()`.

### Frontend Standards

**Component Structure:**
```tsx
'use client';

import { useState, useEffect, useCallback } from 'react';
import { useUser, useAuth } from '@clerk/nextjs';
import { useApi } from '@/lib/api-client';

export function ComponentName() {
  // 1. Hooks first
  const { user, isLoaded } = useUser();
  const api = useApi();
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // 2. Callbacks
  const fetchData = useCallback(async () => {
    try {
      const result = await api.get('/endpoint');
      setData(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, [api]);

  // 3. Effects
  useEffect(() => {
    if (isLoaded) fetchData();
  }, [isLoaded, fetchData]);

  // 4. Loading state
  if (!isLoaded || isLoading) {
    return <LoadingSpinner />;
  }

  // 5. Error state
  if (error) {
    return <ErrorMessage message={error} />;
  }

  // 6. Main render
  return <div>{/* content */}</div>;
}
```

**Styling with Tailwind:**
- Use design tokens: `text-foreground`, `bg-primary`, `border-border`
- Never use arbitrary values: `text-[#hex]` is FORBIDDEN
- Responsive: `md:grid-cols-2`, `lg:p-8`

**Time Formatting:**
```tsx
import { formatTime } from '@/lib/utils';

// REQUIRED - 12-hour AM/PM format
formatTime('14:30:36')  // "2:30:36 PM"

// FORBIDDEN - 24-hour format
<span>14:30:36</span>  // Wrong!
```

### Testing Standards

**E2E Test Pattern:**
```typescript
import { test, expect } from '@playwright/test';
import { loginAsPublisher, getSharedPublisher, BASE_URL } from '../utils';

// REQUIRED: Enable parallel mode
test.describe.configure({ mode: 'parallel' });

test.describe('Feature Name', () => {
  test('should do something', async ({ page }) => {
    // Use pre-created shared publishers (NO data creation in tests)
    const publisher = getSharedPublisher('verified-1');
    await loginAsPublisher(page, publisher.id);

    await page.goto(`${BASE_URL}/publisher/dashboard`);
    await page.waitForLoadState('networkidle');

    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});
```

**Test Data:**
- Use shared fixtures from `tests/e2e/utils/shared-fixtures.ts`
- Types: `verified-1` through `verified-5`, `with-algorithm-1`, `with-coverage`, `pending`, `suspended`
- NEVER create/delete data in individual tests (breaks parallelism)
- Test names must have `TEST_` prefix if creating data

## Multi-Publisher System

**Publisher Context:**
The system supports multiple publishers per user and admin impersonation.

```tsx
// Access current publisher context
import { usePublisherContext } from '@/providers/PublisherContext';

const {
  selectedPublisher,       // Current publisher (or impersonated)
  publishers,              // All accessible publishers
  setSelectedPublisherId,  // Switch publisher
  isImpersonating,         // Admin impersonation mode
} = usePublisherContext();
```

**Backend Publisher Resolution:**
```go
// Handles X-Publisher-Id validation and multi-tenancy
pc := h.publisherResolver.MustResolve(w, r)
if pc == nil {
    return // Error response already sent
}
publisherID := pc.PublisherID
```

**Header Requirements:**
- `Authorization: Bearer <token>` - Required for all protected endpoints
- `X-Publisher-Id: <uuid>` - Required for publisher-scoped endpoints
- The API client (`useApi()`) handles these automatically

## Zmanim Calculation System

**DSL (Domain-Specific Language):**
Publishers define formulas using a JSON-based DSL in `api/internal/dsl/`. The engine supports:
- Solar calculations (sunrise, sunset, twilight angles)
- Time arithmetic (add/subtract minutes)
- Fixed times
- Conditional logic based on seasons/dates
- References to other zmanim (linked calculations)

**Calculation Flow:**
1. User requests zmanim for a location + date
2. System finds publishers with coverage for that location (PostGIS queries)
3. For each publisher, fetch their algorithm and published zmanim
4. Execute DSL formulas for each zman
5. Cache results in Redis (24hr TTL)
6. Return formatted times to user

**Formula Storage:**
- Master registry: `master_registry` table (all possible zmanim)
- Publisher algorithms: `publisher_algorithms` table (DSL formulas)
- Published zmanim: `publisher_zmanim` table (which zmanim to show)
- Zman relationships: `linked_zmanim` field for calculations that depend on others

## Common Pitfalls & Solutions

### Backend

**Problem:** Manual publisher ID extraction is verbose and error-prone
**Solution:** Use `PublisherResolver.MustResolve()` - handles all edge cases

**Problem:** Raw SQL in handlers causes type safety issues
**Solution:** Define queries in `api/internal/db/queries/*.sql` and use SQLc

**Problem:** Errors expose internal details to users
**Solution:** Log detailed errors with slog, return generic user messages

### Frontend

**Problem:** 401 errors due to missing/null auth token
**Solution:** Always check `isLoaded` and verify token before API calls

**Problem:** Inconsistent API response handling (`data.data?.publishers || data.publishers`)
**Solution:** Use `useApi()` hook - it unwraps responses automatically

**Problem:** Design inconsistencies due to hardcoded colors
**Solution:** Use Tailwind design tokens exclusively

**Problem:** Times showing in 24-hour format
**Solution:** Use `formatTime()` utility for all time displays

### Testing

**Problem:** Tests fail when run in parallel due to data conflicts
**Solution:** Use shared fixtures - never create/delete data in individual tests

**Problem:** Flaky tests due to timing issues
**Solution:** Always use `page.waitForLoadState('networkidle')` before assertions

## Documentation References

See `docs/` directory for comprehensive documentation:
- `docs/ARCHITECTURE.md` - System architecture deep dive
- `docs/coding-standards.md` - Complete coding standards (source of truth)
- `docs/api-reference.md` - REST API documentation
- `docs/data-models.md` - Database schema details
- `tests/TESTING.md` - E2E testing guide

## Service URLs (Coder Environment)

| Service | Port | URL |
|---------|------|-----|
| Web App | 3001 | http://localhost:3001 |
| Go API  | 8080 | http://localhost:8080 |
| PostgreSQL | 5432 | postgres:5432 (internal Docker network) |

**Health checks:**
```bash
curl http://localhost:8080/health   # API
curl http://localhost:3001          # Web
```

## Key Insights for AI Agents

1. **Always use established patterns**: This codebase has strong conventions (6-step handlers, useApi hook, SQLc queries). Follow them exactly.

2. **Never skip type safety**: SQLc provides compile-time type checking for database queries. Regenerate after schema changes.

3. **Multi-tenancy is built-in**: The X-Publisher-Id header and PublisherResolver handle tenant isolation. Use them correctly.

4. **Auth is complex**: Clerk integration requires careful `isLoaded` checks and token validation. The `useApi()` hook handles this.

5. **Tests must be parallel-safe**: Use shared fixtures, never create/delete data in individual tests. This is critical for CI/CD speed.

6. **API responses are standardized**: All responses are wrapped by `RespondJSON()`. Never double-wrap data.

7. **The DSL is central**: The zmanim calculation engine is formula-driven. Changes to calculations happen via DSL updates, not code changes.

8. **Geographic data is specialized**: PostGIS enables efficient location queries. The cities table has ~163k entries with geometry columns.

9. **Caching is time-based**: Redis caches zmanim calculations with 24hr TTL. Cache invalidation happens automatically.

10. **The coding standards document is authoritative**: `docs/coding-standards.md` contains the complete ruleset. When in doubt, check there first.
