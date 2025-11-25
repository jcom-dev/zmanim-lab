# Story 1.3: Admin Publisher Management

Status: ready-for-dev

## Story

As an **administrator**,
I want **to create and manage publisher accounts**,
so that **I can onboard halachic authorities to the platform**.

## Acceptance Criteria

1. Admin sees list of all publishers with status (pending/verified/suspended)
2. Admin can create new publisher with email, name, organization
3. New publisher receives Clerk invitation email
4. Admin can verify pending publishers (status → verified)
5. Admin can suspend verified publishers (status → suspended)
6. Admin can reactivate suspended publishers
7. Admin dashboard shows usage statistics (publishers, calculations, cache ratio)
8. Admin can configure system settings (rate limits, cache TTL, feature flags)

## Tasks / Subtasks

- [ ] Task 1: Create publishers database table (AC: 1-6)
  - [ ] 1.1 Create migration for publishers table
  - [ ] 1.2 Add indexes for clerk_user_id and status
  - [ ] 1.3 Run migration in Supabase

- [ ] Task 2: Create system_config database table (AC: 8)
  - [ ] 2.1 Create migration for system_config table
  - [ ] 2.2 Seed default configuration values
  - [ ] 2.3 Run migration in Supabase

- [ ] Task 3: Implement admin API handlers (AC: 1-6)
  - [ ] 3.1 Create api/internal/handlers/admin.go
  - [ ] 3.2 GET /api/admin/publishers - list all publishers
  - [ ] 3.3 POST /api/admin/publishers - create new publisher
  - [ ] 3.4 PUT /api/admin/publishers/{id}/verify
  - [ ] 3.5 PUT /api/admin/publishers/{id}/suspend
  - [ ] 3.6 PUT /api/admin/publishers/{id}/reactivate

- [ ] Task 4: Implement Clerk invitation (AC: 3)
  - [ ] 4.1 Use Clerk Admin API to create user invitation
  - [ ] 4.2 Send invitation email with onboarding link
  - [ ] 4.3 Handle invitation acceptance callback

- [ ] Task 5: Implement admin stats endpoint (AC: 7)
  - [ ] 5.1 GET /api/admin/stats
  - [ ] 5.2 Query total/active publishers count
  - [ ] 5.3 Query total calculations (from logs or counter)
  - [ ] 5.4 Query cache hit ratio from Redis

- [ ] Task 6: Implement system config endpoints (AC: 8)
  - [ ] 6.1 GET /api/admin/config
  - [ ] 6.2 PUT /api/admin/config
  - [ ] 6.3 Support rate limits, cache TTL, feature flags

- [ ] Task 7: Create admin publisher list page (AC: 1)
  - [ ] 7.1 Create web/app/admin/publishers/page.tsx
  - [ ] 7.2 Display publishers in table with status badges
  - [ ] 7.3 Add action buttons (verify/suspend/reactivate)
  - [ ] 7.4 Add search/filter functionality

- [ ] Task 8: Create admin publisher creation form (AC: 2, 3)
  - [ ] 8.1 Create web/app/admin/publishers/new/page.tsx
  - [ ] 8.2 Form fields: email, name, organization
  - [ ] 8.3 Submit to POST /api/admin/publishers
  - [ ] 8.4 Show success/error feedback

- [ ] Task 9: Create admin dashboard page (AC: 7)
  - [ ] 9.1 Create web/app/admin/dashboard/page.tsx
  - [ ] 9.2 Display stats cards (publishers, calculations, cache)
  - [ ] 9.3 Add refresh functionality

- [ ] Task 10: Create admin settings page (AC: 8)
  - [ ] 10.1 Create web/app/admin/settings/page.tsx
  - [ ] 10.2 Form for system configuration
  - [ ] 10.3 Save to PUT /api/admin/config

## Dev Notes

### Architecture Patterns

- **Admin Role Check:** Middleware validates admin claim in JWT
- **Publisher Status Flow:** pending → verified ↔ suspended
- **Clerk Integration:** Use Clerk Admin API for user management

### Database Schema

```sql
CREATE TABLE publishers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clerk_user_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    organization TEXT,
    email TEXT NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, verified, suspended
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE system_config (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now()
);
```

### References

- [Source: docs/architecture.md#Data-Model]
- [Source: docs/epics.md#Story-1.3-Admin-Publisher-Management]
- [Source: docs/sprint-artifacts/tech-spec-epic-1.md#Story-1.3]
- [Source: docs/prd.md#FR34-FR38]

## Dev Agent Record

### Context Reference
### Agent Model Used
### Debug Log References
### Completion Notes List
### File List
