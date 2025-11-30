# Coding Standards - Zmanim Lab

**Purpose:** Ensure consistent code quality and patterns across the codebase
**Audience:** Developers (human and AI agents)
**Status:** CAST-IRON RULES - Violations block PRs
**Based on:** Story 3.2 Codebase Audit (2025-11-27), Codebase Review (2025-11-28)

---

## CRITICAL VIOLATIONS (Must Fix Immediately)

The following patterns are FORBIDDEN and must be refactored:

### 1. Hardcoded Colors - NEVER USE

```tsx
// FORBIDDEN - Will be rejected in code review
className="text-[#1e3a5f]"
className="bg-[#0051D5]"
className="border-[#007AFF]"
style={{ color: '#ff0000' }}
```

**REQUIRED - Use design tokens:**
```tsx
className="text-primary"
className="bg-primary/90"
className="text-muted-foreground"
className="border-border"
```

### 2. Defining API_BASE in Components - NEVER DO THIS

```tsx
// FORBIDDEN - Will be rejected in code review
const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';
```

**REQUIRED - Use the unified API client:**
```tsx
import { useApi } from '@/lib/api-client';

const api = useApi();
const data = await api.get('/publisher/profile');
```

### 3. Duplicated Fetch Logic - USE UNIFIED API CLIENT

```tsx
// FORBIDDEN - Raw fetch with manual auth handling
const token = await getToken();
const response = await fetch(`${API_BASE}/api/v1/endpoint`, {
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
    'X-Publisher-Id': selectedPublisher.id,
  },
});
```

**REQUIRED - Use the unified API client (useApi hook):**
```tsx
import { useApi } from '@/lib/api-client';

// In component
const api = useApi();
const data = await api.get<DataType>('/publisher/profile');
await api.post('/publisher/zmanim', { body: JSON.stringify(zman) });

// For public endpoints (no auth)
const countries = await api.public.get('/countries');

// For admin endpoints (no X-Publisher-Id)
const stats = await api.admin.get('/admin/stats');
```

**For React Query data fetching, use factory hooks:**
```tsx
import { usePublisherQuery, usePublisherMutation } from '@/lib/hooks';

// Query with automatic caching and publisher context
const { data, isLoading, error } = usePublisherQuery<ProfileData>(
  'publisher-profile',
  '/publisher/profile'
);

// Mutation with automatic cache invalidation
const updateProfile = usePublisherMutation<Profile, UpdateRequest>(
  '/publisher/profile',
  'PUT',
  { invalidateKeys: ['publisher-profile'] }
);
```

### 4. Authentication - CORRECT PATTERNS (No Broken Code)

**RULE: Always check Clerk loading state BEFORE accessing auth:**
```tsx
const { isLoaded, isSignedIn, user } = useUser();
const { getToken } = useAuth();

// NEVER access user or call getToken before isLoaded is true
if (!isLoaded) {
  return <LoadingSpinner />;
}

if (!isSignedIn) {
  redirect('/sign-in');
}

// NOW safe to use
const token = await getToken();
```

**RULE: Token MUST be awaited and checked:**
```tsx
// WRONG - token may be null/undefined, sends "Bearer null" causing 401
const token = await getToken();
fetch(url, { headers: { Authorization: `Bearer ${token}` } });

// CORRECT - handle missing token gracefully
const token = await getToken();
if (!token) {
  setError('Not authenticated. Please sign in.');
  setLoading(false);
  return;
}
fetch(url, { headers: { Authorization: `Bearer ${token}` } });
```

**Common 401 Error Patterns to Avoid:**
1. Making fetch requests before checking if token is null
2. Not handling the case where `getToken()` returns null
3. Sending `Authorization: Bearer null` or `Authorization: Bearer undefined`
4. Making authenticated requests before Clerk's `isLoaded` is true

**RULE: X-Publisher-Id header required for publisher endpoints:**
```tsx
// WRONG - missing publisher context
fetch(`${API_BASE}/api/v1/publisher/profile`, {
  headers: { Authorization: `Bearer ${token}` }
});

// CORRECT - include publisher ID
fetch(`${API_BASE}/api/v1/publisher/profile`, {
  headers: {
    Authorization: `Bearer ${token}`,
    'X-Publisher-Id': selectedPublisher.id,  // REQUIRED
  }
});
```

**RULE: Use the unified API client to prevent mistakes:**
```tsx
// This hook handles all auth correctly - USE IT
import { useApi } from '@/lib/api-client';

const api = useApi();
const data = await api.get('/publisher/profile');
// Token and X-Publisher-Id handled automatically
```

**DEBUGGING CHECKLIST (when auth is broken):**

1. Is `isLoaded` true before calling `getToken()`?
2. Is the token being sent in the Authorization header?
3. Is `X-Publisher-Id` header set for publisher routes?
4. Are environment variables correct? (`CLERK_SECRET_KEY`, `NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY`)
5. Is the backend running? (`tmux attach -t zmanim`)

**COMMON MISTAKES:**

| Mistake | Fix |
|---------|-----|
| Calling `getToken()` before `isLoaded` | Add loading check |
| Missing Authorization header | Use centralized fetch hook |
| Missing X-Publisher-Id | Use centralized fetch hook |
| Token is null/undefined | Check `isSignedIn` first |
| Wrong env variables | Both must be from same Clerk instance |

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

**RULE: Use the unified API client (useApi hook) - NEVER raw fetch**

```tsx
import { useApi } from '@/lib/api-client';

function MyComponent() {
  const api = useApi();

  // GET request (auth + X-Publisher-Id automatic)
  const profile = await api.get<ProfileData>('/publisher/profile');

  // POST request
  await api.post('/publisher/zmanim', {
    body: JSON.stringify(zmanData),
  });

  // Public endpoint (no auth)
  const countries = await api.public.get<Country[]>('/countries');

  // Admin endpoint (auth but no X-Publisher-Id)
  const stats = await api.admin.get('/admin/stats');
}
```

**RULE: Use React Query hooks for data fetching**

```tsx
import {
  usePublisherQuery,
  usePublisherMutation,
  useGlobalQuery,
} from '@/lib/hooks';

// Publisher-scoped query (auto-includes X-Publisher-Id)
const { data, isLoading, error } = usePublisherQuery<ProfileData>(
  'publisher-profile',
  '/publisher/profile'
);

// Global query (no publisher context)
const { data: templates } = useGlobalQuery<Template[]>(
  'templates',
  '/zmanim/templates',
  { staleTime: 1000 * 60 * 60 } // 1 hour cache
);

// Mutation with cache invalidation
const updateProfile = usePublisherMutation<Profile, UpdateRequest>(
  '/publisher/profile',
  'PUT',
  { invalidateKeys: ['publisher-profile'] }
);

// Usage
await updateProfile.mutateAsync(formData);
```

**Reference:** `web/lib/api-client.ts`, `web/lib/hooks/useApiQuery.ts`

**DON'T:**
- Don't use raw `fetch()` - use `useApi()` hook
- Don't define API_BASE in components - it's in api-client.ts
- Don't manually add auth headers - useApi handles it
- Don't forget to handle loading/error states

### Styling (Tailwind CSS) - MANDATORY DESIGN TOKEN USAGE

**RULE: NO HARDCODED COLORS**

All colors MUST come from the design system defined in `tailwind.config.ts` and `globals.css`:

| Usage | CORRECT | FORBIDDEN |
|-------|---------|-----------|
| Primary text | `text-foreground` | `text-[#111827]` |
| Muted text | `text-muted-foreground` | `text-gray-400` |
| Primary button | `bg-primary` | `bg-[#007AFF]` |
| Button hover | `bg-primary/90` | `bg-[#0051D5]` |
| Card background | `bg-card` | `bg-white` |
| Borders | `border-border` | `border-gray-300` |
| Status success | `bg-green-100 text-green-800` | (allowed - semantic) |
| Status error | `bg-destructive/10 text-destructive` | `bg-red-100` |

**Reusable Status Badge Classes (add to globals.css):**
```css
@layer utilities {
  .status-badge-success { @apply bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-medium; }
  .status-badge-warning { @apply bg-yellow-100 text-yellow-800 px-3 py-1 rounded-full text-sm font-medium; }
  .status-badge-error { @apply bg-red-100 text-red-800 px-3 py-1 rounded-full text-sm font-medium; }
  .status-badge-pending { @apply bg-blue-100 text-blue-800 px-3 py-1 rounded-full text-sm font-medium; }
}
```

**Layout Pattern:**
```tsx
<div className="p-8">
  <div className="max-w-6xl mx-auto">
    {/* Header */}
    <div className="mb-8">
      <h1 className="text-3xl font-bold text-foreground">Page Title</h1>
      <p className="text-muted-foreground mt-1">Subtitle</p>
    </div>

    {/* Grid content */}
    <div className="grid gap-6 md:grid-cols-2">
      {/* Cards */}
    </div>
  </div>
</div>
```

**MANDATORY Design Token Hierarchy (use in this order):**
1. Semantic tokens: `primary`, `secondary`, `destructive`, `muted`, `accent`, `foreground`, `background`
2. Extended colors from config: `apple-blue`, `apple-gray-500`
3. Tailwind defaults: `green-100`, `red-800` (for status colors only)
4. **NEVER**: Arbitrary values like `[#hex]` or inline styles

**Responsive Design:**
```tsx
// Grid columns
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">

// Spacing
<div className="p-4 md:p-6 lg:p-8">

// Hide/show
<div className="hidden md:block">
```

### Time Formatting - MANDATORY 12-HOUR FORMAT

**RULE: All times displayed to users MUST use 12-hour AM/PM format**

```tsx
// FORBIDDEN - 24-hour format confuses users
<span>14:30:36</span>
<span>{result.time}</span>  // If backend returns "14:30:36"

// REQUIRED - 12-hour AM/PM format
<span>2:30:36 PM</span>
<span>{formatTime(result.time)}</span>
```

**Use the shared time formatting utility:**
```tsx
import { formatTime, formatTimeShort } from '@/lib/utils';

// Full format with seconds: "2:30:36 PM"
formatTime('14:30:36')

// Short format without seconds: "2:30 PM"
formatTimeShort('14:30:36')
```

**Implementation (add to lib/utils.ts if not present):**
```tsx
export function formatTime(time: string): string {
  // Handle HH:MM:SS or HH:MM format
  const [hours, minutes, seconds] = time.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const hour12 = hours % 12 || 12;

  if (seconds !== undefined) {
    return `${hour12}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')} ${period}`;
  }
  return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
}

export function formatTimeShort(time: string): string {
  const [hours, minutes] = time.split(':').map(Number);
  const period = hours >= 12 ? 'PM' : 'AM';
  const hour12 = hours % 12 || 12;
  return `${hour12}:${minutes.toString().padStart(2, '0')} ${period}`;
}
```

**Where this applies:**
- Calculated zman times (Formula Builder, Algorithm Editor)
- Preview results
- Weekly preview dialog
- Any time display in the UI

---

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

**DO: Follow this template using PublisherResolver**

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

    // Step 1: Resolve publisher context (handles X-Publisher-Id, auth, errors)
    pc := h.publisherResolver.MustResolve(w, r)
    if pc == nil {
        return // Response already sent
    }
    publisherID := pc.PublisherID

    // Step 2: Extract URL parameters
    id := chi.URLParam(r, "id")
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

    // Step 5: Use SQLc generated queries (preferred) or service layer
    result, err := h.db.Queries.GetSomething(ctx, sqlcgen.GetSomethingParams{
        PublisherID: publisherID,
        ID:          id,
    })
    if err != nil {
        slog.Error("operation failed", "error", err, "id", id)
        RespondInternalError(w, r, "Failed to process request")
        return
    }

    // Step 6: Respond with success
    RespondJSON(w, r, http.StatusOK, map[string]interface{}{
        "data": result,
    })
}
```

**Reference:** `api/internal/handlers/publisher_zmanim.go`

### PublisherResolver Pattern (REQUIRED for publisher endpoints)

**RULE: Use PublisherResolver instead of manual auth checks**

```go
// FORBIDDEN - Manual publisher ID extraction (verbose, error-prone)
userID := middleware.GetUserID(ctx)
if userID == "" {
    RespondUnauthorized(w, r, "User ID not found")
    return
}
requestedID := r.Header.Get("X-Publisher-Id")
publisherID := middleware.GetValidatedPublisherID(ctx, requestedID)
if publisherID == "" {
    RespondForbidden(w, r, "No access")
    return
}

// REQUIRED - Use PublisherResolver (handles all cases)
pc := h.publisherResolver.MustResolve(w, r)
if pc == nil {
    return // Response already sent
}
publisherID := pc.PublisherID
```

**PublisherResolver methods:**
```go
// MustResolve - Returns nil and sends error response if resolution fails
pc := h.publisherResolver.MustResolve(w, r)

// Resolve - Returns PublisherContext or error (for custom error handling)
pc, err := h.publisherResolver.Resolve(ctx, r)

// ResolveOptional - Doesn't fail if publisher not found (for mixed endpoints)
pc := h.publisherResolver.ResolveOptional(ctx, r)
```

**Reference:** `api/internal/handlers/publisher_context.go`

### SQLc for Database Queries (REQUIRED)

**RULE: Use SQLc generated queries instead of raw SQL**

```go
// FORBIDDEN - Raw SQL in handlers (error-prone, no type safety)
query := `SELECT id, name FROM publishers WHERE id = $1`
rows, err := h.db.Pool.Query(ctx, query, publisherID)

// REQUIRED - SQLc generated queries (type-safe, maintainable)
result, err := h.db.Queries.GetPublisher(ctx, publisherID)

// For complex results, convert SQLc types to handler types
zmanim := make([]PublisherZman, len(sqlcZmanim))
for i, z := range sqlcZmanim {
    zmanim[i] = sqlcZmanToPublisherZman(z)
}
```

**Reference:** `api/internal/db/queries/*.sql`, `api/internal/handlers/publisher_zmanim.go`

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

### CRITICAL: Parallel Test Execution

Tests MUST be designed for parallel execution. This is a non-negotiable requirement for fast CI/CD pipelines.

**RULE: Use shared fixtures, not per-test data creation**
```typescript
// FORBIDDEN - Creates data per test (slow, causes conflicts)
test.beforeEach(async () => {
  testPublisher = await createTestPublisherEntity({ name: 'Test' });
});
test.afterEach(async () => {
  await cleanupTestData();
});

// REQUIRED - Use pre-created shared publishers
import { getSharedPublisher, getPublisherWithAlgorithm } from '../utils';

test('can access dashboard', async ({ page }) => {
  const publisher = getSharedPublisher('verified-1');
  await loginAsPublisher(page, publisher.id);
  // Test logic...
});
```

**RULE: Enable parallel mode in all test files**
```typescript
// REQUIRED at top of every spec file
test.describe.configure({ mode: 'parallel' });
```

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
│   │   ├── algorithm-editor.spec.ts
│   │   ├── coverage.spec.ts
│   │   ├── team.spec.ts
│   │   └── onboarding.spec.ts
│   ├── auth/               # Authentication tests
│   │   └── authentication.spec.ts
│   ├── public/             # Public page tests
│   │   └── public-pages.spec.ts
│   ├── setup/              # Global setup/teardown
│   │   ├── global-setup.ts
│   │   └── global-teardown.ts
│   └── utils/              # Shared utilities
│       ├── clerk-auth.ts       # Auth helpers
│       ├── test-fixtures.ts    # DB fixtures
│       ├── shared-fixtures.ts  # Shared publisher pool
│       ├── algorithm-fixtures.ts # Algorithm test data
│       ├── wait-helpers.ts     # Wait utilities
│       ├── test-builders.ts    # Entity builders
│       └── index.ts            # Unified exports
```

### Test File Pattern

**DO: Use shared fixtures for parallel execution**
```typescript
/**
 * E2E Tests: Feature Name
 *
 * Optimized for parallel execution using shared fixtures.
 */
import { test, expect } from '@playwright/test';
import {
  loginAsPublisher,
  getSharedPublisher,
  getPublisherWithAlgorithm,
  BASE_URL,
} from '../utils';

// REQUIRED: Enable parallel mode
test.describe.configure({ mode: 'parallel' });

test.describe('Feature Name - Section', () => {
  test('test case description', async ({ page }) => {
    // Get pre-created shared publisher (NO creation/deletion)
    const publisher = getSharedPublisher('verified-1');
    await loginAsPublisher(page, publisher.id);

    // Navigate
    await page.goto(`${BASE_URL}/publisher/dashboard`);
    await page.waitForLoadState('networkidle');

    // Assert
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });

  test('another independent test', async ({ page }) => {
    // Each test is completely independent - can run in parallel
    const publisher = getSharedPublisher('verified-2'); // Use different publisher
    await loginAsPublisher(page, publisher.id);
    // Test logic...
  });
});
```

**Reference:** `tests/e2e/publisher/team.spec.ts`

### Shared Publisher Types

The shared fixture pool provides these pre-created publishers:

| Key | Type | Use Case |
|-----|------|----------|
| `verified-1` through `verified-5` | verified | General tests needing auth |
| `pending` | pending | Testing pending status flows |
| `suspended` | suspended | Testing suspended status flows |
| `with-algorithm-1`, `with-algorithm-2` | verified + algorithm | Algorithm editor tests |
| `with-coverage` | verified + coverage | Coverage page tests |
| `empty-1` through `empty-3` | verified (no data) | Onboarding/empty state tests |

```typescript
// Get specific publisher by key
const publisher = getSharedPublisher('verified-1');

// Get publisher with algorithm pre-created
const publisher = getPublisherWithAlgorithm();

// Get empty publisher for onboarding tests
const publisher = getEmptyPublisher(1);

// Get any available verified publisher
const publisher = getAnyVerifiedPublisher();
```

### Test Data Conventions

**DO:**
```typescript
// Use shared fixtures - data is pre-created
const publisher = getSharedPublisher('verified-1');

// When you must create data, use TEST_ prefix and unique identifiers
const name = `TEST_E2E_${Date.now()}_Feature`;

// Test emails - use zmanim.com domain or MailSlurp
const email = `e2e-test-${Date.now()}@test.zmanim.com`;
```

**DON'T:**
```typescript
// Don't create/delete data in individual tests (breaks parallelism)
test.beforeEach(async () => {
  testPublisher = await createTestPublisherEntity({...}); // BAD
});

// Don't use .local domains (Clerk rejects them)
const email = 'test@test.zmanim-lab.local';  // BAD

// Don't use non-unique names (causes conflicts in parallel)
const publisher = { name: 'Test Publisher' };  // BAD - collides
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

## Database Migrations

### Running Migrations in Coder Environment

When developing in the Coder cloud IDE, the database runs in a local Docker container (not Supabase). Use the following methods to run migrations:

**Method 1: Use the migrate script (Recommended)**
```bash
./scripts/migrate.sh
```

This script:
- Auto-detects if you're in Coder environment
- Uses local PostgreSQL from `api/.env` DATABASE_URL
- Tracks applied migrations in `schema_migrations` table
- Skips already-applied migrations

**Method 2: Direct psql (for single migrations)**
```bash
# Source the database credentials
source api/.env

# Apply a specific migration
PGPASSWORD=<password> psql -h postgres -U zmanim -d zmanim \
  -f supabase/migrations/20240028_rename_fundamental_to_core.sql
```

**Method 3: Extract and run (when you need the credentials)**
```bash
# The DATABASE_URL format is: postgresql://user:password@host:port/database
# Example: postgresql://zmanim:zmanim_dev_xxx@postgres:5432/zmanim

# Parse from api/.env and run
source api/.env
echo $DATABASE_URL  # See the connection string
```

### Creating New Migrations

1. Create a new SQL file in `supabase/migrations/` with timestamp prefix:
   ```
   supabase/migrations/20240029_your_migration_name.sql
   ```

2. Write idempotent SQL (use `IF NOT EXISTS`, `ON CONFLICT DO NOTHING`):
   ```sql
   -- Migration: Description of what this does

   ALTER TABLE your_table ADD COLUMN IF NOT EXISTS new_column TEXT;

   -- For column renames (not idempotent, be careful)
   ALTER TABLE your_table RENAME COLUMN old_name TO new_name;
   ```

3. Run the migration:
   ```bash
   ./scripts/migrate.sh
   ```

4. Update SQLc queries if schema changed:
   ```bash
   cd api && go run github.com/sqlc-dev/sqlc/cmd/sqlc@latest generate
   ```

5. Rebuild Go code:
   ```bash
   cd api && go build ./...
   ```

### Migration Best Practices

| Do | Don't |
|----|-------|
| Use timestamp prefixes (20240029_) | Use sequential numbers (001_) |
| Make migrations idempotent when possible | Assume clean state |
| Test migrations locally first | Push untested migrations |
| Update SQLc queries after schema changes | Forget to regenerate sqlc |
| Include rollback comments | Leave migrations undocumented |

### Environment Detection

The migrate script detects the environment:
- **Coder**: Uses local PostgreSQL via Docker network (`postgres:5432`)
- **Production**: Uses Supabase CLI (`npx supabase migration up`)

Connection info is read from `api/.env`:
```
DATABASE_URL=postgresql://zmanim:password@postgres:5432/zmanim
```

---

## Error Handling Standards

### Backend Error Handling

**Pattern: Wrap errors with context**
```go
// REQUIRED - wrap with context using fmt.Errorf
if err != nil {
    return nil, fmt.Errorf("failed to fetch publisher: %w", err)
}

// FORBIDDEN - naked error returns
if err != nil {
    return nil, err  // No context, hard to debug
}
```

**Pattern: Log at the boundary, not everywhere**
```go
// In service layer - return error, don't log
func (s *Service) DoSomething() error {
    if err != nil {
        return fmt.Errorf("failed to do something: %w", err)
    }
}

// In handler layer - log the error with context
if err != nil {
    slog.Error("operation failed", "error", err, "user_id", userID)
    RespondInternalError(w, r, "Failed to process request")
    return
}
```

**Pattern: User-friendly error messages**
```go
// REQUIRED - generic messages for 500 errors
RespondInternalError(w, r, "Failed to process request")

// FORBIDDEN - exposing internals
RespondInternalError(w, r, err.Error())  // Exposes database errors!
RespondInternalError(w, r, "SQL: duplicate key constraint violation")
```

### Frontend Error Handling

**Pattern: Use ApiError class**
```tsx
import { ApiError } from '@/lib/api-client';

try {
  await api.post('/endpoint', { body: JSON.stringify(data) });
} catch (error) {
  if (error instanceof ApiError) {
    if (error.isUnauthorized) {
      // Handle 401
    } else if (error.isNotFound) {
      // Handle 404
    } else if (error.isServerError) {
      // Handle 500+
    }
    setError(error.message);
  } else {
    setError('An unexpected error occurred');
  }
}
```

**Pattern: Toast notifications for mutations**
```tsx
const mutation = usePublisherMutation<Data, Request>(
  '/endpoint',
  'POST',
  {
    invalidateKeys: ['query-key'],
    onError: (error) => {
      toast.error(error.message);
    },
    onSuccess: () => {
      toast.success('Operation completed');
    }
  }
);
```

---

## Performance Standards

### Backend Performance

**Pattern: Use database indexes for common queries**
```sql
-- Index columns used in WHERE clauses
CREATE INDEX idx_publisher_zmanim_publisher_id ON publisher_zmanim(publisher_id);
CREATE INDEX idx_publisher_zmanim_zman_key ON publisher_zmanim(zman_key);

-- Composite indexes for multi-column filters
CREATE INDEX idx_publisher_zmanim_publisher_key
  ON publisher_zmanim(publisher_id, zman_key);
```

**Pattern: Paginate large result sets**
```go
// REQUIRED for endpoints returning many rows
params := sqlcgen.ListItemsParams{
    Limit:  int32(limit),
    Offset: int32(offset),
}
```

**Pattern: Use caching for expensive operations**
```go
// Cache zman calculations (24-hour TTL)
cacheKey := fmt.Sprintf("zman:%s:%s:%s", publisherID, zmanKey, date)
if cached, ok := h.cache.Get(cacheKey); ok {
    return cached
}
```

### Frontend Performance

**Pattern: Memoize expensive computations**
```tsx
const expensiveResult = useMemo(() => {
  return calculateSomethingExpensive(data);
}, [data]);
```

**Pattern: Debounce user input**
```tsx
const debouncedSearch = useMemo(
  () => debounce((value: string) => setSearch(value), 300),
  []
);
```

**Pattern: Use React Query staleTime for static data**
```tsx
const { data } = useGlobalQuery<Template[]>('templates', '/zmanim/templates', {
  staleTime: 1000 * 60 * 60, // 1 hour - templates rarely change
});
```

---

## Security Standards

### Input Validation

**Backend: Validate all inputs**
```go
// REQUIRED - validate request fields
validationErrors := make(map[string]string)

if req.Name == "" {
    validationErrors["name"] = "Name is required"
}
if len(req.Name) > 255 {
    validationErrors["name"] = "Name must be 255 characters or less"
}
if !isValidEmail(req.Email) {
    validationErrors["email"] = "Invalid email format"
}

if len(validationErrors) > 0 {
    RespondValidationError(w, r, "Validation failed", validationErrors)
    return
}
```

**Frontend: Validate before submission**
```tsx
const [errors, setErrors] = useState<Record<string, string>>({});

const validate = () => {
  const newErrors: Record<string, string> = {};
  if (!formData.name) newErrors.name = 'Name is required';
  if (!isValidEmail(formData.email)) newErrors.email = 'Invalid email';
  setErrors(newErrors);
  return Object.keys(newErrors).length === 0;
};

const handleSubmit = async () => {
  if (!validate()) return;
  // Proceed with submission
};
```

### SQL Injection Prevention

**REQUIRED: Use parameterized queries (SQLc handles this)**
```go
// SQLc generates safe parameterized queries
result, err := h.db.Queries.GetPublisher(ctx, publisherID)
```

**FORBIDDEN: String concatenation in queries**
```go
// NEVER DO THIS
query := fmt.Sprintf("SELECT * FROM publishers WHERE id = '%s'", publisherID)
```

### XSS Prevention

**Pattern: React escapes by default - don't bypass**
```tsx
// SAFE - React escapes content
<div>{userProvidedContent}</div>

// DANGEROUS - bypass escaping (avoid unless absolutely necessary)
<div dangerouslySetInnerHTML={{ __html: content }} />
```

### Authentication Checks

**Backend: Always verify auth before operations**
```go
// Use middleware.RequireAuth or middleware.RequireRole
r.With(middleware.RequireRole("admin")).Get("/admin/stats", h.AdminStats)
r.With(middleware.RequireAuth).Get("/publisher/profile", h.GetProfile)
```

**Frontend: Check auth state before rendering protected content**
```tsx
if (!isLoaded) return <Loading />;
if (!isSignedIn) return redirect('/sign-in');
if (!hasPublisherAccess) return redirect('/');
```

---

## Code Organization Standards

### File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Go handlers | snake_case | `publisher_zmanim.go` |
| Go services | snake_case | `clerk_service.go` |
| React components | PascalCase | `WeeklyPreviewDialog.tsx` |
| React hooks | camelCase with use prefix | `useApiQuery.ts` |
| Utilities | kebab-case | `api-client.ts` |
| Types | camelCase | `types/clerk.ts` |

### Import Organization

**Go imports (3 groups, blank line between)**
```go
import (
    // Standard library
    "context"
    "encoding/json"
    "net/http"

    // Third-party packages
    "github.com/go-chi/chi/v5"
    "github.com/jackc/pgx/v5"

    // Internal packages
    "github.com/jcom-dev/zmanim-lab/internal/db"
    "github.com/jcom-dev/zmanim-lab/internal/middleware"
)
```

**TypeScript imports (4 groups)**
```tsx
// 1. React and framework imports
import { useState, useEffect } from 'react';
import Link from 'next/link';

// 2. Third-party libraries
import { useUser } from '@clerk/nextjs';
import { Loader2 } from 'lucide-react';

// 3. Internal components and utilities
import { Button } from '@/components/ui/button';
import { useApi } from '@/lib/api-client';

// 4. Types
import type { Publisher } from '@/types';
```

### Function/Method Ordering

**Go files**
1. Type definitions
2. Constructor functions (New*)
3. Public methods (exported)
4. Private methods (unexported)
5. Helper functions

**React components**
1. Imports
2. Types/Interfaces
3. Component function
   - Hooks (Clerk, context, state)
   - Callbacks (useCallback)
   - Effects (useEffect)
   - Early returns (loading, error)
   - Main render
4. Helper functions (if not extracted)

---

## Git Workflow Standards

### Branch Naming

```
feature/epic-{n}-{short-description}
fix/{issue-or-short-description}
refactor/{scope}-{description}
docs/{what-documented}
```

### Commit Messages

```
<type>(<scope>): <description>

[optional body]

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types**: feat, fix, refactor, docs, test, chore, style, perf

**Examples**:
```
feat(algorithm): add weekly preview dialog
fix(auth): handle expired tokens gracefully
refactor(handlers): migrate to PublisherResolver pattern
docs(readme): update deployment instructions
```

### Pull Request Checklist

- [ ] All tests pass (`npm test`, `go test ./...`)
- [ ] No new hardcoded colors (use design tokens)
- [ ] No raw fetch() calls (use useApi hook)
- [ ] Handlers use PublisherResolver pattern
- [ ] SQLc queries used (no raw SQL in handlers)
- [ ] Errors logged with slog and context
- [ ] E2E tests added for new features
- [ ] Times displayed in 12-hour format

---

_Last Updated: 2025-11-30_
_Based on: Story 3.2 Codebase Audit, Epic 1-4 Implementation, Production Refactoring, Architect Review_

---

## Changelog

### 2025-11-30 - Architect Review Updates
- Added **Error Handling Standards** section with backend/frontend patterns
- Added **Performance Standards** section (caching, pagination, memoization)
- Added **Security Standards** section (validation, SQL injection, XSS, auth)
- Added **Code Organization Standards** section (naming, imports, ordering)
- Added **Git Workflow Standards** section (branches, commits, PR checklist)
- Updated changelog to reflect comprehensive review

### 2025-11-30 - Database Migration Tooling
- Added `scripts/migrate.sh` for environment-aware migrations
- Added documentation for running migrations in Coder environment

### 2025-11-29 - Production Refactoring
- **Frontend**: Replaced `useAuthenticatedFetch` with unified `useApi` hook from `@/lib/api-client`
- **Frontend**: Added React Query factory hooks (`usePublisherQuery`, `usePublisherMutation`)
- **Backend**: Added `PublisherResolver` pattern for consistent auth/publisher extraction
- **Backend**: Migrated to SQLc generated queries for type-safe database access
- **Testing**: Added shared fixtures system for parallel test execution
- **Testing**: Added `test.describe.configure({ mode: 'parallel' })` requirement
