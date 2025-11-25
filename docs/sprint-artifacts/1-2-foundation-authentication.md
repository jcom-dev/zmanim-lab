# Story 1.2: Foundation & Authentication

Status: ready-for-dev

## Story

As an **application user**,
I want **secure authentication and a reliable API**,
so that **I can safely access the platform with appropriate permissions**.

## Acceptance Criteria

1. Unauthenticated users can view public pages and access anonymous endpoints
2. Clerk sign-in modal appears and supports email/password and social providers
3. Authenticated publishers can access /publisher/* routes
4. Authenticated admins can access /admin/* routes
5. API returns structured error responses: `{error: {code, message, details}}`
6. Anonymous users receive 429 after 100 requests/hour

## Tasks / Subtasks

- [ ] Task 1: Install and configure Clerk frontend (AC: 2, 3, 4)
  - [ ] 1.1 Install @clerk/nextjs package
  - [ ] 1.2 Configure ClerkProvider in app layout
  - [ ] 1.3 Add Clerk middleware for route protection
  - [ ] 1.4 Create sign-in/sign-up pages with Clerk components
  - [ ] 1.5 Protect /publisher/* routes (require publisher role)
  - [ ] 1.6 Protect /admin/* routes (require admin role)

- [ ] Task 2: Implement Go JWT middleware (AC: 3, 4)
  - [ ] 2.1 Add Clerk SDK or manual JWKS verification
  - [ ] 2.2 Create api/internal/middleware/auth.go
  - [ ] 2.3 Extract user ID and roles from JWT claims
  - [ ] 2.4 Create role-checking middleware (admin, publisher)

- [ ] Task 3: Implement API response helpers (AC: 5)
  - [ ] 3.1 Create respondJSON() helper function
  - [ ] 3.2 Create respondError() helper with error codes
  - [ ] 3.3 Define standard error code constants
  - [ ] 3.4 Apply consistent response format across handlers

- [ ] Task 4: Implement rate limiting (AC: 6)
  - [ ] 4.1 Create api/internal/middleware/ratelimit.go
  - [ ] 4.2 Implement 100 req/hour limit for anonymous users
  - [ ] 4.3 Higher limits for authenticated users
  - [ ] 4.4 Return 429 with Retry-After header

- [ ] Task 5: Configure CORS (AC: 1)
  - [ ] 5.1 Create api/internal/middleware/cors.go
  - [ ] 5.2 Allow frontend domain in CORS headers
  - [ ] 5.3 Configure allowed methods and headers

- [ ] Task 6: Set up TanStack Query (AC: 1)
  - [ ] 6.1 Install @tanstack/react-query
  - [ ] 6.2 Create web/providers/QueryProvider.tsx
  - [ ] 6.3 Configure query client defaults
  - [ ] 6.4 Wrap app in QueryProvider

- [ ] Task 7: Install shadcn/ui components (AC: 1)
  - [ ] 7.1 Run npx shadcn-ui@latest init
  - [ ] 7.2 Configure Midnight Trust color system in CSS variables
  - [ ] 7.3 Install initial component set (Button, Card, Dialog, Input)

## Dev Notes

### Architecture Patterns

- **Response Format:** `{data, error, meta}` per architecture doc
- **JWT Validation:** Clerk JWKS endpoint for key verification
- **Rate Limiting:** In-memory or Redis-backed counter
- **Role Claims:** Custom claims in Clerk JWT for admin/publisher roles

### Source Tree Components

```
web/
  ├── app/
  │   ├── layout.tsx           # Add ClerkProvider
  │   ├── sign-in/[[...sign-in]]/page.tsx
  │   └── sign-up/[[...sign-up]]/page.tsx
  ├── middleware.ts            # Clerk route protection
  └── providers/
      └── QueryProvider.tsx    # TanStack Query setup
api/internal/
  ├── middleware/
  │   ├── auth.go              # JWT validation
  │   ├── cors.go              # CORS configuration
  │   └── ratelimit.go         # Rate limiting
  └── handlers/
      └── response.go          # Response helpers
```

### References

- [Source: docs/architecture.md#Authentication-Flow]
- [Source: docs/architecture.md#API-Response-Format]
- [Source: docs/epics.md#Story-1.2-Foundation-Authentication]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.2]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
