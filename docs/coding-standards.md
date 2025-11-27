# Coding Standards - Zmanim Lab

**Purpose:** Ensure consistent code quality and patterns across the codebase
**Audience:** Developers (human and AI agents)
**Status:** Living document (update as patterns evolve)
**Based on:** Story 3.2 Codebase Audit (2025-11-27)

---

## General Principles

1. **Consistency over cleverness** - Follow established patterns even if you know a "better" way
2. **Explicit over implicit** - Be clear and obvious in your intent
3. **Tested over untested** - E2E tests are mandatory for user-facing changes
4. **Documented over undocumented** - Capture decisions and patterns

---

## Frontend Standards

### File Organization

```
web/
├── app/                    # Next.js App Router pages
│   ├── (auth)/            # Auth routes (Clerk sign-in/sign-up)
│   ├── admin/             # Admin pages (/admin/*)
│   ├── publisher/         # Publisher pages (/publisher/*)
│   └── zmanim/            # User-facing pages (/zmanim/*)
├── components/
│   ├── ui/                # shadcn/ui components (don't modify directly)
│   ├── admin/             # Admin-specific components
│   ├── publisher/         # Publisher-specific components
│   ├── shared/            # Shared components (ProfileDropdown, etc.)
│   ├── home/              # Home page components
│   └── zmanim/            # Zmanim display components
├── lib/                   # Utilities and helpers
│   ├── api.ts            # API client (to be created)
│   └── utils.ts          # General utilities
├── types/                 # TypeScript type definitions
│   └── clerk.ts          # Clerk metadata types (to be created)
└── providers/             # React context providers
    ├── PublisherContext.tsx
    └── QueryProvider.tsx
```

### Component Structure

**DO: Use this pattern for client components**

```tsx
'use client';

// 1. React and framework imports
import { useState, useEffect, useCallback } from 'react';
import Link from 'next/link';

// 2. Third-party libraries
import { useUser, useAuth } from '@clerk/nextjs';
import { Settings, Building2 } from 'lucide-react';

// 3. Internal components and utilities
import { Button } from '@/components/ui/button';
import { usePublisherContext } from '@/providers/PublisherContext';

// 4. Types (inline or imported)
interface ComponentProps {
  prop1: string;
  prop2?: number;
}

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

export function ComponentName({ prop1, prop2 }: ComponentProps) {
  // 1. Hooks first (Clerk, state, context)
  const { user, isLoaded } = useUser();
  const { getToken } = useAuth();
  const { selectedPublisher } = usePublisherContext();
  const [data, setData] = useState<DataType | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // 2. useCallback for async operations
  const fetchData = useCallback(async () => {
    if (!selectedPublisher) return;
    try {
      setIsLoading(true);
      const token = await getToken();
      const response = await fetch(`${API_BASE}/api/v1/endpoint`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'X-Publisher-Id': selectedPublisher.id,
        },
      });
      const result = await response.json();
      setData(result.data || result);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load');
    } finally {
      setIsLoading(false);
    }
  }, [getToken, selectedPublisher]);

  // 3. useEffect for data fetching
  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // 4. Loading state (early return)
  if (!isLoaded || isLoading) {
    return (
      <div className="flex justify-center p-8">
        <Loader2 className="w-8 h-8 animate-spin text-blue-400" />
      </div>
    );
  }

  // 5. Error state (early return)
  if (error) {
    return (
      <div className="bg-red-900/50 border border-red-700 rounded-lg p-4">
        <p className="text-red-200">{error}</p>
      </div>
    );
  }

  // 6. Main render
  return (
    <div className="p-8">
      <div className="max-w-6xl mx-auto">
        {/* Content */}
      </div>
    </div>
  );
}
```

**Reference:** `web/app/publisher/dashboard/page.tsx`

**DON'T:**
- Don't use `'use client'` unless necessary (hooks, event handlers, browser APIs)
- Don't put business logic in components - extract to hooks or utilities
- Don't forget loading and error states

### Client vs Server Components

| Use Client Components (`'use client'`) when: | Use Server Components (default) when: |
|---------------------------------------------|---------------------------------------|
| Using React hooks (useState, useEffect) | Rendering static content |
| Using Clerk hooks (useUser, useAuth) | Fetching data on the server |
| Adding event listeners (onClick, onChange) | No interactivity needed |
| Accessing browser APIs (localStorage, window) | SEO-critical content |

### Clerk Metadata Access

**DO: Type-cast publicMetadata**

```tsx
// Define the type (ideally in web/types/clerk.ts)
interface ClerkPublicMetadata {
  role?: 'admin' | 'publisher' | 'user';
  publisher_access_list?: string[];
  primary_publisher_id?: string;
}

// In component
const { user, isLoaded } = useUser();

if (!isLoaded || !user) return null;

const metadata = user.publicMetadata as ClerkPublicMetadata;
const isAdmin = metadata.role === 'admin';
const hasPublisherAccess = (metadata.publisher_access_list?.length || 0) > 0;
```

**Reference:** `web/components/home/RoleNavigation.tsx:12-19`

### State Management

**Clerk User State:**
```tsx
import { useUser, useAuth } from '@clerk/nextjs';

// Always check isLoaded before accessing user
const { user, isLoaded } = useUser();
const { getToken } = useAuth();

if (!isLoaded) return <LoadingSpinner />;
if (!user) return <SignInPrompt />;
```

**PublisherContext:**
```tsx
import { usePublisherContext } from '@/providers/PublisherContext';

const {
  selectedPublisher,      // Current publisher (or impersonated)
  publishers,             // All accessible publishers
  setSelectedPublisherId, // Change publisher
  isImpersonating,        // Admin impersonation mode
  startImpersonation,     // Begin impersonation
  exitImpersonation,      // End impersonation
} = usePublisherContext();
```

**Reference:** `web/providers/PublisherContext.tsx`

### API Integration

**DO: Use consistent fetch pattern**

```tsx
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

// GET request
const response = await fetch(`${API_BASE}/api/v1/endpoint`, {
  headers: {
    'Authorization': `Bearer ${token}`,
    'X-Publisher-Id': publisherId,  // When publisher-specific
  },
});

// POST request
const response = await fetch(`${API_BASE}/api/v1/endpoint`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  },
  body: JSON.stringify(data),
});

// Handle response wrapper
const result = await response.json();
const actualData = result.data || result;  // Handle wrapped/unwrapped
```

**DON'T:**
- Don't forget to include auth token for protected routes
- Don't forget X-Publisher-Id header for publisher-specific endpoints

### Styling (Tailwind CSS)

**Layout Pattern:**
```tsx
<div className="p-8">
  <div className="max-w-6xl mx-auto">
    {/* Header */}
    <div className="mb-8">
      <h1 className="text-3xl font-bold">Page Title</h1>
      <p className="text-gray-400 mt-1">Subtitle</p>
    </div>

    {/* Grid content */}
    <div className="grid gap-6 md:grid-cols-2">
      {/* Cards */}
    </div>
  </div>
</div>
```

**Color Palette:**
| Purpose | Color Classes |
|---------|---------------|
| Admin actions | `bg-slate-600 hover:bg-slate-500` |
| Publisher actions | `bg-blue-600 hover:bg-blue-700` |
| Success/User actions | `bg-green-600 hover:bg-green-700` |
| Danger | `bg-red-600 hover:bg-red-700` |
| Warning | `bg-yellow-500 text-yellow-950` |
| Card backgrounds | `bg-slate-800 border-slate-700` |
| Muted text | `text-gray-400`, `text-gray-500` |

**Responsive Design:**
```tsx
// Grid columns
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">

// Spacing
<div className="p-4 md:p-6 lg:p-8">

// Hide/show
<div className="hidden md:block">
```

### Icons (Lucide React)

**DO:**
```tsx
import { Settings, Building2, UserPlus, Loader2 } from 'lucide-react';

// Standard sizes
<Icon className="w-4 h-4" />   // Small (inline, buttons)
<Icon className="w-5 h-5" />   // Medium (navigation)
<Icon className="w-8 h-8" />   // Large (cards, empty states)

// With text
<Button>
  <Settings className="w-4 h-4 mr-2" />
  Settings
</Button>
```

**DON'T:**
- Don't use inline SVGs (use Lucide icons instead)
- Don't mix icon libraries (stick to Lucide React)

**Reference:** `web/components/home/RoleNavigation.tsx`

### Form Handling

**Standard Pattern:**
```tsx
const [formData, setFormData] = useState({
  name: '',
  email: '',
});
const [isSubmitting, setIsSubmitting] = useState(false);
const [error, setError] = useState<string | null>(null);

const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault();
  setIsSubmitting(true);
  setError(null);

  try {
    const token = await getToken();
    const response = await fetch(`${API_BASE}/api/v1/endpoint`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify(formData),
    });

    if (!response.ok) {
      throw new Error('Failed to submit');
    }

    // Success handling
    router.push('/success');
  } catch (err) {
    setError(err instanceof Error ? err.message : 'An error occurred');
  } finally {
    setIsSubmitting(false);
  }
};
```

---

## Backend Standards

### Handler Structure (6-Step Pattern)

**DO: Follow this template**

```go
package handlers

import (
    "encoding/json"
    "log/slog"
    "net/http"

    "github.com/go-chi/chi/v5"
)

// HandlerName handles [description]
// METHOD /api/v1/path/{param}
func (h *Handlers) HandlerName(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()

    // Step 1: Extract URL parameters
    id := chi.URLParam(r, "id")

    // Step 2: Validate required parameters
    if id == "" {
        RespondValidationError(w, r, "ID is required", nil)
        return
    }

    // Step 3: Parse request body (for POST/PUT)
    var req struct {
        Name  string `json:"name"`
        Email string `json:"email"`
    }
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        RespondBadRequest(w, r, "Invalid request body")
        return
    }

    // Step 4: Validate request fields
    validationErrors := make(map[string]string)
    if req.Name == "" {
        validationErrors["name"] = "Name is required"
    }
    if len(validationErrors) > 0 {
        RespondValidationError(w, r, "Validation failed", validationErrors)
        return
    }

    // Step 5: Call service layer (business logic)
    result, err := h.service.DoSomething(ctx, id, req.Name)
    if err != nil {
        slog.Error("operation failed", "error", err, "id", id)
        RespondInternalError(w, r, "Failed to process request")
        return
    }

    // Step 6: Respond with success
    RespondJSON(w, r, http.StatusOK, map[string]interface{}{
        "result": result,
    })
}
```

**Reference:** `api/internal/handlers/admin.go:17-59`

**DON'T:**
- Don't put business logic in handlers (use services)
- Don't forget to log errors with context
- Don't expose internal error messages to users

### Response Helpers

**Location:** `api/internal/handlers/response.go`

```go
// Success responses
RespondJSON(w, r, http.StatusOK, data)           // 200 with data
RespondJSON(w, r, http.StatusCreated, data)      // 201 created

// Error responses
RespondValidationError(w, r, "msg", details)     // 400 validation
RespondBadRequest(w, r, "msg")                   // 400 bad request
RespondUnauthorized(w, r, "msg")                 // 401 unauthorized
RespondForbidden(w, r, "msg")                    // 403 forbidden
RespondNotFound(w, r, "msg")                     // 404 not found
RespondConflict(w, r, "msg")                     // 409 conflict
RespondInternalError(w, r, "msg")                // 500 internal error
RespondServiceUnavailable(w, r, "msg")           // 503 unavailable
```

### Service Layer Pattern

**DO:**
```go
package services

import (
    "context"
    "fmt"
    "log/slog"
)

type MyService struct {
    db           *db.Database
    clerkService *ClerkService
}

func NewMyService(db *db.Database, clerk *ClerkService) *MyService {
    return &MyService{
        db:           db,
        clerkService: clerk,
    }
}

// DoSomething performs [description]
func (s *MyService) DoSomething(ctx context.Context, id string) (*Result, error) {
    // Business logic here

    if err != nil {
        return nil, fmt.Errorf("failed to do something: %w", err)
    }

    slog.Info("operation successful", "id", id)
    return result, nil
}
```

**Reference:** `api/internal/services/clerk_service.go`

### Logging (slog)

**DO:**
```go
import "log/slog"

// Error - always include error and context
slog.Error("operation failed",
    "error", err,
    "user_id", userId,
    "publisher_id", publisherId,
)

// Info - for successful operations
slog.Info("user created",
    "user_id", userId,
    "email", email,
)

// Warn - for recoverable issues
slog.Warn("deprecated endpoint called",
    "endpoint", r.URL.Path,
)
```

**DON'T:**
```go
// Don't use fmt.Println or log.Println
fmt.Println("This is bad")        // Bad
log.Println("Also bad")           // Bad
slog.Info("This is good")         // Good
```

### Database Access (pgx)

**Single Row:**
```go
var result Type
err := h.db.Pool.QueryRow(ctx, query, params...).Scan(&field1, &field2)
if err == pgx.ErrNoRows {
    RespondNotFound(w, r, "Resource not found")
    return
}
if err != nil {
    slog.Error("query failed", "error", err)
    RespondInternalError(w, r, "Failed to retrieve data")
    return
}
```

**Multiple Rows:**
```go
rows, err := h.db.Pool.Query(ctx, query, params...)
if err != nil {
    slog.Error("query failed", "error", err)
    RespondInternalError(w, r, "Failed to retrieve data")
    return
}
defer rows.Close()

results := make([]map[string]interface{}, 0)
for rows.Next() {
    var field1, field2 string
    var optionalField *string

    err := rows.Scan(&field1, &field2, &optionalField)
    if err != nil {
        slog.Error("scan failed", "error", err)
        continue
    }

    result := map[string]interface{}{
        "field1": field1,
        "field2": field2,
    }
    if optionalField != nil {
        result["optional_field"] = *optionalField
    }
    results = append(results, result)
}
```

### Clerk Integration

**Service Setup:**
```go
import (
    "github.com/clerk/clerk-sdk-go/v2"
    clerkUser "github.com/clerk/clerk-sdk-go/v2/user"
)

func NewClerkService() (*ClerkService, error) {
    secretKey := os.Getenv("CLERK_SECRET_KEY")
    if secretKey == "" {
        return nil, fmt.Errorf("CLERK_SECRET_KEY not set")
    }
    clerk.SetKey(secretKey)
    return &ClerkService{initialized: true}, nil
}
```

**User Operations:**
```go
// Create user
params := &clerkUser.CreateParams{
    EmailAddresses:          &[]string{email},
    FirstName:               clerk.String(name),
    PublicMetadata:          clerk.JSONRawMessage(metadataJSON),
    SkipPasswordRequirement: clerk.Bool(true),
}
user, err := clerkUser.Create(ctx, params)

// Update metadata
params := &clerkUser.UpdateMetadataParams{
    PublicMetadata: clerk.JSONRawMessage(metadataJSON),
}
_, err = clerkUser.UpdateMetadata(ctx, clerkUserID, params)
```

**Reference:** `api/internal/services/clerk_service.go`

---

## Testing Standards

### Test File Organization

```
tests/
├── e2e/
│   ├── admin/              # Admin flow tests
│   │   ├── dashboard.spec.ts
│   │   ├── publishers.spec.ts
│   │   └── impersonation.spec.ts
│   ├── publisher/          # Publisher flow tests
│   │   ├── dashboard.spec.ts
│   │   ├── algorithm.spec.ts
│   │   └── coverage.spec.ts
│   ├── user/               # End user tests
│   │   ├── location.spec.ts
│   │   └── zmanim.spec.ts
│   ├── registration/       # Registration flows
│   ├── errors/             # Error handling
│   ├── setup/              # Global setup/teardown
│   └── utils/              # Shared utilities
│       ├── clerk-auth.ts   # Auth helpers
│       ├── test-fixtures.ts # DB fixtures
│       ├── email-testing.ts # Email helpers
│       └── cleanup.ts      # Cleanup utilities
```

### Test File Pattern

**DO:**
```typescript
import { test, expect } from '@playwright/test';
import {
  loginAsAdmin,
  loginAsPublisher,
  createTestPublisherEntity,
  cleanupTestData,
  BASE_URL,
} from '../utils';

test.describe('Feature Name', () => {
  let testPublisher: { id: string; name: string };

  // Create shared test data ONCE
  test.beforeAll(async () => {
    testPublisher = await createTestPublisherEntity({
      name: 'TEST_E2E_Feature_Name',
      organization: 'TEST_E2E_Org',
      status: 'verified',
    });
  });

  // Clean up AFTER all tests
  test.afterAll(async () => {
    await cleanupTestData();
  });

  // Login BEFORE each test
  test.beforeEach(async ({ page }) => {
    await loginAsAdmin(page);
  });

  test('describes what the test verifies', async ({ page }) => {
    // Navigate
    await page.goto(`${BASE_URL}/admin/publishers`);
    await page.waitForLoadState('networkidle');

    // Assert
    await expect(page.getByRole('heading', { name: 'Publisher Management' })).toBeVisible();
  });

  test('another test in the same describe block', async ({ page }) => {
    // Uses same testPublisher, same login
  });
});
```

**Reference:** `tests/e2e/admin/publishers.spec.ts`

### Test Data Conventions

**DO:**
```typescript
// Entity names - TEST_ prefix
const publisher = await createTestPublisherEntity({
  name: 'TEST_E2E_Publisher_Feature',
  organization: 'TEST_E2E_Organization',
});

// Test emails - use example.com domain
const email = `test-user-${Date.now()}@test-zmanim.example.com`;
```

**DON'T:**
```typescript
// Don't use .local domains (Clerk rejects them)
const email = 'test@test.zmanim-lab.local';  // Bad

// Don't use production-like names
const publisher = await createTestPublisherEntity({
  name: 'Real Publisher Name',  // Bad - not identifiable as test
});
```

### Auth Injection

**DO: Use Clerk testing library**
```typescript
import { loginAsAdmin, loginAsPublisher, loginAsUser } from '../utils';

// Admin test
test('admin can view dashboard', async ({ page }) => {
  await loginAsAdmin(page);
  await page.goto(`${BASE_URL}/admin/dashboard`);
});

// Publisher test
test('publisher can view profile', async ({ page }) => {
  await loginAsPublisher(page, testPublisher.id);
  await page.goto(`${BASE_URL}/publisher/profile`);
});

// User test
test('user can search locations', async ({ page }) => {
  await loginAsUser(page);
  await page.goto(`${BASE_URL}/`);
});
```

**Reference:** `tests/e2e/utils/clerk-auth.ts`

### Assertions

**DO:**
```typescript
// Role-based selectors (preferred)
await expect(page.getByRole('heading', { name: 'Title' })).toBeVisible();
await expect(page.getByRole('button', { name: 'Submit' })).toBeEnabled();

// Text-based selectors
await expect(page.getByText('Success message')).toBeVisible();

// Wait for network before assertions
await page.waitForLoadState('networkidle');
```

**DON'T:**
```typescript
// Don't use fragile CSS selectors
await page.locator('.some-class > div:nth-child(2)').click();  // Bad

// Don't forget to wait for page to load
await expect(page.getByText('Content')).toBeVisible();  // May flake
```

### Cleanup

**DO: Always cleanup test data**
```typescript
test.afterAll(async () => {
  await cleanupTestData();  // Idempotent - safe to run multiple times
});
```

**Reference:** `tests/e2e/utils/cleanup.ts`

---

## API Standards

### Endpoint Naming

```
GET    /api/v1/publishers              # List publishers
GET    /api/v1/publishers/{id}         # Get single publisher
POST   /api/v1/publishers              # Create publisher
PUT    /api/v1/publishers/{id}         # Update publisher
DELETE /api/v1/publishers/{id}         # Delete publisher

GET    /api/v1/publishers/{id}/users   # Nested resource
POST   /api/v1/publishers/{id}/invite  # Action endpoint
```

### Request Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes (protected) | `Bearer {token}` |
| `Content-Type` | Yes (POST/PUT) | `application/json` |
| `X-Publisher-Id` | Sometimes | Publisher context for multi-tenant |

### Response Format

**Success:**
```json
{
  "data": {
    "id": "uuid",
    "name": "Publisher Name"
  },
  "meta": {
    "timestamp": "2025-11-27T10:30:00Z",
    "request_id": "uuid"
  }
}
```

**Error:**
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Name is required",
    "details": {
      "name": "This field is required"
    }
  },
  "meta": {
    "timestamp": "2025-11-27T10:30:00Z",
    "request_id": "uuid"
  }
}
```

### Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 200 | OK | Successful GET, PUT |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Validation error, malformed request |
| 401 | Unauthorized | Not authenticated |
| 403 | Forbidden | Not authorized for this action |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | Duplicate, state conflict |
| 500 | Internal Error | Server error (log details, return generic message) |

---

## Code Review Checklist

### Frontend

- [ ] Client components use `'use client'` only when needed
- [ ] Clerk `isLoaded` check before accessing user
- [ ] Proper loading and error states
- [ ] Tailwind classes used consistently
- [ ] Lucide icons (not inline SVG)
- [ ] Imports organized properly
- [ ] API calls include auth token and error handling

### Backend

- [ ] Handler follows 6-step pattern
- [ ] Business logic in service layer
- [ ] Response helpers used (RespondJSON, RespondError, etc.)
- [ ] Structured logging with slog
- [ ] Errors logged with context (error, user_id, etc.)
- [ ] Error messages don't expose internals

### Testing

- [ ] E2E test for user-facing changes
- [ ] Test data uses TEST_ prefix
- [ ] Test emails use example.com domain
- [ ] Cleanup in afterAll
- [ ] Auth injection uses loginAsAdmin/loginAsPublisher
- [ ] Assertions use getByRole/getByText

---

## When to Deviate

These standards are guidelines, not laws. Deviate when:

1. **There's a good reason** - Document it in a comment
2. **The pattern doesn't fit** - Some cases are genuinely different
3. **A better pattern emerges** - Update this document!

When deviating:
```tsx
// Deviation: Using inline SVG because [specific reason]
<svg>...</svg>
```

---

## Quick Reference

### Frontend Checklist
1. `'use client'` only if using hooks/events
2. Type-cast Clerk metadata
3. Loading → Error → Content pattern
4. Tailwind for styling
5. Lucide for icons

### Backend Checklist
1. Extract params → Validate → Service → Respond
2. slog for logging
3. Response helpers for all responses
4. Context-first parameters
5. Error wrapping with fmt.Errorf

### Testing Checklist
1. beforeAll for shared data
2. afterAll for cleanup
3. beforeEach for auth
4. TEST_ prefix for entities
5. example.com for emails

---

_Last Updated: 2025-11-27_
_Based on: Story 3.2 Codebase Audit, Epic 1 & 2 Implementation_
