# Coding Standards - Zmanim Lab

**Status:** CAST-IRON RULES - Violations block PRs
**Audience:** AI agents and developers

---

## CRITICAL VIOLATIONS (PR Blockers)

### 1. Hardcoded Colors
```tsx
// FORBIDDEN
className="text-[#1e3a5f]" | className="bg-[#0051D5]" | style={{ color: '#ff0000' }}

// REQUIRED - design tokens
className="text-primary" | className="bg-primary/90" | className="text-muted-foreground"
```

### 2. Raw fetch() / API_BASE in Components
```tsx
// FORBIDDEN
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
const response = await fetch(`${API_BASE}/api/v1/endpoint`, { headers: {...} });

// REQUIRED - unified API client
import { useApi } from '@/lib/api-client';
const api = useApi();
await api.get<DataType>('/publisher/profile');      // Auth + X-Publisher-Id automatic
await api.public.get('/countries');                  // No auth
await api.admin.get('/admin/stats');                 // Auth, no X-Publisher-Id
```

### 3. React Query Pattern
```tsx
import { usePublisherQuery, usePublisherMutation } from '@/lib/hooks';
const { data, isLoading, error } = usePublisherQuery<ProfileData>('publisher-profile', '/publisher/profile');
const mutation = usePublisherMutation<Profile, UpdateRequest>('/publisher/profile', 'PUT', { invalidateKeys: ['publisher-profile'] });
```

### 4. Clerk Auth - MUST check isLoaded first
```tsx
const { isLoaded, isSignedIn, user } = useUser();
if (!isLoaded) return <LoadingSpinner />;
if (!isSignedIn) redirect('/sign-in');
// NOW safe to access user/token
```

**Common 401 causes:** Token null before isLoaded=true | Missing X-Publisher-Id header | Bearer null/undefined

---

## Clean Code Policy - ZERO TOLERANCE

**FORBIDDEN patterns - delete, don't mark:**
- `@deprecated` annotations
- `// Legacy`, `// Backward compat`, `// TODO: remove`, `// FIXME` comments
- Fallback logic for old formats
- Dual-format support (`status == 'verified' || status == 'active'`)
- Re-exports "for compatibility"

**Rule:** One format only. Migrate data, update code, delete old code.

---

## Frontend Standards

### File Structure
```
web/
├── app/                    # Next.js App Router (admin/, publisher/, zmanim/)
├── components/
│   ├── ui/                # shadcn/ui (don't modify)
│   ├── admin/ | publisher/ | shared/ | zmanim/
├── lib/
│   ├── api-client.ts      # Unified API client
│   └── hooks/             # React Query factory hooks
├── providers/             # PublisherContext, QueryProvider
└── types/
```

### Component Pattern
```tsx
'use client';
// 1. React/framework → 2. Third-party → 3. Internal → 4. Types
import { useState, useEffect, useCallback } from 'react';
import { useUser } from '@clerk/nextjs';
import { useApi } from '@/lib/api-client';

export function Component() {
  // 1. Hooks (Clerk, context, state)
  const { user, isLoaded } = useUser();
  const api = useApi();
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  // 2. Callbacks
  const fetchData = useCallback(async () => {
    try {
      setData(await api.get('/endpoint'));
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }, [api]);

  // 3. Effects
  useEffect(() => { if (isLoaded) fetchData(); }, [isLoaded, fetchData]);

  // 4. Early returns: Loading → Error → Content
  if (!isLoaded || isLoading) return <Loader2 className="animate-spin" />;
  if (error) return <div className="text-destructive">{error}</div>;
  return <div>{/* content */}</div>;
}
```

### Client vs Server Components
| Client (`'use client'`) | Server (default) |
|------------------------|------------------|
| React hooks, Clerk hooks, event handlers, browser APIs | Static content, server data fetching, SEO-critical |

### Clerk Metadata
```tsx
interface ClerkPublicMetadata {
  role?: 'admin' | 'publisher' | 'user';
  publisher_access_list?: string[];
  primary_publisher_id?: string;
}
const metadata = user.publicMetadata as ClerkPublicMetadata;
```

### PublisherContext
```tsx
const { selectedPublisher, publishers, setSelectedPublisherId, isImpersonating } = usePublisherContext();
```

### Design Tokens (MANDATORY)

**Semantic tokens (use first):**
| Token | Usage |
|-------|-------|
| `foreground` / `background` | Primary text / page bg |
| `card` / `card-foreground` | Card bg / text |
| `primary` / `primary-foreground` | CTAs, links / text on primary |
| `muted` / `muted-foreground` | Disabled bg / secondary text |
| `destructive` | Errors, delete |
| `border` / `input` / `ring` | Borders / form inputs / focus |

**Correct:**
```tsx
className="text-foreground bg-card border-border text-muted-foreground bg-primary/90"
```

**Forbidden:**
```tsx
className="text-[#111827]" | className="bg-white" | style={{ color: '#ff0000' }}
```

**Exceptions (require dark: variant):**
- Status: `text-green-600 dark:text-green-400`
- Syntax highlighting: `text-blue-600 dark:text-blue-400`

**Status badges:** `status-badge-success` | `status-badge-warning` | `status-badge-error`
**Alerts:** `alert-warning` | `alert-error` | `alert-success` | `alert-info`

### Time Formatting - 12-hour ONLY
```tsx
import { formatTime, formatTimeShort } from '@/lib/utils';
formatTime('14:30:36')      // "2:30:36 PM"
formatTimeShort('14:30:36') // "2:30 PM"
// FORBIDDEN: <span>14:30:36</span>
```

### Icons - Lucide React only
```tsx
import { Settings, Loader2 } from 'lucide-react';
<Icon className="w-4 h-4" />  // Small
<Icon className="w-5 h-5" />  // Medium
<Icon className="w-8 h-8" />  // Large
```

---

## Backend Standards

### Handler Pattern (6 Steps)
```go
func (h *Handlers) HandlerName(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // 1. Resolve publisher context
    pc := h.publisherResolver.MustResolve(w, r)
    if pc == nil { return }
    publisherID := pc.PublisherID

    // 2. Extract URL params
    id := chi.URLParam(r, "id")
    if id == "" { RespondValidationError(w, r, "ID required", nil); return }

    // 3. Parse body (POST/PUT)
    var req struct { Name string `json:"name"` }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondBadRequest(w, r, "Invalid request body"); return
    }

    // 4. Validate
    if req.Name == "" { RespondValidationError(w, r, "Validation failed", map[string]string{"name": "required"}); return }

    // 5. SQLc query
    result, err := h.db.Queries.GetSomething(ctx, sqlcgen.GetSomethingParams{PublisherID: publisherID})
    if err != nil {
        slog.Error("operation failed", "error", err, "id", id)
        RespondInternalError(w, r, "Failed to process request"); return
    }

    // 6. Respond
    RespondJSON(w, r, http.StatusOK, result)
}
```

### PublisherResolver (REQUIRED for publisher endpoints)
```go
// FORBIDDEN - manual extraction
userID := middleware.GetUserID(ctx)
publisherID := r.Header.Get("X-Publisher-Id")

// REQUIRED
pc := h.publisherResolver.MustResolve(w, r)  // Returns nil + sends error if fails
pc, err := h.publisherResolver.Resolve(ctx, r)  // Custom error handling
pc := h.publisherResolver.ResolveOptional(ctx, r)  // Mixed endpoints
```

### SQLc (REQUIRED - no raw SQL in handlers)
```go
// FORBIDDEN
query := `SELECT * FROM publishers WHERE id = $1`
rows, _ := h.db.Pool.Query(ctx, query, id)

// REQUIRED
result, err := h.db.Queries.GetPublisher(ctx, publisherID)
```

### Response Helpers
```go
RespondJSON(w, r, http.StatusOK, data)        // 200
RespondJSON(w, r, http.StatusCreated, data)   // 201
RespondValidationError(w, r, "msg", details)  // 400
RespondBadRequest(w, r, "msg")                // 400
RespondUnauthorized(w, r, "msg")              // 401
RespondForbidden(w, r, "msg")                 // 403
RespondNotFound(w, r, "msg")                  // 404
RespondConflict(w, r, "msg")                  // 409
RespondInternalError(w, r, "msg")             // 500
```

### Logging - slog only
```go
slog.Error("operation failed", "error", err, "user_id", userID, "publisher_id", publisherID)
slog.Info("user created", "user_id", userID)
// FORBIDDEN: fmt.Println, log.Println, log.Printf
```

### Error Handling
```go
// REQUIRED - wrap with context
return nil, fmt.Errorf("failed to fetch publisher: %w", err)

// FORBIDDEN - naked returns
return nil, err

// Log at handler boundary, not in services
// User messages: generic for 500s, never expose internals
```

---

## API Standards

### Response Format
```json
{ "data": <payload>, "meta": { "timestamp": "...", "request_id": "..." } }
```

**RULE:** Pass data directly to RespondJSON - NEVER double-wrap
```go
RespondJSON(w, r, 200, publishers)  // CORRECT: { "data": [...] }
RespondJSON(w, r, 200, map[string]interface{}{"publishers": publishers})  // FORBIDDEN
```

### Headers
| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Protected endpoints | `Bearer {token}` |
| `Content-Type` | POST/PUT | `application/json` |
| `X-Publisher-Id` | Publisher endpoints | Publisher context |

### Status Codes
200 OK | 201 Created | 204 No Content | 400 Bad Request | 401 Unauthorized | 403 Forbidden | 404 Not Found | 409 Conflict | 500 Internal Error

---

## Testing Standards

### Parallel Execution (REQUIRED)
```typescript
test.describe.configure({ mode: 'parallel' });  // REQUIRED at top of every spec file
```

### Shared Fixtures (REQUIRED - no per-test data creation)
```typescript
// FORBIDDEN
test.beforeEach(async () => { testPublisher = await createTestPublisherEntity({...}); });

// REQUIRED
import { getSharedPublisher, getPublisherWithAlgorithm } from '../utils';
const publisher = getSharedPublisher('verified-1');
```

### Shared Publisher Types
| Key | Use Case |
|-----|----------|
| `verified-1` to `verified-5` | General auth tests |
| `pending` / `suspended` | Status flow tests |
| `with-algorithm-1`, `with-algorithm-2` | Algorithm editor |
| `with-coverage` | Coverage page |
| `empty-1` to `empty-3` | Onboarding/empty state |

### Test Pattern
```typescript
import { test, expect } from '@playwright/test';
import { loginAsPublisher, getSharedPublisher, BASE_URL } from '../utils';

test.describe.configure({ mode: 'parallel' });

test.describe('Feature', () => {
  test('description', async ({ page }) => {
    const publisher = getSharedPublisher('verified-1');
    await loginAsPublisher(page, publisher.id);
    await page.goto(`${BASE_URL}/publisher/dashboard`);
    await page.waitForLoadState('networkidle');
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});
```

### Auth Helpers
```typescript
await loginAsAdmin(page);
await loginAsPublisher(page, publisherId);
await loginAsUser(page);
```

### Assertions
```typescript
// CORRECT - role/text selectors
await expect(page.getByRole('heading', { name: 'Title' })).toBeVisible();
await expect(page.getByText('Success')).toBeVisible();
await page.waitForLoadState('networkidle');

// FORBIDDEN - fragile CSS selectors
await page.locator('.some-class > div:nth-child(2)').click();
```

### Test Data
- Use shared fixtures (pre-created)
- If creating: `TEST_E2E_${Date.now()}_Feature`
- Emails: `e2e-test-${Date.now()}@test.zmanim.com`
- FORBIDDEN: `.local` domains, non-unique names

---

## Database Migrations

### Run Migrations
```bash
./scripts/migrate.sh  # Auto-detects environment, tracks in schema_migrations
```

### Create Migration
```bash
# 1. Create: db/migrations/20240029_description.sql
# 2. Write idempotent SQL (IF NOT EXISTS, ON CONFLICT DO NOTHING)
# 3. Run: ./scripts/migrate.sh
# 4. Regenerate SQLc: cd api && sqlc generate
# 5. Rebuild: go build ./...
```

---

## Development Workflow

### Service Restart
```bash
./restart.sh  # ALWAYS use this - handles migrations, cleanup, tmux
# FORBIDDEN: manual go run, npm run dev, pkill
```

### Service URLs
| Service | Port |
|---------|------|
| Web | 3001 |
| API | 8080 |

### Redis Cache
```bash
redis-cli -h redis KEYS "zmanim:*" | xargs -r redis-cli -h redis DEL  # Clear zmanim
redis-cli -h redis FLUSHDB  # Clear all
```

### Code Changes
```bash
# Backend: cd api && go build ./... && go test ./... && cd .. && ./restart.sh
# Frontend: cd web && npm run type-check && npm run lint (hot reload works)
# Schema: ./scripts/migrate.sh && cd api && sqlc generate && go build ./... && cd .. && ./restart.sh
```

---

## Security Standards

- **Input validation:** Backend validates all fields, frontend validates before submit
- **SQL injection:** SQLc handles parameterization - NEVER string concat in queries
- **XSS:** React escapes by default - avoid `dangerouslySetInnerHTML`
- **Auth:** Use middleware.RequireAuth/RequireRole, check isLoaded before rendering protected content

---

## Code Organization

### File Naming
| Type | Convention | Example |
|------|------------|---------|
| Go handlers/services | snake_case | `publisher_zmanim.go` |
| React components | PascalCase | `WeeklyPreviewDialog.tsx` |
| React hooks | camelCase + use | `useApiQuery.ts` |
| Utilities | kebab-case | `api-client.ts` |

### Import Order
**Go:** stdlib → third-party → internal (blank lines between)
**TypeScript:** React/framework → third-party → internal → types

### Function Order
**Go:** Types → Constructors → Public → Private → Helpers
**React:** Imports → Types → Component (hooks → callbacks → effects → early returns → render) → Helpers

---

## Git Standards

### Branches
`feature/epic-{n}-{description}` | `fix/{description}` | `refactor/{scope}-{description}`

### Commits
```
<type>(<scope>): <description>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```
Types: feat, fix, refactor, docs, test, chore, style, perf

---

## Technical Debt (2025-12-02)

| Category | Count | Severity |
|----------|-------|----------|
| Raw `fetch()` in .tsx | 73 | CRITICAL |
| `log.Printf/fmt.Printf` in Go | ~100 | HIGH |
| `waitForTimeout` in tests | 52 | HIGH |
| Double-wrapped API responses | 80+ | MEDIUM |
| Test files missing parallel mode | 23/29 | MEDIUM |

### Detection Commands
```bash
grep -r "await fetch\(" web/app web/components --include="*.tsx" | wc -l  # Should be 0
grep -rE "log\.Printf|fmt\.Printf" api/internal/handlers api/internal/services --include="*.go" | wc -l  # Should be 0
grep -r "waitForTimeout" tests/e2e --include="*.ts" | wc -l  # Should be 0
```

### Exemptions
`api/cmd/` (CLI tools) | `api/internal/db/sqlcgen/` (auto-generated)

---

## Quick Reference Checklists

### Frontend
1. `'use client'` only for hooks/events
2. `useApi()` for all API calls
3. Design tokens for colors
4. 12-hour time format
5. Loading → Error → Content pattern
6. Check `isLoaded` before Clerk access

### Backend
1. PublisherResolver for publisher endpoints
2. SQLc for all queries
3. slog for logging
4. Response helpers for all responses
5. Wrap errors with context
6. Generic messages for 500s

### Testing
1. `test.describe.configure({ mode: 'parallel' })`
2. Shared fixtures only
3. `waitForLoadState('networkidle')` before assertions
4. Role/text selectors
5. `TEST_` prefix if creating data

### PR Checklist
- [ ] No hardcoded colors
- [ ] No raw fetch()
- [ ] PublisherResolver pattern
- [ ] SQLc queries
- [ ] slog logging
- [ ] 12-hour time format
- [ ] E2E tests for new features
- [ ] Parallel mode in test files
